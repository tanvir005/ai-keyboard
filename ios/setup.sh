#!/bin/bash
#
# One command between a fresh clone and a runnable Xcode project.
#
#     ./setup.sh sk-proj-your-openai-key
#     ./setup.sh                          # no key: every tool stays on the stub
#
# ## Why this exists
# The steps it replaces are individually trivial and collectively a trap. The
# project needs Secrets.xcconfig to exist before XcodeGen will run at all, that
# file is gitignored so no clone ever has it, and when it is missing XcodeGen
# fails with a message about a config file rather than "make your key file".
# Then the .xcodeproj has to be generated, which a fresh clone also lacks.
#
# Getting any of that wrong produces a build that looks fine and does nothing,
# which is exactly what happened. So: one command, and it says what it did.

set -euo pipefail

cd "$(dirname "$0")"

KEY="${1:-}"
MODEL="${2:-gpt-5-nano}"

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn(){ printf '  \033[33m!\033[0m %s\n' "$1"; }

# ---------------------------------------------------------------------------

say "Checking tools"

if ! command -v xcodegen >/dev/null 2>&1; then
    warn "xcodegen is not installed. Run this, then try again:"
    printf '\n      brew install xcodegen\n\n'
    exit 1
fi
ok "xcodegen $(xcodegen --version 2>/dev/null | head -1)"

# ---------------------------------------------------------------------------

say "Writing Secrets.xcconfig"

if [ -n "$KEY" ]; then
    printf 'NIB_OPENAI_KEY = %s\nNIB_OPENAI_MODEL = %s\n' "$KEY" "$MODEL" > Secrets.xcconfig
    ok "key written, model $MODEL"
elif [ -f Secrets.xcconfig ]; then
    ok "already exists, left alone"
else
    cp Secrets.xcconfig.example Secrets.xcconfig
    warn "no key given — created an empty one"
    warn "every AI tool will return canned stub text until a key is set"
fi

# The file is gitignored, but a key is worth one more check than that.
if git check-ignore -q Secrets.xcconfig 2>/dev/null; then
    ok "gitignored, so the key cannot be committed"
else
    warn "WARNING: Secrets.xcconfig is NOT gitignored. Do not commit it."
fi

# ---------------------------------------------------------------------------

say "Generating the Xcode project"

rm -rf Nib.xcodeproj
xcodegen generate --spec project.yml >/dev/null
[ -d Nib.xcodeproj ] || { warn "xcodegen produced no Nib.xcodeproj"; exit 1; }
ok "Nib.xcodeproj"

# ---------------------------------------------------------------------------

say "Done — three things left, and Xcode has to do them"

cat <<'STEPS'
  1. open Nib.xcodeproj

  2. Click the blue "Nib" at the top of the sidebar, then set
     Signing & Capabilities -> Team on BOTH targets:
         Nib
         NibKeyboard
     Missing one is the usual reason signing fails.

  3. Pick your iPhone at the top, press Run.

  Then on the phone, once it installs:

     Settings -> General -> Keyboard -> Keyboards -> Nib
       -> Allow Full Access -> ON

  Full Access resets on every reinstall, and without it iOS blocks the
  keyboard from the network entirely. No key, no model, no suggestions —
  and no error explaining why.
STEPS

printf '\n'
