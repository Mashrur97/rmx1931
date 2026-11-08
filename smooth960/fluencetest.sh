#!/system/bin/sh
# Live test of Qualcomm Fluence (dual-mic noise suppression) for recording. Undone by a reboot.
#   sh fluencetest.sh on     -> enable + restart audio
#   sh fluencetest.sh log    -> show which input device the HAL picked for the last recording
RP=$(command -v resetprop || ls /data/adb/ksu/bin/resetprop 2>/dev/null)
case "$1" in
  on)
    "$RP" ro.vendor.audio.sdk.fluencetype fluence
    setprop persist.vendor.audio.fluence.audiorec true
    setprop persist.vendor.audio.fluence.voicerec true
    logcat -c
    pkill -f android.hardware.audio.service; pkill -f vendor.audio-hal; pkill audioserver
    sleep 3
    echo "fluencetype=$(getprop ro.vendor.audio.sdk.fluencetype) audiorec=$(getprop persist.vendor.audio.fluence.audiorec)"
    echo "audio restarted - record a test video now, then: sh fluencetest.sh log" ;;
  log)
    logcat -d | grep -iE "in_snd_device|select_devices|fluence|SND_DEVICE_IN" | tail -15 ;;
  *) echo "usage: fluencetest.sh on|log  (reboot to undo)" ;;
esac
