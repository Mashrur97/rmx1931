#!/system/bin/sh
# OppoCamera module (v0.11) diagnostics for a new ROM build.
# Run as root:  sh /data/local/tmp/camdiag.sh
# It opens the camera by itself, waits, closes it, and packs everything into
# /sdcard/camdiag.tar.gz  (pull that and send it).
# Changes nothing on the phone.

OUT=/sdcard/camdiag
rm -rf $OUT; mkdir -p $OUT
S=$OUT/summary.txt
say() { echo "$*" | tee -a $S; }

say "=== camdiag $(date)"
say "fingerprint: $(getprop ro.build.fingerprint)"
say "rom version: $(getprop ro.modversion) $(getprop org.infinity.version) $(getprop ro.infinity.version)"
for m in /data/adb/modules/*/module.prop; do grep -q -i oppocam "$m" && say "module.prop: $m $(grep -E '^version=' $m)"; done

say ""
say "=== module boot log"
cp /data/adb/oppocam/boot.log $OUT/boot.log 2>/dev/null && say "copied boot.log" || say "NO boot.log"
grep -iE "FAILED|missing|skip|differs|not patched" $OUT/boot.log 2>/dev/null | tee -a $S

say ""
say "=== libraries (exists / size / md5)"
for f in /system/lib64/libstdc++.so /vendor/lib64/libstdc++.so /vendor/lib64/libstdc++_vendor.so /system/lib64/libstdc++_vendor.so \
         /vendor/lib64/libcdsprpc.so /vendor/lib64/libadsprpc.so /system/lib64/libnativewindow.so \
         /vendor/lib64/libarcsoft_dualcam_refocus_preview.so /odm/lib64/libarcsoft_dualcam_refocus_preview.so \
         /vendor/lib64/libarcsoft_hdrplus_hvx_5221_stub.so /odm/lib64/libarcsoft_hdrplus_hvx_5221_stub.so \
         /vendor/lib64/libCOppLceTonemapAPI.so /odm/lib64/libCOppLceTonemapAPI.so /vendor/lib64/libOPPORectify.so \
         /vendor/lib64/libOGLManager.so /system/bin/cameraserver; do
  if [ -f "$f" ]; then say "$f  $(stat -c %s $f)  $(md5sum $f | cut -c1-12)"; else say "$f  (none)"; fi
done

say ""
say "=== symbol version names present (count of matches; 0 = version gone)"
say "libcdsprpc SDSPRPC: $(grep -c SDSPRPC /vendor/lib64/libcdsprpc.so 2>/dev/null)"
say "libnativewindow LIBNATIVEWINDOW: $(grep -c LIBNATIVEWINDOW /system/lib64/libnativewindow.so 2>/dev/null)"

say ""
say "=== mounts"
grep oppocam /proc/mounts | tee -a $S

say ""
say "=== opening the camera for 15 s"
logcat -c
monkey -p com.oppo.camera -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 15
say "camera pid: $(pidof com.oppo.camera)"
dumpsys media.camera > $OUT/media_camera.txt 2>&1
input keyevent KEYCODE_HOME
sleep 2
logcat -d > $OUT/logcat.txt
logcat -b crash -d > $OUT/crash.txt 2>/dev/null

say ""
say "=== linker / load errors"
grep -iE "cannot locate symbol|dlopen failed|CANNOT LINK|SDSPRPC|LIBNATIVEWINDOW|libstdc\+\+|version .* not found|library .* not found" $OUT/logcat.txt | head -60 | tee -a $S
say ""
say "=== camera errors"
grep -iE "F DEBUG|FATAL|camera.*(died|crash)|onConfigureFailed|ERROR_CAMERA|CameraAccessException" $OUT/logcat.txt | head -40 | tee -a $S

cd /sdcard && tar czf camdiag.tar.gz camdiag && say "" && say "packed: /sdcard/camdiag.tar.gz ($(stat -c %s camdiag.tar.gz) bytes)"
