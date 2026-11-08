#!/system/bin/sh
# Phase 2 benchmark: RIFE (rife-ncnn-vulkan, Android arm64) on the phone, as root.
# Needs: /data/local/tmp/rife/{rife-ncnn-vulkan,rife-v4/} and ffmpeg at /data/adb/oppocam/ffmpeg.
# usage: sh rifebench.sh [clip] [start_sec] [dur_sec]
# Default clip/section = the fan clip slice used for the minterpolate comparison.
B=/data/local/tmp/rife
FF=/data/adb/oppocam/ffmpeg
clip="${1:-/sdcard/DCIM/Camera/VID20261107210737.mp4}"; ss="${2:-10}"; dur="${3:-4}"
W=/data/local/tmp/rb
R="$B/rife-ncnn-vulkan"
[ -x "$R" ] || chmod 755 "$R"
[ -f "$clip" ] || { echo "clip not found: $clip"; exit 1; }
rm -rf "$W"; mkdir -p "$W/in"
F=$((dur*30))
echo "== extracting $F frames from $clip at ${ss}s"
$FF -hide_banner -loglevel error -nostdin -ss "$ss" -t "$dur" -i "$clip" -an \
  -vf "setpts=N/(30*TB)" -frames:v $F "$W/in/%08d.png" || exit 1
N=$(ls "$W/in" | wc -l); T=$((N*2))
echo "   $N frames -> target $T"
echo "== GPU info"
"$R" -v -i "$W/in" -o "$W/probe" -m "$B/rife-v4" -n 4 2>&1 | grep -iE "gpu|vulkan|adreno|\[0" | head -5
rm -rf "$W/probe"

run() {   # run <name> <rife options...>
  name="$1"; shift
  rm -rf "$W/o_$name"; mkdir -p "$W/o_$name"
  t0=$(date +%s)
  "$R" -i "$W/in" -o "$W/o_$name" -m "$B/rife-v4" -n $T "$@" > "$W/log_$name.txt" 2>&1
  rc=$?; t1=$(date +%s); s=$((t1-t0)); [ $s -lt 1 ] && s=1
  n=$(ls "$W/o_$name" 2>/dev/null | wc -l)
  echo "$name: exit $rc, $n frames in ${s}s  (~$((n/s)) frames/s)  [$*]"
  [ $rc -ne 0 ] && tail -3 "$W/log_$name.txt"
}
echo "== runs"
run gpu      -g 0
run gpu_uhd  -g 0 -u
run gpu_j    -g 0 -j 2:4:4
run both     -g 0,-1 -j 2:2,4:4
run cpu      -g -1 -j 2:8:4
echo "== encoding the GPU result for a visual check"
$FF -hide_banner -loglevel error -nostdin -framerate 30 -i "$W/o_gpu/%08d.png" \
  -c:v libx264 -crf 16 -preset veryfast -pix_fmt yuv420p -y /sdcard/Download/rife_gpu.mp4 \
  && echo "   /sdcard/Download/rife_gpu.mp4"
[ -d "$W/o_gpu_uhd" ] && $FF -hide_banner -loglevel error -nostdin -framerate 30 -i "$W/o_gpu_uhd/%08d.png" \
  -c:v libx264 -crf 16 -preset veryfast -pix_fmt yuv420p -y /sdcard/Download/rife_gpu_uhd.mp4 \
  && echo "   /sdcard/Download/rife_gpu_uhd.mp4"
echo "== done (temp files in $W)"
