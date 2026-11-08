#!/system/bin/sh
PATH=/system/bin:$PATH
MODDIR=${0%/*}
ST=/data/adb/oppocam
LOG=$ST/boot.log
exec >>"$LOG" 2>&1

until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 2; done
rm -f $ST/booting; sync
echo "=== boot completed $(date) - marker cleared"

STEPS=$(cat $ST/steps 2>/dev/null)
case " $STEPS " in *" hal "*) sh $MODDIR/oppocam.sh writefile ;; esac
case " $STEPS " in *" app "*)
  n=0; until pm path com.oppo.camera >/dev/null 2>&1 || [ $n -ge 60 ]; do sleep 2; n=$((n+1)); done
  sh $MODDIR/oppocam.sh grant
  echo "pkg: $(pm path com.oppo.camera)" ;;
esac
# v0.10 Smooth 960 helper (runs ffmpeg outside the camera's sandbox)
if [ -f $ST/s960d.sh ]; then
  pkill -f s960d.sh
  tail -n 300 $ST/s960d.log > $ST/s960d.log.1 2>/dev/null; mv $ST/s960d.log.1 $ST/s960d.log
  setsid sh $ST/s960d.sh >> $ST/s960d.log 2>&1 < /dev/null &
  echo "s960d started"
fi
