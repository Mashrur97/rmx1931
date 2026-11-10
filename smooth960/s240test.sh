#!/system/bin/sh
# Test: "960 from 240" - interpolate a slice of a 1080p 240 fps clip x2 (480-like) and x4 (960-like)
# with the Smooth 960 "best" settings, 6 chunks in parallel, and time both.
# usage (as root): sh s240test.sh /sdcard/DCIM/Camera/VIDxxxx.mp4 [start_s] [seconds]
#   default: 2 s of playback from the middle of the clip
# Results in /sdcard/Download: s240_orig.mp4 (the slice as recorded), s240_x2.mp4, s240_x4.mp4
FF=${S960_FF:-/data/adb/oppocam/ffmpeg}
W=${S240_W:-/data/local/tmp/s240test}
OUT=${S240_OUT:-/sdcard/Download}
N=6
MI="mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1:mb_size=8"
ENC="-c:v libx264 -crf 18 -preset veryfast -pix_fmt yuv420p -threads 2 -an"
clip="$1"
[ -n "$clip" ] && [ -f "$clip" ] || { echo "usage: sh s240test.sh /sdcard/DCIM/Camera/VIDxxxx.mp4 [start_s] [seconds]"; exit 1; }
dur=${3:-2}
if [ -n "$2" ]; then ss=$2; else
  len=$($FF -hide_banner -i "$clip" 2>&1 | sed -n 's/.*Duration: \([0-9]*\):\([0-9]*\):\([0-9]*\).*/\1 \2 \3/p' | { read h m s; echo $((h*3600+m*60+s)); })
  ss=$(( len/2 - dur/2 )); [ $ss -lt 0 ] && ss=0
fi
rm -rf $W; mkdir -p $W
trap 'pkill -P $$ 2>/dev/null' EXIT INT TERM
F=$((dur*30))
echo "== clip: $clip  slice ${ss}s +${dur}s ($F frames)"
t0=$(date +%s)
$FF -hide_banner -loglevel error -nostdin -ss $ss -t $dur -i "$clip" -an -vf "setpts=N/(30*TB)" -r 30 \
  -frames:v $F -c:v libx264 -crf 10 -preset ultrafast -pix_fmt yuv420p -y $W/cut.mp4 || exit 1
n=$($FF -hide_banner -nostdin -i $W/cut.mp4 -map 0:v -c copy -f framecrc - 2>/dev/null | grep -vc '^#')
echo "   cut: $n frames in $(( $(date +%s) - t0 ))s"
$FF -hide_banner -loglevel error -nostdin -i $W/cut.mp4 $ENC -y $OUT/s240_orig.mp4

for f in 2 4; do
  t0=$(date +%s); pids=""; : > $W/list$f.txt
  i=0
  while [ $i -lt $N ]; do
    a=$(( i*n/N )); b=$(( (i+1)*n/N )); e=$(( b+2 )); [ $e -gt $n ] && e=$n
    $FF -hide_banner -loglevel error -nostdin -i $W/cut.mp4 \
      -vf "trim=start_frame=$a:end_frame=$e,setpts=N/(30*TB),minterpolate=fps=$((30*f)):$MI,setpts=N/(30*TB)" \
      -frames:v $(( f*(b-a) )) -r 30 $ENC -y $W/c${f}_$i.mp4 &
    pids="$pids $!"
    echo "file 'c${f}_$i.mp4'" >> $W/list$f.txt
    i=$((i+1))
  done
  for p in $pids; do wait $p || echo "   chunk failed ($p)"; done
  $FF -hide_banner -loglevel error -nostdin -f concat -safe 0 -i $W/list$f.txt -c copy -y $OUT/s240_x$f.mp4 || exit 1
  m=$($FF -hide_banner -nostdin -i $OUT/s240_x$f.mp4 -map 0:v -c copy -f framecrc - 2>/dev/null | grep -vc '^#')
  echo "x$f: $n -> $m frames in $(( $(date +%s) - t0 ))s   ($OUT/s240_x$f.mp4)"
done
echo "== done. s240_orig = 240 as recorded (8x slow), x2 = 480-like (16x), x4 = 960-like (32x)"
