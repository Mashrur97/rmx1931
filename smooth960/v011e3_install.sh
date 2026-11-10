#!/system/bin/sh
# v0.11 step E3 test install (APK only): video Noise reduction + Sharpening lists, 60 fps switch (diagnostic log on).
# Helper scripts stay as installed in step D. Reboot afterwards.
# Undo: sh v011e3_install.sh undo   (puts the v0.10 APK back, then reboot)
ST=/data/adb/oppocam
P=$ST/payload/priv-app/OppoCamera
T=/data/local/tmp
if [ "$1" = undo ]; then
  [ -f $ST/OppoCamera.apk.v010 ] || { echo "no v0.10 backup"; exit 1; }
  cp $ST/OppoCamera.apk.v010 $P/OppoCamera.apk && chmod 644 $P/OppoCamera.apk
  chcon u:object_r:system_file:s0 $P/OppoCamera.apk
  echo "v0.10 APK restored - now reboot"; exit 0
fi
[ -f $T/OppoCamera.apk ] || { echo "missing $T/OppoCamera.apk"; exit 1; }
[ -f $ST/OppoCamera.apk.v010 ] || cp $P/OppoCamera.apk $ST/OppoCamera.apk.v010
cp $T/OppoCamera.apk $P/OppoCamera.apk && chmod 644 $P/OppoCamera.apk
chcon u:object_r:system_file:s0 $P/OppoCamera.apk
echo "apk md5: $(md5sum $P/OppoCamera.apk | cut -c1-12)  (expect f0cbd05668f8)"
echo "installed - now reboot"
