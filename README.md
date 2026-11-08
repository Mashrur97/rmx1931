# rmx1931

Mashrur's working repo for the Realme X2 Pro (RMX1931, "samurai") on Infinity-X (Android 17) with KernelSU:

- **OppoCamera port**: stock RealmeUI F.14 camera as a KernelSU module (v0.10).
- **Smooth 960**: the camera's 960 mode makes real in-between frames (480 fps capture + motion interpolation)
  instead of repeating frames. Root helper + camera hook.
- **OnePlus Gallery fixes**: Meishe watermark, slow-mo detection on non-OnePlus phones, document filters.

Full history, every finding and the reasoning live in the Claude doc
"Realme X2 Pro: stock OppoCamera port to Android 17, handoff notes". This repo holds the scripts and tools.

## Layout

| Path | What |
| --- | --- |
| `module/` | v0.10 module scripts (`customize.sh` installer, `post-fs-data.sh` overlays, `service.sh` boot hook + helper start, `oppocam.sh` helper commands). The payload (APK, libraries) is not in git. |
| `smooth960/` | `s960d.sh` root helper (runs ffmpeg outside the camera sandbox), `libs960sh.so` camera-side messenger (goes in the payload's `lib/arm64`), installers and diagnostic scripts. |
| `pc/` | Manual smoothing from a Windows PC over adb (`smooth960.bat` + `smooth960_adb.sh`), Termux version. |
| `tools/` | APK/dex/ELF tools: `v2sign.py` (APK v2 signer), `rezip.py`, `patchentry.py`, dex and ARM64 disassembly helpers, `make_system_img.py`. |
| `gallery/` | OnePlus Gallery patch notes. |

## Smooth 960 in one paragraph

960 mode records 480 fps. The camera calls `com.b.a.a(src, dst, factor)` (`compileSlowMotion`, Meishe), which our
hook redirects to `com.b.S960`. That runs `libs960sh.so`, which hands a job file to the root helper `s960d.sh`. The
helper cuts the slow section, interpolates it 2x with ffmpeg `minterpolate` in 6 parallel chunks, adds the 16x head
and tail like stock, and writes the result into a file the camera created. The camera saves it normally, or, if
you left the camera, the helper saves `Slow<date>.mp4` itself and the camera posts a "Saved" notification.

## Build notes

- Camera APK: `apktool d -r` the v0.9.1 APK (md5 `768c1a00…`), apply the smali changes, `apktool b`, take
  `classes.dex` + `classes3.dex` (classes.dex is at the 64K limit: new classes go in classes3), put them into the
  original APK with `tools/rezip.py`, sign with `uber-apk-signer-1.3.0 --allowResign` (built-in Android Debug key,
  cert sha256 `1E:08:A9:03…`).
- Module zip: v0.9.1 zip tree + `module/` scripts + new APK + `smooth960/libs960sh.so` in
  `payload/priv-app/OppoCamera/lib/arm64/` + `s960/{ffmpeg,s960d.sh}`; `zip -r` with forward slashes.
- ffmpeg: johnvansickle static arm64 build (glibc). It cannot run inside an app (seccomp kills it), only as root.
