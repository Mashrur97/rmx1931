#!/system/bin/sh
# Lists the dual-mic / fluence record routes in the audio config, plus the audio HAL's fluence props.
echo "== mixer_paths files"
ls /vendor/etc/mixer_paths*.xml /vendor/etc/audio/*/mixer_paths*.xml /odm/etc/mixer_paths*.xml 2>/dev/null
echo "== dual-mic / fluence paths"
for f in /vendor/etc/mixer_paths*.xml /vendor/etc/audio/*/mixer_paths*.xml /odm/etc/mixer_paths*.xml; do
  [ -f "$f" ] && grep -ioE 'path name="[^"]*(dmic|fluence|endfire|broadside)[^"]*"' "$f"
done | sort -u | head -40
echo "== audio platform info (device -> backend)"
for f in /vendor/etc/audio_platform_info*.xml /vendor/etc/audio/*/audio_platform_info*.xml /odm/etc/audio_platform_info*.xml; do
  [ -f "$f" ] && { echo "-- $f"; grep -ioE '(name|device)="[^"]*(DMIC|FLUENCE|ENDFIRE)[^"]*"' "$f" | sort -u | head -15; }
done
echo "== fluence props"
getprop | grep -i fluence
