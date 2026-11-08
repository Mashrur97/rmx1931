#!/system/bin/sh
# smooth960 over adb (no Termux): static ffmpeg/ffprobe in /data/local/tmp
# Splits the section into chunks and interpolates them in parallel (minterpolate is single-threaded).
# usage: sh smooth960_adb.sh /sdcard/DCIM/Camera/VIDxxxx.mp4 [start_sec] [duration_sec] [chunks]
B=/data/local/tmp
FF=$B/ffmpeg; FP=$B/ffprobe
in="$1"; ss="${2:-0}"; dur="$3"; N="${4:-6}"
[ -f "$in" ] || { echo "usage: smooth960_adb.sh <video.mp4> [start] [duration] [chunks]"; exit 1; }
chmod 755 $FF $FP 2>/dev/null
out="${in%.*}_smooth960.mp4"
W=$B/s960_work; rm -rf $W; mkdir -p $W
t0=$(date +%s)

# 1) exact cut at constant 30 fps (near-lossless, fast)
tdur=""; [ -n "$dur" ] && tdur="-t $dur"
echo "Cutting section..."
$FF -hide_banner -loglevel error -ss "$ss" $tdur -i "$in" -an \
  -vf "setpts=N/(30*TB)" -r 30 -c:v libx264 -preset ultrafast -crf 8 -y $W/cut.mp4 || exit 1
F=$($FP -v error -select_streams v:0 -count_frames -show_entries stream=nb_read_frames -of csv=p=0 $W/cut.mp4)
[ "$F" -gt 1 ] 2>/dev/null || { echo "could not read frames"; exit 1; }
[ "$N" -gt $((F/8)) ] && N=$((F/8)); [ "$N" -lt 1 ] && N=1
TOTAL=$((2*(F-1)-1))
echo "$F frames -> $TOTAL, $N parallel chunks"

# 2) chunk i owns frames [a, b); it is fed a few frames past b so interpolation crosses
#    the seam, and keeps exactly 2*(b-a) output frames (the last chunk keeps all).
step=$(( (F-1+N-1)/N ))
i=0; a=0; : > $W/list.txt
while [ $a -lt $((F-1)) ]; do
  b=$((a+step)); [ $b -gt $((F-1)) ] && b=$((F-1))
  # minterpolate needs look-ahead: feed 2 extra frames, cut output exactly at the seam
  e=$((b+3)); [ $e -gt $F ] && e=$F
  lim=""; [ $b -lt $((F-1)) ] && lim="-frames:v $((2*(b-a)))"
  $FF -hide_banner -loglevel error -nostats -progress $W/p$i.txt -i $W/cut.mp4 -an \
    -vf "trim=start_frame=$a:end_frame=$e,setpts=N/(30*TB),minterpolate=fps=60:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1,setpts=N/(30*TB)" \
    $lim -r 30 -c:v libx264 -crf 18 -preset veryfast -pix_fmt yuv420p -threads 2 \
    -y $W/c$i.mp4 > $W/e$i.txt 2>&1 &
  echo "file '$W/c$i.mp4'" >> $W/list.txt
  i=$((i+1)); a=$b
done
CH=$i

# 3) progress until all chunks finish
while :; do
  done=0; run=0; k=0
  while [ $k -lt $CH ]; do
    f=$(grep '^frame=' $W/p$k.txt 2>/dev/null | tail -1 | cut -d= -f2)
    done=$((done+${f:-0}))
    grep -q '^progress=end' $W/p$k.txt 2>/dev/null || run=$((run+1))
    k=$((k+1))
  done
  el=$(( $(date +%s) - t0 ))
  printf '\r  %d / %d frames  (%ds)   ' $done $TOTAL $el
  [ $run -eq 0 ] && break
  sleep 2
done
echo
k=0; while [ $k -lt $CH ]; do [ -s $W/c$k.mp4 ] || { echo "chunk $k failed:"; cat $W/e$k.txt; exit 1; }; k=$((k+1)); done

# 4) stitch, tag as slow-mo, index
$FF -hide_banner -loglevel error -f concat -safe 0 -i $W/list.txt -c copy \
  -movflags +faststart+use_metadata_tags -metadata com.android.capture.fps=960 -y "$out" || exit 1
rm -rf $W
am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file://$out" >/dev/null 2>&1
echo "Done in $(( $(date +%s) - t0 ))s: $out"
