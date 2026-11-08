#!/system/bin/sh
pkill -f s960d.sh
RP=$(command -v resetprop || ls /data/adb/ksu/bin/resetprop 2>/dev/null)
[ -n "$RP" ] && "$RP" --delete oppo.camera.packname
rm -f /data/vendor/camera/client_package_name
rm -rf /data/adb/oppocam
