#!/system/bin/sh
# OppoCamera module diagnostics, part 3: same as camdiag.sh, plus the camera HAL's own (CamX) error log.
# Run as root after the phone has booted:  sh /data/local/tmp/camdiag3.sh
# For the test it temporarily adds a CamX log-settings file (overlay on /vendor/etc/camera, in RAM only)
# and restarts the camera HAL; at the end it removes the overlay and restarts the HAL again.
# Nothing is written to /vendor; a reboot also undoes it. Packs into /sdcard/camdiag3.tar.gz.

OUT=/sdcard/camdiag3
rm -rf $OUT; mkdir -p $OUT
S=$OUT/summary.txt
say() { echo "$*" | tee -a $S; }
hal_restart() {
  for p in $(pidof android.hardware.camera.provider@2.4-service_64) $(pidof android.hardware.camera.provider@2.4-service) \
           $(pidof vendor.qti.camera.provider@2.7-service_64); do kill $p; done
  sleep 3
  i=0
  # the camera service event log is newest-first: wait until the newest event for camera 7 is ADD
  while [ $i -lt 60 ]; do
    dumpsys media.camera 2>/dev/null | grep -m1 "device 7, reason" | grep -q ADD && break
    sleep 1; i=$((i+1))
  done
  sleep 5
  say "camera HAL back after ${i}s (pid $(pidof android.hardware.camera.provider@2.4-service_64 android.hardware.camera.provider@2.4-service vendor.qti.camera.provider@2.7-service_64), cameraserver $(pidof cameraserver))"
}

say "=== camdiag3 $(date)"
say "fingerprint: $(getprop ro.build.fingerprint)"
for m in /data/adb/modules/*/module.prop; do grep -q -i oppocam "$m" && say "module: $(grep -E '^version=' $m)"; done
cp /data/adb/oppocam/boot.log $OUT/boot.log 2>/dev/null
say ""
say "=== module boot log"
cat $OUT/boot.log 2>/dev/null | tee -a $S

say ""
say "=== enabling CamX logging (temporary)"
D=/data/local/tmp/camxlog
rm -rf $D; mkdir -p $D
[ -f /vendor/etc/camera/camxoverridesettings.txt ] && cat /vendor/etc/camera/camxoverridesettings.txt > $D/camxoverridesettings.txt
cat >> $D/camxoverridesettings.txt <<EOF
systemLogEnable=TRUE
logErrorMask=0xFFFFFFFF
logWarningMask=0xFFFFFFFF
logConfigMask=0xFFFFFFFF
EOF
chmod 755 $D; chmod 644 $D/camxoverridesettings.txt
chcon u:object_r:vendor_configs_file:s0 $D/camxoverridesettings.txt
chcon "$(ls -dZ /vendor/etc/camera | cut -d' ' -f1)" $D
mount -t overlay camxlog -o "lowerdir=$D:/vendor/etc/camera" /vendor/etc/camera && say "overlay on /vendor/etc/camera mounted" || say "overlay FAILED"
hal_restart

say ""
say "=== opening the camera for 15 s"
am force-stop com.oppo.camera
sleep 1
logcat -c
monkey -p com.oppo.camera -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 15
say "camera pid: $(pidof com.oppo.camera)"
dumpsys media.camera > $OUT/media_camera.txt 2>&1
input keyevent KEYCODE_HOME
sleep 2
logcat -b all -d > $OUT/logcat.txt
dmesg 2>/dev/null | grep -iE "avc:.*(camera|hal_camera)" | tail -40 > $OUT/avc.txt
say "log lines: $(wc -l < $OUT/logcat.txt)"

say ""
say "=== removing the CamX log overlay"
umount /vendor/etc/camera && say "overlay removed" || say "umount FAILED (a reboot removes it)"
rm -rf $D
hal_restart

say ""
say "=== CamX / CHI errors"
grep -E "CamX|CHIUSECASE|CHIPARTIAL|chiusecase|CamxResult|chxextension" $OUT/logcat.txt | grep -E " E |ERROR|Fail|fail|Cannot|cannot|not found|dlopen" | grep -vE "EnumerateCameras|CalcSatFov|BuildLogicalCameraInfo" | head -120 | tee -a $S
say ""
say "=== library loading errors"
grep -iE "cannot locate symbol|dlopen failed|CANNOT LINK|version .* not found|library .* not found" $OUT/logcat.txt | grep -v nativeloader | head -40 | tee -a $S
say ""
say "=== SELinux denials (camera)"
grep -E "avc: +denied" $OUT/logcat.txt | grep -iE "camera" | head -20 | tee -a $S
head -20 $OUT/avc.txt | tee -a $S
say ""
say "=== camera service errors"
grep -iE "configureStreams|onConfigureFailed|Function not implemented|ERROR_CAMERA" $OUT/logcat.txt | head -20 | tee -a $S

cd /sdcard && tar czf camdiag3.tar.gz camdiag3 && say "" && say "packed: /sdcard/camdiag3.tar.gz ($(stat -c %s camdiag3.tar.gz) bytes)"
