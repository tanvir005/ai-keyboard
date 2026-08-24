import SwiftUI
import NibKit

@main
struct NibApp: App {
    @State private var settings = SharedSettings.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                // The kraft palette is a committed look, not a themeable one —
                // the mockup renders every screen on constant paper stock.
                .preferredColorScheme(.light)
                .tint(NibStyle.Palette.red)
        }
    }
}

struct RootView: View {
    @Environment(SharedSettings.self) private var settings

    var body: some View {
        Group {
            if settings.onboardingComplete {
                MainTabView()
            } else {
                OnboardingFlow()
            }
        }
        .background(NibStyle.Palette.paper)
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }
            PresetsView()
                .tabItem { Label("Presets", systemImage: "slider.horizontal.3") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
