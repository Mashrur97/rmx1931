#!/data/data/com.termux/files/usr/bin/bash
# smooth960: turn a 480fps slow-mo clip into a smooth "960" by generating real in-between frames.
# usage: smooth960 /sdcard/DCIM/Camera/VIDxxxx.mp4   -> writes VIDxxxx_smooth960.mp4 next to it
set -e
in="$1"
[ -f "$in" ] || { echo "usage: smooth960 <video.mp4>"; exit 1; }
out="${in%.*}_smooth960.mp4"
frames=$(ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 "$in")
echo "Interpolating $frames frames -> $((frames*2)). This takes a while; keep Termux open."
ffmpeg -hide_banner -loglevel error -stats -i "$in" \
  -vf "minterpolate=fps=60:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1,setpts=2*PTS" \
  -r 30 -an -c:v libx264 -crf 18 -preset veryfast -pix_fmt yuv420p \
  -movflags +faststart+use_metadata_tags -metadata com.android.capture.fps=960 \
  "$out"
# let the gallery see it right away
am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file://$out" >/dev/null 2>&1 || true
echo "Done: $out"
