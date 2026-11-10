#!/system/bin/sh
# GCam stage 2a test install: camera APK that, after the stage 1 probe, builds the main camera's
# StaticMetadata (sensor, colour calibration, RAW size...) and calls Gcam_Create. Photos unchanged.
# libgcastartup.so from stage 1 stays. Logs to tag GCAM. Reboot afterwards.
# Crash guard: if Gcam_Create kills the camera, files/gcam2a.lock stays and later starts skip the test.
# Needs in /data/local/tmp: OppoCamera.apk
# Undo: sh g2a_install.sh undo   (back to the pre-GCam APK, library removed, then reboot)
# Retry after a crash: sh g2a_install.sh unlock
ST=/data/adb/oppocam
P=$ST/payload/priv-app/OppoCamera
T=/data/local/tmp
if [ "$1" = undo ]; then
  [ -f $ST/OppoCamera.apk.pregcam ] || { echo "no backup"; exit 1; }
  cp $ST/OppoCamera.apk.pregcam $P/OppoCamera.apk && chmod 644 $P/OppoCamera.apk
  chcon u:object_r:system_file:s0 $P/OppoCamera.apk
  rm -f $P/lib/arm64/libgcastartup.so
  echo "restored - now reboot"; exit 0
fi
if [ "$1" = unlock ]; then
  rm -f /data/user/0/com.oppo.camera/files/gcam2a.lock
  echo "lock removed - open the camera again"; exit 0
fi
[ -f $T/OppoCamera.apk ] || { echo "missing $T/OppoCamera.apk"; exit 1; }
[ -f $P/lib/arm64/libgcastartup.so ] || { echo "libgcastartup.so not installed - run g1_install.sh first"; exit 1; }
[ -f $ST/OppoCamera.apk.pregcam ] || cp $P/OppoCamera.apk $ST/OppoCamera.apk.pregcam
cp $T/OppoCamera.apk $P/OppoCamera.apk && chmod 644 $P/OppoCamera.apk
chcon u:object_r:system_file:s0 $P/OppoCamera.apk
rm -f /data/user/0/com.oppo.camera/files/gcam2a.lock
echo "apk md5: $(md5sum $P/OppoCamera.apk | cut -c1-12)  (expect 3e11b931147f)"
echo "installed - now reboot"
