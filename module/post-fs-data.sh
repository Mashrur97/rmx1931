#!/system/bin/sh
PATH=/system/bin:$PATH
# OppoCamera v0.11.2 - runs before zygote/HALs start.
# - Nothing is changed unless enabled in $MODDIR/steps (see oppocam.sh).
# - Auto-rollback: if the previous boot never reached boot_completed,
#   this boot changes nothing (service.sh clears the marker on success).
MODDIR=${0%/*}
ST=/data/adb/oppocam            # state + payload live here (KernelSU never copies this)
P=$ST/payload
LOG=$ST/boot.log
mkdir -p $ST
[ -f "$LOG" ] && tail -n 300 "$LOG" > "$LOG.old"
exec >"$LOG" 2>&1
echo "=== post-fs-data $(date) uptime=$(cut -d' ' -f1 /proc/uptime)"

STEPS=$(cat $ST/steps 2>/dev/null)
echo "steps enabled: [${STEPS}]"

if [ -f $ST/booting ]; then
  echo "!!! previous boot did not complete with steps [$(cat $ST/booting)]"
  echo "!!! AUTO-ROLLBACK: skipping everything this boot"
  cp $ST/booting $ST/last_failed_steps
  rm -f $ST/booting; sync
  exit 0
fi
[ -d $P/priv-app ] || { echo "no payload in $P yet - run: oppocam.sh payload"; exit 0; }
echo "$STEPS" > $ST/booting; sync

on() { case " $STEPS " in *" $1 "*) return 0 ;; esac; return 1; }

ctx() { ls -Zd "$1" 2>/dev/null | awk '{print $1}'; }
RP=$(command -v resetprop || ls /data/adb/ksu/bin/resetprop 2>/dev/null)
setp() { if [ -n "$RP" ]; then "$RP" "$1" "$2"; else setprop "$1" "$2"; fi; }

ovl() { # ovl <target dir> <payload dir> <file context>
  [ -d "$1" ] && [ -d "$2" ] || { echo "skip ovl $1 (missing)"; return; }
  chcon -R "$3" "$2"; chcon "$(ctx "$1")" "$2"
  mount -t overlay oppocam -o "lowerdir=$2:$1" "$1" && echo "mounted $1" || echo "FAILED mount $1"
}

if on app; then
  echo "-- step app"
  ovl /system/priv-app        $P/priv-app        u:object_r:system_file:s0
  ovl /system/etc/permissions $P/etc/permissions u:object_r:system_file:s0
  ovl /system/etc/sysconfig   $P/etc/sysconfig   u:object_r:system_file:s0
  # SELinux rules for the app/HAL are in sepolicy.rule (KernelSU loads them once, in one batch).
  # Never live-patch sepolicy here: repeated live policy reloads crashed this kernel.
fi

if on odm; then
  echo "-- step odm"
  LIBCTX=$(ctx /odm/lib64/libAlgoProcess.so); [ -n "$LIBCTX" ] || LIBCTX=u:object_r:same_process_hal_file:s0
  CAMCTX=$(ctx /odm/etc/camera/CameraHWConfiguration.config); [ -n "$CAMCTX" ] || CAMCTX=u:object_r:vendor_configs_file:s0
  echo "libctx=$LIBCTX camctx=$CAMCTX"
  # v0.11.1: newer builds install libWaterMark in /odm instead of /vendor; then our fixed copy (+ shim) goes
  # into the odm overlay so it shadows the original there.
  rm -f $P/odm_lib64/libWaterMark.so $P/odm_lib64/libui_wmshim.so
  if [ "$(md5sum /odm/lib64/libWaterMark.so 2>/dev/null | cut -d' ' -f1)" = 3230275c2b0af925503316ccc973d14d ]; then
    cp $MODDIR/vlib/libWaterMark.so $MODDIR/vlib/libui_wmshim.so $P/odm_lib64/ && chmod 644 $P/odm_lib64/libWaterMark.so $P/odm_lib64/libui_wmshim.so
    echo "libWaterMark.so is in /odm: watermark shim added to the odm overlay"
  fi
  ovl /odm/lib64      $P/odm_lib64  "$LIBCTX"
  # v0.11.2: some builds (Nov 10 2026) don't install the 2MP depth sensor (OV02A1B) files; then they come from the module
  rm -rf $P/odm_camera/config
  if [ ! -f /odm/etc/camera/config/ov02a1b ]; then
    mkdir -p $P/odm_camera/config && cp $MODDIR/depth/ov02a1b $P/odm_camera/config/ && chmod 755 $P/odm_camera/config && chmod 644 $P/odm_camera/config/ov02a1b
    echo "depth sensor: /odm/etc/camera/config/ov02a1b missing - added"
  fi
  ovl /odm/etc/camera $P/odm_camera "$CAMCTX"
fi

if on vlib; then
  echo "-- step vlib"
  # vendor libs the HAL namespace is missing on A17:
  #  libstdc++.so  - needed by libOPPORectify/libCOppLceTonemapAPI (sat + preview nodes); copied from /system
  #  libui_wmshim  - old GraphicBufferMapper::unlock for libWaterMark (watermark node); libWaterMark patched to load it
  V=$ST/vlib; rm -rf $V; mkdir -p $V
  if [ "$(md5sum /vendor/lib64/libWaterMark.so 2>/dev/null | cut -d' ' -f1)" = 3230275c2b0af925503316ccc973d14d ]; then
    cp $MODDIR/vlib/libWaterMark.so $MODDIR/vlib/libui_wmshim.so $V/
  elif [ ! -f /vendor/lib64/libWaterMark.so ]; then echo "libWaterMark.so not in /vendor (newer build) - handled in step odm"
  else echo "libWaterMark.so md5 differs - watermark shim skipped"; fi
  cp /system/lib64/libstdc++.so $V/ || echo "no /system/lib64/libstdc++.so"
  # v0.11.2: depth sensor (OV02A1B) module + tuning, missing on some builds: without the sensormodule the sensor is never
  # probed and logical camera 7 (Photo mode) collapses to one device -> configure_streams -38
  if [ ! -f /vendor/lib64/camera/com.qti.sensormodule.shine_ov02a1b.bin ]; then
    mkdir -p $V/camera && cp $MODDIR/depth/com.qti.sensormodule.shine_ov02a1b.bin $MODDIR/depth/com.qti.tuned.shine_ov02a1b.bin $V/camera/
    echo "depth sensor: sensormodule/tuned missing in /vendor - added"
  fi
  if [ ! -f /vendor/lib64/libarcsoft_time_convert.so ]; then
    cp $MODDIR/depth/libarcsoft_time_convert.so $V/ && echo "libarcsoft_time_convert.so missing in /vendor - added"
  fi
  find $V -type f -exec chmod 644 {} +; find $V -type d -exec chmod 755 {} +
  WCTX=$(ctx /vendor/lib64/libWaterMark.so); [ -n "$WCTX" ] || WCTX=u:object_r:vendor_file:s0
  SCTX=$(ctx /vendor/lib64/libion.so);       [ -n "$SCTX" ] || SCTX=u:object_r:same_process_hal_file:s0
  [ -f $V/libWaterMark.so ] && chcon "$WCTX" $V/libWaterMark.so $V/libui_wmshim.so
  [ -f $V/libstdc++.so ] && chcon "$SCTX" $V/libstdc++.so
  VCTX=$(ctx /vendor/lib64/libarcsoft_beautyshot.so); [ -n "$VCTX" ] || VCTX=u:object_r:vendor_file:s0
  [ -f $V/libarcsoft_time_convert.so ] && chcon "$VCTX" $V/libarcsoft_time_convert.so
  if [ -d $V/camera ]; then
    CCTX=$(ctx /vendor/lib64/camera/com.qti.sensor.ov02a1b.so); [ -n "$CCTX" ] || CCTX=u:object_r:vendor_file:s0
    chcon "$CCTX" $V/camera/*; chcon "$(ctx /vendor/lib64/camera)" $V/camera
  fi
  chcon "$(ctx /vendor/lib64)" $V
  ls -lZ $V
  mount -t overlay oppocam -o "lowerdir=$V:/vendor/lib64" /vendor/lib64 && echo "mounted /vendor/lib64" || echo "FAILED mount /vendor/lib64"
fi

if on csrv; then
  echo "-- step csrv"
  # cameraserver (libcameraservice is static on this ROM) patched at 0x22ae18: tbz -> b
  # so multi-frame capture buffers with non-increasing timestamps are not marked ERROR.
  # v0.11.1: two known builds - Infinity-X before Nov 10 2026 (patch at 0x22ae18) and the Nov 10 build (0x237970)
  O=/system/bin/cameraserver; N=; NM=
  case "$(md5sum $O | cut -d' ' -f1)" in
    51cd8d642e628eecc29baa6903b1d04d) N=$MODDIR/csrv/cameraserver;   NM=88a7f15d6e8faee1a565fd1ab5f5d99f ;;
    22101b52a2af6ca3e843c02ca9dd8794) N=$MODDIR/csrv/cameraserver_b; NM=eec0c658a88d105001bc8b703e48862d ;;
  esac
  if [ -n "$N" ] && [ "$(md5sum $N | cut -d' ' -f1)" = "$NM" ]; then
    # NOT a bind mount: a file bind-mounted from /data keeps /data's nosuid flag, and init's
    # exec transition into the cameraserver domain is then refused (security_bounded_transition).
    # An overlay on /system/bin is a fresh mount without nosuid.
    C=$ST/csrv_bin; rm -rf $C; mkdir -p $C; cp $N $C/cameraserver
    chmod 755 $C/cameraserver; chown 0:2000 $C/cameraserver; chcon "$(ctx $O)" $C/cameraserver
    chcon "$(ctx /system/bin)" $C
    mount -t overlay oppocam -o "lowerdir=$C:/system/bin" /system/bin && echo "mounted /system/bin ($(ctx $O))" || echo "FAILED mount /system/bin"
  elif grep -q "tolerated for multi-frame" $O 2>/dev/null; then echo "cameraserver: ROM already has the multi-frame timestamp fix - patch not needed"
  else echo "cameraserver: unknown build and no ROM fix found - not patched (photo mode may hang)"; fi
fi

# (step "pub" removed in v0.3: ROM already lists the camera libs as public)

if on hal; then
  echo "-- step hal"
  setp oppo.camera.packname com.oppo.camera
  echo "packname=$(getprop oppo.camera.packname) [$(getprop -Z oppo.camera.packname)]"
fi

# Let the OPPO camera keep its full-size YUV streams (16 MP front, 64 MP): Android 17's cameraserver rounds
# unlisted sizes down to the nearest advertised one unless the app is in this list (CAF privileged-client bypass).
PL=$(getprop persist.vendor.camera.privapp.list)
case ",$PL," in *,com.oppo.camera,*) ;; *) setp persist.vendor.camera.privapp.list "${PL:+$PL,}com.oppo.camera" ;; esac
echo "privapp.list=$(getprop persist.vendor.camera.privapp.list)"
echo "=== post-fs-data done"; sync
