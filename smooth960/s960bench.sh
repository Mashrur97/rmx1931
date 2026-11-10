#!/system/bin/sh
# Smooth 960 benchmark: times the real helper on one clip with different settings.
# Runs a private copy of s960d.sh (own queue/work dirs), so the camera's helper is untouched.
# usage (as root): sh s960bench.sh /sdcard/DCIM/Camera/VIDxxxx.mp4 [cooldown_seconds]
# Keep the screen off while it runs. Results also go to /sdcard/Download/s960bench.txt
D=/data/adb/oppocam
B=/data/local/tmp/s960bench
clip="$1"; cool="${2:-30}"
[ -n "$clip" ] && [ -f "$clip" ] || { echo "usage: sh s960bench.sh /sdcard/DCIM/Camera/VIDxxxx.mp4"; exit 1; }
[ -f $D/s960d.sh ] || { echo "helper not found in $D"; exit 1; }
rm -rf $B; mkdir -p $B/q
touch $B/front
RES=/sdcard/Download/s960bench.txt

S960_Q=$B/q S960_W=$B/w S960_CAMFRONT=$B/front S960_FF=$D/ffmpeg sh $D/s960d.sh > $B/helper.log 2>&1 &
HP=$!
trap 'kill $HP 2>/dev/null; pkill -P $HP 2>/dev/null' EXIT INT TERM
sleep 1

# run <label> <options>  -> prints seconds, or FAIL
run() {
  : > $B/out.mp4; : > $B/q/status; : > $B/q/progress
  printf '%s\n%s\n%s\n%s\n' "$clip" "$B/out.mp4" 2 "$2" > $B/q/job.tmp
  mv $B/q/job.tmp $B/q/job
  i=0; s=""
  while [ $i -lt 900 ]; do
    s=$(cat $B/q/status 2>/dev/null); [ -n "$s" ] && break
    p=$(cat $B/q/progress 2>/dev/null); set -- $p
    [ -n "$2" ] && [ "$2" -gt 0 ] && printf '\r   %-24s %3d%%' "$LABEL" $((100*$1/$2))
    sleep 1; i=$((i+1))
  done
  printf '\r'
  case "$s" in
    "OK "*) t=${s#OK }; line=$(printf '%-24s %4ss   %s' "$LABEL" "$t" "$(ls -l $B/out.mp4 | awk '{printf "%.1f MB", $5/1048576}')") ;;
    *) line=$(printf '%-24s FAIL (%s)' "$LABEL" "${s:-timeout}") ;;
  esac
  echo "$line"; echo "$line" >> $RES
}

{ echo "Smooth 960 benchmark $(date '+%Y-%m-%d %H:%M')  clip: $(basename "$clip")"; } > $RES
echo "== clip: $clip   (cooldown ${cool}s between runs)"
best=""; bt=99999
for c in 2 4 6 8; do
  LABEL="cores=$c balanced"
  run x "cores=$c quality=balanced"
  t=$(tail -1 $RES | awk '{print $3}' | tr -d s)
  case "$t" in ''|*[!0-9]*) ;; *) [ "$t" -lt "$bt" ] && { bt=$t; best=$c; } ;; esac
  sleep "$cool"
done
[ -z "$best" ] && { echo "no run finished - see $B/helper.log"; exit 1; }
echo "== fastest core count: $best"
for q in fast best; do
  LABEL="cores=$best $q"
  run x "cores=$best quality=$q"
  sleep "$cool"
done
echo "== results saved to $RES"
