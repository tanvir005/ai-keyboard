import Foundation

#if canImport(Darwin)
import Darwin
#endif

/// Measures how much memory this process is actually charged for, and lets a
/// known amount be claimed on purpose.
///
/// ## Why this exists
/// A keyboard extension runs under a far smaller memory limit than an app, and
/// iOS does not warn before it acts — it kills the extension and the keyboard
/// vanishes mid-sentence. Every plan for Chinese and Japanese input rests on
/// one assumption: that a dictionary of tens of megabytes can be *mapped* and
/// read in place rather than parsed into objects.
///
/// That assumption is worth half a day to test and four months to be wrong
/// about, so this exists to test it before anything is built on it.
///
/// ## Why mapped and heap are both here
/// They are charged differently, and the difference is the whole question. A
/// heap allocation is dirty memory — it counts against the limit in full, and
/// cannot be reclaimed. File-backed pages are clean: the kernel may evict and
/// re-read them under pressure, so a mapped dictionary can be far larger than
/// a parsed one before anything dies.
///
/// Measuring both is what turns "mmap is probably better" into a number.
public enum MemoryProbe {

    /// What iOS charges this process, in bytes.
    ///
    /// `phys_footprint` deliberately, not resident size: it is the figure the
    /// system's own out-of-memory killer reads, so it is the only one whose
    /// limit matters. Resident size looks similar and is not what ends the
    /// process.
    public static var footprintBytes: UInt64? {
        #if canImport(Darwin)
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return UInt64(info.phys_footprint)
        #else
        return nil
        #endif
    }

    /// Footprint in whole megabytes, for showing on screen.
    public static var footprintMB: Int? {
        footprintBytes.map { Int($0 / (1024 * 1024)) }
    }

    // MARK: - Claiming memory on purpose

    /// A file mapped into this process, kept alive by holding the value.
    ///
    /// Releasing it unmaps — which is why the probe has to be stored somewhere
    /// with the lifetime of the keyboard rather than created and dropped.
    public final class MappedFile {
        private let base: UnsafeMutableRawPointer
        private let length: Int
        private let url: URL

        public let megabytes: Int

        /// Sum of the bytes read by `touchAllPages`, kept only so the reads
        /// cannot be optimised away. It wraps, and is not worth asserting on —
        /// use `firstByte` to check the mapping reaches the file.
        public private(set) var checksum: UInt8 = 0

        fileprivate init(base: UnsafeMutableRawPointer, length: Int, url: URL) {
            self.base = base
            self.length = length
            self.url = url
            self.megabytes = length / (1024 * 1024)
        }

        /// The first byte of the mapping.
        public var firstByte: UInt8 {
            base.assumingMemoryBound(to: UInt8.self)[0]
        }

        /// Reads one byte per page so the pages are actually faulted in, and
        /// returns how many it touched.
        ///
        /// Without this, `mmap` costs nothing measurable — the mapping exists
        /// but no page has been touched, and the probe would report a success
        /// that means nothing. A real dictionary lookup touches pages, so the
        /// experiment has to as well.
        @discardableResult
        public func touchAllPages() -> Int {
            let pageSize = Int(getpagesize())
            let bytes = base.assumingMemoryBound(to: UInt8.self)
            var sum: UInt8 = 0
            var touched = 0
            for offset in stride(from: 0, to: length, by: pageSize) {
                sum = sum &+ bytes[offset]
                touched += 1
            }
            checksum = sum
            return touched
        }

        deinit {
            munmap(base, length)
            try? FileManager.default.removeItem(at: url)
        }
    }

    public enum ProbeError: Error {
        case couldNotCreateFile
        case couldNotOpenFile
        case couldNotMap
    }

    /// Writes a file of `megabytes` and maps it read-only.
    ///
    /// The file is deleted when the mapping is released, so a run leaves
    /// nothing behind in the container. That also means it is written fresh
    /// each time — a second's work at the largest size, and not worth the
    /// bookkeeping to avoid.
    public static func mapFile(
        megabytes: Int,
        directory: URL = FileManager.default.temporaryDirectory
    ) throws -> MappedFile {
        let length = megabytes * 1024 * 1024
        let url = directory.appendingPathComponent("nib-memory-probe-\(megabytes)mb.bin")

        // Written a megabyte at a time: building the whole thing as one Data
        // would claim on the heap exactly what this is trying to avoid
        // claiming, and the measurement would be of the writer.
        try? FileManager.default.removeItem(at: url)
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw ProbeError.couldNotCreateFile
        }
        guard let handle = FileHandle(forWritingAtPath: url.path) else {
            throw ProbeError.couldNotOpenFile
        }
        let chunk = Data(repeating: 0x4E, count: 1024 * 1024) // "N"
        for _ in 0 ..< megabytes {
            handle.write(chunk)
        }
        try? handle.close()

        let descriptor = open(url.path, O_RDONLY)
        guard descriptor >= 0 else { throw ProbeError.couldNotOpenFile }
        defer { close(descriptor) }

        let base = mmap(nil, length, PROT_READ, MAP_PRIVATE, descriptor, 0)
        guard let base, base != MAP_FAILED else { throw ProbeError.couldNotMap }

        return MappedFile(base: base, length: length, url: url)
    }

    /// The comparison case: the same number of megabytes claimed on the heap.
    ///
    /// This is what parsing a dictionary into Swift values costs. If the
    /// extension survives a mapped file of a given size but dies on a heap
    /// allocation of the same size, that difference is the answer the whole
    /// probe was run to find.
    public static func allocateHeap(megabytes: Int) -> Data {
        var data = Data(count: megabytes * 1024 * 1024)
        // Written to, not just sized: untouched pages may never be backed at
        // all, and an allocation that was never faulted in proves nothing.
        data.withUnsafeMutableBytes { raw in
            guard let bytes = raw.bindMemory(to: UInt8.self).baseAddress else { return }
            let pageSize = Int(getpagesize())
            for offset in stride(from: 0, to: raw.count, by: pageSize) {
                bytes[offset] = 0x4E
            }
        }
        return data
    }
}
