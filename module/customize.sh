SKIPUNZIP=0
# OppoCamera (stock RealmeUI F.14) for Realme X2 Pro on Android 17 - all-in-one installer v0.10
DEV="$(getprop ro.product.vendor.device)$(getprop ro.product.device)$(getprop ro.build.product)"
case "$DEV" in
  *RMX1931*|*samurai*) ui_print "- Device OK: $DEV" ;;
  *) abort "! Only for Realme X2 Pro (RMX1931). Found: $DEV" ;;
esac
ST=/data/adb/oppocam
mkdir -p $ST
ui_print "- Installing payload (camera app + libraries) to $ST/payload"
if [ -d "$MODPATH/payload/priv-app" ]; then
  rm -rf $ST/payload.old; [ -d $ST/payload ] && mv $ST/payload $ST/payload.old
  mv "$MODPATH/payload" $ST/payload || abort "! payload move failed"
  rm -rf $ST/payload.old
  chown -R 0:0 $ST/payload; find $ST/payload -type d -exec chmod 755 {} +; find $ST/payload -type f -exec chmod 644 {} +
fi
[ -s $ST/steps ] || echo "app odm vlib csrv hal" > $ST/steps
# v0.9: 64 MP needs the OPPO-client emulation (hal) together with the privileged-camera property
grep -qw hal $ST/steps || echo "$(cat $ST/steps) hal" > $ST/steps
rm -f $ST/booting
ui_print "- Steps: [$(cat $ST/steps)]"
O=/system/bin/cameraserver
if [ "$(md5sum $O | cut -d' ' -f1)" = 51cd8d642e628eecc29baa6903b1d04d ]; then
  ui_print "- cameraserver: known build, timestamp patch will apply"
elif grep -q "tolerated for multi-frame" $O 2>/dev/null; then
  ui_print "- cameraserver: this ROM already tolerates multi-frame timestamps, no patch needed"
else
  ui_print "! cameraserver differs from tested build and isn't patched in the ROM: photo mode may hang"
fi
# v0.10 Smooth 960: root helper + ffmpeg live outside the module (kept small)
if [ -f "$MODPATH/s960/s960d.sh" ]; then
  ui_print "- Installing Smooth 960 helper to $ST"
  cp "$MODPATH/s960/ffmpeg" $ST/ffmpeg && chmod 755 $ST/ffmpeg
  cp "$MODPATH/s960/s960d.sh" $ST/s960d.sh && chmod 755 $ST/s960d.sh
  rm -rf "$MODPATH/s960"
fi
set_perm_recursive "$MODPATH" 0 0 0755 0644
for f in post-fs-data.sh service.sh uninstall.sh oppocam.sh; do set_perm "$MODPATH/$f" 0 0 0755; done
set_perm "$MODPATH/csrv/cameraserver" 0 2000 0755
ui_print "- Done. Reboot. Helper: su -c sh /data/adb/modules/oppocam_samurai/oppocam.sh status"
ui_print "- Bootloop? Hold volume-down during boot (KSU safe mode); failed steps auto-disable next boot"
