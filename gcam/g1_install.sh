#!/system/bin/sh
# GCam stage 1 test install: camera APK with the GCam engine probe + libgcastartup.so (from the GCam
# port's APK) next to the camera's other native libs. Nothing about photos changes; on camera start
# it logs to tag GCAM whether Google's engine loads. Reboot afterwards.
# Needs in /data/local/tmp: OppoCamera.apk libgcastartup.so
# Undo: sh g1_install.sh undo   (puts the previous APK back, removes the library, then reboot)
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
for f in OppoCamera.apk libgcastartup.so; do [ -f $T/$f ] || { echo "missing $T/$f"; exit 1; }; done
[ -f $ST/OppoCamera.apk.pregcam ] || cp $P/OppoCamera.apk $ST/OppoCamera.apk.pregcam
cp $T/OppoCamera.apk $P/OppoCamera.apk && chmod 644 $P/OppoCamera.apk
cp $T/libgcastartup.so $P/lib/arm64/libgcastartup.so && chmod 644 $P/lib/arm64/libgcastartup.so
chcon u:object_r:system_file:s0 $P/OppoCamera.apk $P/lib/arm64/libgcastartup.so
echo "apk md5: $(md5sum $P/OppoCamera.apk | cut -c1-12)  (expect 3a0eb064df96)"
echo "lib md5: $(md5sum $P/lib/arm64/libgcastartup.so | cut -c1-12)"
echo "installed - now reboot"
