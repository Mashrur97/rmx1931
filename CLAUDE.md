# Notes for Claude sessions

- Owner: Mashrur (nickname RN). Credits and author fields say "Mashrur". He published the camera module; Nayem
  (Infinity-X maintainer) tests it.
- Read the Claude doc "Realme X2 Pro: stock OppoCamera port to Android 17, handoff notes" (status at the top, then the
  newest sections at the end) before changing anything. It is the source of truth; this repo holds scripts and tools.
- Discuss before writing code. Deliver phone-side changes as scripts to push and run (Windows cmd mangles nested
  quotes in `adb shell su -c "..."`), one command per line.
- The user tests on the phone; the workspace has no device. Test scripts locally (dash, x86 ffmpeg, fake paths)
  before sending.
- Binaries and OPPO-derived files (APK, payload libs, decompiled smali) are not committed while the repo is public.
- Commits end with the attribution lines from the session's system reminder.
