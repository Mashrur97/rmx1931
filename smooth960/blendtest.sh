#!/system/bin/sh
# Smooth 960: blend vs best on the same clip. Runs a private copy of the helper (camera untouched),
# times both, saves both results and a side-by-side to /sdcard/Download.
# usage (as root): sh blendtest.sh /sdcard/DCIM/Camera/VIDxxxx.mp4   (a raw 480 clip, 21 s or longer)
D=/data/adb/oppocam
B=/data/local/tmp/s960blend
OUT=/sdcard/Download
clip="$1"
[ -n "$clip" ] && [ -f "$clip" ] || { echo "usage: sh blendtest.sh /sdcard/DCIM/Camera/VIDxxxx.mp4"; exit 1; }
HELPER=${S960_HELPER:-$D/s960d.sh}
[ -f "$HELPER" ] || { echo "helper not found: $HELPER"; exit 1; }
grep -q "quality=blend" "$HELPER" || { echo "this helper has no blend mode - push the new s960d.sh and run with S960_HELPER=/data/local/tmp/s960d.sh"; exit 1; }
rm -rf $B; mkdir -p $B/q; touch $B/front
S960_Q=$B/q S960_W=$B/w S960_CAMFRONT=$B/front S960_FF=$D/ffmpeg sh "$HELPER" > $B/helper.log 2>&1 &
HP=$!
trap 'kill $HP 2>/dev/null; pkill -P $HP 2>/dev/null' EXIT INT TERM
sleep 1

run() {   # run <name> <options>
  : > $B/$1.mp4; : > $B/q/status; : > $B/q/progress
  printf '%s\n%s\n%s\n%s\n' "$clip" "$B/$1.mp4" 2 "$2" > $B/q/job.tmp; mv $B/q/job.tmp $B/q/job
  i=0; s=""
  while [ $i -lt 900 ]; do
    s=$(cat $B/q/status 2>/dev/null); [ -n "$s" ] && break
    p=$(cat $B/q/progress 2>/dev/null); set -- $p
    [ -n "$2" ] && [ "$2" -gt 0 ] && printf '\r   %-6s %3d%%' "$NAME" $((100*$1/$2))
    sleep 1; i=$((i+1))
  done
  printf '\r'
  case "$s" in "OK "*) echo "$NAME: ${s#OK } s"; cp $B/$NAME.mp4 $OUT/s960_$NAME.mp4 ;; *) echo "$NAME: FAIL (${s:-timeout}) - see $B/helper.log"; return 1 ;; esac
}
echo "== clip: $clip"
NAME=blend; run blend "quality=blend denoise=off" || exit 1
sleep 20
NAME=best;  run best  "quality=best denoise=off" || exit 1
echo "== side by side (blend left, best right)"
$D/ffmpeg -hide_banner -loglevel error -nostdin -i $OUT/s960_blend.mp4 -i $OUT/s960_best.mp4 \
  -filter_complex "[0:v]scale=-2:960[a];[1:v]scale=-2:960[b];[a][b]hstack=2" -an \
  -c:v libx264 -crf 20 -preset veryfast -pix_fmt yuv420p -y $OUT/s960_blend_vs_best.mp4 \
  && echo "   $OUT/s960_blend_vs_best.mp4"
echo "== done: $OUT/s960_blend.mp4, $OUT/s960_best.mp4"
