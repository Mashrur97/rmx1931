#!/system/bin/sh
# swap the camera's 960 script: "diag" installs the diagnostic one, "real" puts the real one back
L=/data/adb/oppocam/payload/priv-app/OppoCamera/lib/arm64
case "$1" in
  diag) cp /data/local/tmp/libs960sh_diag.sh $L/libs960sh.so ;;
  real) cp /data/local/tmp/libs960sh.so $L/libs960sh.so ;;
  *) echo "usage: s960diag.sh diag|real"; exit 1 ;;
esac
chmod 755 $L/libs960sh.so; chcon u:object_r:system_file:s0 $L/libs960sh.so
echo "visible to camera:"; head -3 /system/priv-app/OppoCamera/lib/arm64/libs960sh.so | tail -1
