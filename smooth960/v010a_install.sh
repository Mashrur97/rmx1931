#!/system/bin/sh
# v0.10 step A test install: camera APK (real 960 + notification + toast + OnePlus Gallery thumbnail),
# camera-side script, root helper. Reboot afterwards (the APK change needs it).
ST=/data/adb/oppocam
MOD=/data/adb/modules/oppocam_samurai
P=$ST/payload/priv-app/OppoCamera
T=/data/local/tmp
for f in $T/OppoCamera.apk $T/libs960sh.so $T/s960d.sh; do [ -f $f ] || { echo "missing $f"; exit 1; }; done
[ -x $ST/ffmpeg ] || { [ -f $T/ffmpeg ] && cp $T/ffmpeg $ST/ffmpeg && chmod 755 $ST/ffmpeg; }
[ -x $ST/ffmpeg ] || { echo "no ffmpeg in $ST or $T"; exit 1; }
[ -f $ST/OppoCamera.apk.pre960 ] || cp $P/OppoCamera.apk $ST/OppoCamera.apk.pre960
cp $T/OppoCamera.apk $P/OppoCamera.apk && chmod 644 $P/OppoCamera.apk
cp $T/libs960sh.so $P/lib/arm64/libs960sh.so && chmod 755 $P/lib/arm64/libs960sh.so
chcon u:object_r:system_file:s0 $P/OppoCamera.apk $P/lib/arm64/libs960sh.so
rm -f $P/lib/arm64/libffmpeg_s960.so
cp $T/s960d.sh $ST/s960d.sh && chmod 755 $ST/s960d.sh
grep -q s960d $MOD/service.sh || cat >> $MOD/service.sh <<'EOS'
# real 960 slow-mo helper
[ -f $ST/s960d.sh ] && { pkill -f s960d.sh; tail -n 300 $ST/s960d.log > $ST/s960d.log.1 2>/dev/null; mv $ST/s960d.log.1 $ST/s960d.log; setsid sh $ST/s960d.sh >> $ST/s960d.log 2>&1 < /dev/null & }
EOS
pm grant com.oppo.camera android.permission.POST_NOTIFICATIONS 2>/dev/null
echo "apk md5: $(md5sum $P/OppoCamera.apk | cut -c1-12)  (expect a96d9032846e)"
echo "installed - now reboot"
