#!/system/bin/sh
# Turns the camera HAL's own (CamX) error/warning log on from boot, for diagnosis.
#   sh /data/local/tmp/camxlog.sh on    -> installs a KernelSU boot script, then reboot
#   sh /data/local/tmp/camxlog.sh off   -> removes it, then reboot
# The boot script mounts a log-settings file over /vendor/etc/camera in RAM only; nothing is written to /vendor.

H=/data/adb/post-fs-data.d/camxlog.sh
D=/data/adb/camxlog

case "$1" in
on)
  mkdir -p /data/adb/post-fs-data.d $D
  cat > $D/camxoverridesettings.txt <<EOF
systemLogEnable=TRUE
logErrorMask=0xFFFFFFFF
logWarningMask=0xFFFFFFFF
logConfigMask=0xFFFFFFFF
EOF
  cat > $H <<'EOF'
#!/system/bin/sh
D=/data/adb/camxlog/ovl
rm -rf $D; mkdir -p $D
[ -f /vendor/etc/camera/camxoverridesettings.txt ] && cat /vendor/etc/camera/camxoverridesettings.txt > $D/camxoverridesettings.txt
cat /data/adb/camxlog/camxoverridesettings.txt >> $D/camxoverridesettings.txt
chmod 755 $D; chmod 644 $D/camxoverridesettings.txt
chcon u:object_r:vendor_configs_file:s0 $D/camxoverridesettings.txt
chcon "$(ls -dZ /vendor/etc/camera | cut -d' ' -f1)" $D
mount -t overlay camxlog -o "lowerdir=$D:/vendor/etc/camera" /vendor/etc/camera && echo "camxlog: mounted" > /data/adb/camxlog/boot.txt || echo "camxlog: FAILED" > /data/adb/camxlog/boot.txt
EOF
  chmod 755 $H
  echo "CamX logging will be ON from the next boot - reboot now"
  ;;
off)
  rm -f $H; rm -rf $D
  echo "CamX logging removed - reboot now"
  ;;
*)
  echo "usage: sh camxlog.sh on|off"
  [ -f $H ] && echo "currently: installed ($(cat $D/boot.txt 2>/dev/null))" || echo "currently: not installed"
  ;;
esac
