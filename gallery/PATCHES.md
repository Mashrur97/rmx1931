# OnePlus Gallery 5.0.44 patches (verified Nov 7 2026)

Base: `com.oneplus.gallery` 5.0.44, TG "universal" port, md5 `a5620f71e8919c1a7600411a11874ab2`. The porters embedded
ColorOS `framework.jar` + `oplus-framework.jar` as classes9-11 and signed with the public AOSP `testkey`
(`build/target/product/security/testkey`). Our builds use the same key, so `adb install -r` keeps data.

| Problem | Cause | Patch |
| --- | --- | --- |
| Meishe watermark on trim/crop | `E meicam: The current app is not authorised!` (`allowedAppIds`) | `lib/arm64-v8a/libNvStreamingSdkCore.so` @`0x15c270`: `3c090036` (tbz w28) -> `1f2003d5` (nop) |
| No slow-mo editor (whole clip slow) | detector `sb/e$a.a` gated by `sb/d.c`: `Build.BRAND` md5 == md5("OnePlus") and path `.+/(IMG\|VID)_\d{8}_\d{6}.+` | `classes4.dex` file offset `0x10a87c`: `6201eee2` -> `12110f01` (`const/4 v1,1; return v1`), then fix dex SHA-1 + Adler32 |
| Text-scanner filters do nothing | `YTCommon: 3015 Bundle ID mismatch` (Tencent Youtu) | `lib/arm64-v8a/libYTCommon.so` @`0x1d6f4` and @`0x1d70c` -> `20008052 c0035fd6` (`mov w0,#1; ret`) |

Rebuild: `tools/patchentry.py` for stored libs (same size), `tools/rezip.py` for dex, then
`tools/v2sign.py in.apk out.apk testkey.pk8 testkey.x509.pem`; verify with `apksigtool verify` (pip).
Slow-mo detection only runs when a video is first indexed (clear gallery data to re-index old clips).
