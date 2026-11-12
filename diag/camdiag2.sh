#!/system/bin/sh
# OppoCamera module diagnostics, part 2 (new ROM build).
# Run as root RIGHT AFTER A FRESH REBOOT (do not open the camera first, do not run camdiag.sh first):
#   sh /data/local/tmp/camdiag2.sh
# Collects the camera HAL's boot-time library loading errors and a copy of this build's cameraserver.
# Packs into /sdcard/camdiag2.tar.gz. Changes nothing on the phone.

OUT=/sdcard/camdiag2
rm -rf $OUT; mkdir -p $OUT
S=$OUT/summary.txt
say() { echo "$*" | tee -a $S; }

say "=== camdiag2 $(date)  uptime $(cut -d' ' -f1 /proc/uptime)s"
say "fingerprint: $(getprop ro.build.fingerprint)"

# everything logged since boot, all buffers, before anything clears it
logcat -b all -d > $OUT/boot_all.txt 2>&1
say "boot log lines: $(wc -l < $OUT/boot_all.txt)"

say ""
say "=== library loading errors since boot"
grep -iE "cannot locate symbol|dlopen failed|CANNOT LINK|not found|SDSPRPC|WaterMark|refocus|hdrplus_hvx|LceTonemap|Rectify|libstdc\+\+" $OUT/boot_all.txt \
  | grep -viE "nativeloader|ContentResolver|ActivityManager|PackageManager" | head -80 | tee -a $S

say ""
say "=== camera HAL errors since boot"
grep -iE "CamX.*(ERROR|Failed)|CHIUSECASE.*(ERROR|Fail)|chi.override|camxhal|camera.provider" $OUT/boot_all.txt | head -60 | tee -a $S

say ""
say "=== watermark libs"
for f in /odm/lib64/libWaterMark.so /vendor/lib64/libWaterMark.so /vendor/lib64/camera/components/com.oppo.node.watermark.so; do
  if [ -f "$f" ]; then say "$f  $(stat -c %s $f)  $(md5sum $f | cut -c1-12)  $(ls -Z $f | cut -d' ' -f1)"; else say "$f  (none)"; fi
done

say ""
say "=== cameraserver copy"
cp /system/bin/cameraserver $OUT/cameraserver && say "copied $(md5sum $OUT/cameraserver | cut -c1-12)"

cd /sdcard && tar czf camdiag2.tar.gz camdiag2 && say "" && say "packed: /sdcard/camdiag2.tar.gz ($(stat -c %s camdiag2.tar.gz) bytes)"
