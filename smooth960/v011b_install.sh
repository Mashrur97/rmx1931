#!/system/bin/sh
# v0.11 step B test install: settings now take effect (cores, priority, quality, denoise,
# output quality, deflicker), progress ring on the shutter, pause-viewfinder page.
# Needs in /data/local/tmp: OppoCamera.apk libs960sh.so s960d.sh. Reboot afterwards.
# Undo: sh v011b_install.sh undo   (v0.10 APK + scripts back, then reboot)
ST=/data/adb/oppocam
P=$ST/payload/priv-app/OppoCamera
T=/data/local/tmp
if [ "$1" = undo ]; then
  for f in OppoCamera.apk.v010 libs960sh.so.v010 s960d.sh.v010; do [ -f $ST/$f ] || { echo "no backup $f"; exit 1; }; done
  cp $ST/OppoCamera.apk.v010 $P/OppoCamera.apk && chmod 644 $P/OppoCamera.apk
  cp $ST/libs960sh.so.v010 $P/lib/arm64/libs960sh.so && chmod 755 $P/lib/arm64/libs960sh.so
  chcon u:object_r:system_file:s0 $P/OppoCamera.apk $P/lib/arm64/libs960sh.so
  cp $ST/s960d.sh.v010 $ST/s960d.sh && chmod 755 $ST/s960d.sh
  echo "v0.10 restored - now reboot"; exit 0
fi
for f in OppoCamera.apk libs960sh.so s960d.sh; do [ -f $T/$f ] || { echo "missing $T/$f"; exit 1; }; done
[ -f $ST/OppoCamera.apk.v010 ] || cp $P/OppoCamera.apk $ST/OppoCamera.apk.v010
[ -f $ST/libs960sh.so.v010 ] || cp $P/lib/arm64/libs960sh.so $ST/libs960sh.so.v010
[ -f $ST/s960d.sh.v010 ] || cp $ST/s960d.sh $ST/s960d.sh.v010
cp $T/OppoCamera.apk $P/OppoCamera.apk && chmod 644 $P/OppoCamera.apk
cp $T/libs960sh.so $P/lib/arm64/libs960sh.so && chmod 755 $P/lib/arm64/libs960sh.so
chcon u:object_r:system_file:s0 $P/OppoCamera.apk $P/lib/arm64/libs960sh.so
cp $T/s960d.sh $ST/s960d.sh && chmod 755 $ST/s960d.sh
echo "apk md5: $(md5sum $P/OppoCamera.apk | cut -c1-12)  (expect e8d3beab447f)"
echo "installed - now reboot"
