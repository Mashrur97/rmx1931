#!/system/bin/sh
# Real-960: install the root helper (runs ffmpeg outside the camera's sandbox) and the camera-side script.
ST=/data/adb/oppocam
MOD=/data/adb/modules/oppocam_samurai
L=$ST/payload/priv-app/OppoCamera/lib/arm64
T=/data/local/tmp
for f in $T/ffmpeg $T/s960d.sh $T/libs960sh.so; do [ -f $f ] || { echo "missing $f"; exit 1; }; done
cp $T/ffmpeg $ST/ffmpeg && chmod 755 $ST/ffmpeg
cp $T/s960d.sh $ST/s960d.sh && chmod 755 $ST/s960d.sh
cp $T/libs960sh.so $L/libs960sh.so && chmod 755 $L/libs960sh.so && chcon u:object_r:system_file:s0 $L/libs960sh.so
rm -f $L/libffmpeg_s960.so          # not used any more (can't run inside the camera's sandbox)
# start the helper at every boot
if ! grep -q s960d $MOD/service.sh; then
  cat >> $MOD/service.sh <<'EOS'
# real 960 slow-mo helper
[ -f $ST/s960d.sh ] && { pkill -f s960d.sh; tail -n 300 $ST/s960d.log > $ST/s960d.log.1 2>/dev/null; mv $ST/s960d.log.1 $ST/s960d.log; setsid sh $ST/s960d.sh >> $ST/s960d.log 2>&1 < /dev/null & }
EOS
  echo "added helper start to module service.sh"
fi
# start it now
pkill -f s960d.sh; sleep 1
setsid sh $ST/s960d.sh >> $ST/s960d.log 2>&1 < /dev/null &
sleep 1
pgrep -f s960d.sh >/dev/null && echo "helper running: $(tail -1 $ST/s960d.log)" || echo "helper did NOT start - check $ST/s960d.log"
echo "camera sees: $(sed -n 2p /system/priv-app/OppoCamera/lib/arm64/libs960sh.so)"
