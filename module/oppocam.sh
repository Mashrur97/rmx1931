#!/system/bin/sh
PATH=/system/bin:$PATH
# Helper. Run as root:  su -c "sh /data/adb/modules/oppocam_samurai/oppocam.sh <cmd>"
#   payload         - install /data/local/tmp/oppocam_payload.zip into /data/adb/oppocam
#   status          - what is enabled, last boot log, what the HAL sees
#   enable <step>   - turn a step on (takes effect next reboot). steps: app odm vlib csrv hal
#   disable <step>  - turn a step off
#   grant           - grant the app its runtime permissions
#   clear / collect - clear logs before a camera test / save logs to /sdcard/Download
MODDIR=/data/adb/modules/oppocam_samurai
ST=/data/adb/oppocam; mkdir -p $ST
RP=$(command -v resetprop || ls /data/adb/ksu/bin/resetprop 2>/dev/null)
setp() { if [ -n "$RP" ]; then "$RP" "$1" "$2"; else setprop "$1" "$2"; fi; }
F=/data/vendor/camera/client_package_name
S=$ST/steps

writefile() {
  [ -d /data/vendor/camera ] || return
  echo com.oppo.camera > $F; chmod 0644 $F; restorecon $F 2>/dev/null
}

case "$1" in
  enable)
    touch $S
    if ! grep -qw "$2" $S; then echo "$(cat $S) $2" | xargs > $S.n; mv $S.n $S; fi
    echo "steps: $(cat $S)  (reboot to apply)" ;;
  disable) touch $S; tr ' ' '\n' < $S | grep -vx "$2" | xargs > $S.n; mv $S.n $S; echo "steps: $(cat $S)  (reboot to apply)" ;;
  writefile) writefile ;;
  payload)
    Z=${2:-/data/local/tmp/oppocam_payload.zip}
    [ -f "$Z" ] || { echo "not found: $Z (adb push it first)"; exit 1; }
    BB=$(ls /data/adb/ksu/bin/busybox /data/adb/magisk/busybox 2>/dev/null | head -1)
    rm -rf $ST/payload.new && mkdir -p $ST/payload.new
    if [ -n "$BB" ]; then $BB unzip -oq "$Z" -d $ST/payload.new; else unzip -oq "$Z" -d $ST/payload.new; fi || { echo "unzip failed"; exit 1; }
    [ -f $ST/payload.new/priv-app/OppoCamera/OppoCamera.apk ] || { echo "zip layout wrong"; exit 1; }
    rm -rf $ST/payload && mv $ST/payload.new $ST/payload
    chown -R 0:0 $ST/payload; find $ST/payload -type d -exec chmod 755 {} +; find $ST/payload -type f -exec chmod 644 {} +
    echo "payload installed: $(du -sh $ST/payload | cut -f1)  apk md5 $(md5sum $ST/payload/priv-app/OppoCamera/OppoCamera.apk | cut -c1-12)"
    rm -f "$Z" ;;
  grant)
    for p in CAMERA RECORD_AUDIO ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION \
             READ_EXTERNAL_STORAGE WRITE_EXTERNAL_STORAGE READ_PHONE_STATE POST_NOTIFICATIONS; do
      pm grant com.oppo.camera android.permission.$p 2>&1 | grep -v '^$'
    done; echo "permissions granted" ;;
  status)
    echo "steps enabled:  [$(cat $S 2>/dev/null)]"
    [ -f $ST/last_failed_steps ] && echo "LAST FAILED BOOT had steps: [$(cat $ST/last_failed_steps)]"
    echo "prop: $(getprop oppo.camera.packname)  [$(getprop -Z oppo.camera.packname)]"
    echo "file: $(cat $F 2>/dev/null)"
    echo "pkg:  $(pm path com.oppo.camera)"
    echo "smooth960 helper: $(pgrep -f s960d.sh >/dev/null && echo running || echo NOT running) - $(tail -1 $ST/s960d.log 2>/dev/null)"
    echo "mounts:"; grep oppocam /proc/mounts | awk '{print "  "$2}'
    echo "--- boot.log"; cat $ST/boot.log
    [ -f $ST/boot.log.old ] && { echo "--- boot.log.old"; cat $ST/boot.log.old; }
    ;;
  clear)   logcat -c; echo "logs cleared - open the camera, wait ~15s, then run collect" ;;
  collect)
    D=/sdcard/Download
    logcat -d -b main,system,crash > $D/oppocam_logcat.txt
    dmesg | grep -iE 'avc|camera' > $D/oppocam_dmesg.txt
    { sh $0 status; echo; dumpsys media.camera | head -150; ls -lt /data/tombstones | head -4; } > $D/oppocam_status.txt
    echo "saved: $D/oppocam_logcat.txt oppocam_dmesg.txt oppocam_status.txt"
    ;;
  *) sed -n '3,10p' $0 ;;
esac
