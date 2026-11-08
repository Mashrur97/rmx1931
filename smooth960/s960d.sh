#!/system/bin/sh
# s960d: root helper for OppoCamera's real 960 mode. Runs outside the app sandbox (static ffmpeg
# can't start inside it). Watches the camera's job file, interpolates, writes results into files the
# camera created. Layout matches stock compileSlowMotion: head 32/f s at 32/f x, middle 8/f s slowed
# f x with real motion-interpolated frames (parallel chunks), tail at 32/f x.
FF=${S960_FF:-/data/adb/oppocam/ffmpeg}
Q=${S960_Q:-/data/data/com.oppo.camera/cache/s960}
W=${S960_W:-/data/adb/oppocam/s960work}
# defaults; each job can override them (line 4 of the job file, from the camera's Smooth 960 settings)
N=6
CRF=18
MI="mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1"
PIDF=$W.pid
echo $$ > "$PIDF"
log() { echo "$(date '+%H:%M:%S') $*"; }
# notifications through Android's own shell command (no app needed); harmless if unavailable
note() {
  [ -z "$S960_SHELLNOTE" ] && return   # v0.10: the camera posts the real notification
  r=$(/system/bin/cmd notification post -t "Real 960 slow-mo" s960 "$1" 2>&1 < /dev/null)
  case "$r" in *posting*) ;; *) log "notification failed: $(echo "$r" | head -2 | tr '\n' ' ')" ;; esac
}
# is the camera still the resumed (front) activity? the camera silently drops our result once it's
# backgrounded, so the helper has to notice by itself. S960_CAMFRONT overrides for testing.
cam_front() {
  [ -n "$S960_CAMFRONT" ] && { [ -f "$S960_CAMFRONT" ]; return; }
  # the camera's own settings / Smooth 960 progress page count as "left": the viewfinder is closed
  l=$(dumpsys activity activities 2>/dev/null | grep -m1 -E 'ResumedActivity')
  case "$l" in *SettingActivity*) return 1 ;; *com.oppo.camera*) return 0 ;; *) return 1 ;; esac
}
# where the result goes when the camera left mid-way: DCIM/Camera/Slow<date>.mp4 next to the source
standalone_path() { d=$(dirname "$1"); b=$(basename "$1"); n=$(echo "$b" | sed 's/^VID/Slow/'); [ "$n" = "$b" ] && n="Slow_$b"; echo "$d/$n"; }

real() { case "$1" in /storage/emulated/0/*) echo "/data/media/0/${1#/storage/emulated/0/}" ;; /sdcard/*) echo "/data/media/0/${1#/sdcard/}" ;; *) echo "$1" ;; esac; }

# job options: "cores=6 priority=normal quality=balanced denoise=off bitrate=standard deflicker=0"
opts() {
  N=6; CRF=18; NICE=""; PRE=""; MI="mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1"
  for kv in $1; do
    v=${kv#*=}
    case "$kv" in
      cores=[1-8]) N=$v ;;
      priority=low) NICE="nice -n 10" ;;
      quality=fast) MI="mi_mode=mci:mc_mode=obmc:me_mode=bilat:vsbmc=0" ;;
      quality=best) MI="mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1:mb_size=8" ;;
      denoise=light) PRE="${PRE}hqdn3d=3:2:5:4," ;;
      denoise=medium) PRE="${PRE}hqdn3d=6:4.5:9:7," ;;
      bitrate=small) CRF=23 ;;
      bitrate=high) CRF=14 ;;
      deflicker=1) PRE="${PRE}deflicker=size=5:mode=pm," ;;
    esac
  done
  ENC="-c:v libx264 -crf $CRF -preset veryfast -pix_fmt yuv420p -threads 2 -an"
}

job() {
  src=$(real "$1"); out="$2"; f="$3"; pids=""; alone=""
  opts "$4"
  log "options: cores=$N crf=$CRF ${NICE:+low-priority }pre=${PRE:-none} mi=$MI"
  [ "$f" -ge 1 ] 2>/dev/null || f=2
  H=$((32/f)); M=$((8/f)); S=$((32/f)); [ $H -lt 1 ] && H=1; [ $M -lt 1 ] && M=1
  rm -rf "$W"; mkdir -p "$W"
  [ -f "$src" ] || { log "no source $src"; return 1; }
  F=$((M*30))
  $FF -hide_banner -loglevel error -nostdin -ss $H -t $M -i "$src" -an -vf "${PRE}setpts=N/(30*TB)" -r 30 \
    -frames:v $F -c:v libx264 -preset ultrafast -crf 8 -y "$W/cut.mp4" > "$W/ec.txt" 2>&1 || { cat "$W/ec.txt"; return 1; }
  F=$($FF -v error -nostdin -i "$W/cut.mp4" -map 0:v -c copy -f framecrc - 2>/dev/null | grep -vc '^#')
  [ "${F:-0}" -gt 8 ] || { log "cut has ${F:-0} frames"; return 1; }
  TOTAL=$((f*(F-1)))
  step=$(( (F-1+N-1)/N )); i=0; a=0; : > "$W/mid.txt"
  while [ $a -lt $((F-1)) ]; do
    b=$((a+step)); [ $b -gt $((F-1)) ] && b=$((F-1))
    e=$((b+3)); [ $e -gt $F ] && e=$F
    lim=""; [ $b -lt $((F-1)) ] && lim="-frames:v $((f*(b-a)))"
    $NICE $FF -hide_banner -loglevel error -nostdin -nostats -progress "$W/p$i.txt" -i "$W/cut.mp4" \
      -vf "trim=start_frame=$a:end_frame=$e,setpts=N/(30*TB),minterpolate=fps=$((30*f)):$MI,setpts=N/(30*TB)" \
      $lim -r 30 $ENC -y "$W/c$i.mp4" > "$W/e$i.txt" 2>&1 &
    pids="$pids $!"
    echo "file '$W/c$i.mp4'" >> "$W/mid.txt"
    i=$((i+1)); a=$b
  done
  CH=$i
  # head + tail are cheap; run them niced so the interpolation chunks get the big cores first
  nice -n 15 $FF -hide_banner -loglevel error -nostdin -t $H -i "$src" -vf "${PRE}setpts=PTS/$S" -r 30 $ENC -y "$W/h.mp4" > "$W/eh.txt" 2>&1 &
  pids="$pids $!"
  nice -n 15 $FF -hide_banner -loglevel error -nostdin -ss $((H+M)) -i "$src" -vf "${PRE}setpts=PTS/$S" -r 30 $ENC -y "$W/t.mp4" > "$W/et.txt" 2>&1 &
  pids="$pids $!"
  tick=0
  if [ -f "$Q/cancel" ] || ! cam_front; then alone=1; rm -f "$Q/cancel"; log "camera left - finishing in the background"; note "Smoothing in the background..."; fi
  while :; do
    if [ -z "$alone" ]; then
      tick=$((tick+1))
      if [ -f "$Q/cancel" ] || { [ $((tick%2)) -eq 0 ] && ! cam_front; }; then
        alone=1; rm -f "$Q/cancel"; log "camera left - finishing in the background"; note "Smoothing in the background..."
      fi
    fi
    [ -n "$alone" ] && [ $TOTAL -gt 0 ] && note "Smoothing in the background... $((100*d/TOTAL))%"
    d=0; run=0; k=0
    while [ $k -lt $CH ]; do
      x=$(grep '^frame=' "$W/p$k.txt" 2>/dev/null | tail -1 | cut -d= -f2); d=$((d+${x:-0}))
      grep -q '^progress=end' "$W/p$k.txt" 2>/dev/null || run=$((run+1)); k=$((k+1))
    done
    echo "$d $TOTAL" > "$Q/progress"
    [ $run -eq 0 ] && break
    sleep 1
  done
  wait
  k=0; while [ $k -lt $CH ]; do [ -s "$W/c$k.mp4" ] || { log "chunk $k failed"; cat "$W/e$k.txt"; return 1; }; k=$((k+1)); done
  [ -s "$W/h.mp4" ] || { log "head failed"; cat "$W/eh.txt"; return 1; }
  echo "file '$W/h.mp4'" > "$W/all.txt"; cat "$W/mid.txt" >> "$W/all.txt"
  [ -s "$W/t.mp4" ] && echo "file '$W/t.mp4'" >> "$W/all.txt"
  $FF -hide_banner -loglevel error -nostdin -f concat -safe 0 -i "$W/all.txt" -c copy -movflags +faststart -y "$W/out.mp4" || return 1
  { [ -f "$Q/cancel" ] || ! cam_front; } && { alone=1; rm -f "$Q/cancel"; }
  if [ -z "$alone" ]; then
    cat "$W/out.mp4" > "$out" || return 1     # write INTO the camera's file: keeps its owner/label
    log "done: $F frames -> $TOTAL, $(stat -c %s "$out") bytes"
  else
    dst=$(standalone_path "$src")
    cat "$W/out.mp4" > "$dst" || return 1
    chown "$(stat -c %u:%g "$src")" "$dst"; chmod "$(stat -c %a "$src")" "$dst"
    chcon "$(ls -Z "$src" | awk '{print $1}')" "$dst" 2>/dev/null
    vis="/storage/emulated/0/${dst#/data/media/0/}"
    touch -r "$src" "$dst"
    am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file://$vis" >/dev/null 2>&1
    SAVED="$vis"; note "Saved $(basename "$dst")"
    log "done in background: $dst ($(stat -c %s "$dst") bytes)"
    rm -rf "$W"; return 3
  fi
  rm -rf "$W"
  return 0
}

log "s960d started (pid $$), watching $Q (PATH=$PATH, $(id -Z 2>/dev/null))"
while :; do
  if [ -f "$Q/job" ]; then
    j1=$(sed -n 1p "$Q/job"); j2=$(sed -n 2p "$Q/job"); j3=$(sed -n 3p "$Q/job"); j4=$(sed -n 4p "$Q/job")
    rm -f "$Q/job"
    log "job: $j1 -> $j2 (x$j3) [$j4]"
    t0=$(date +%s)
    job "$j1" "$j2" "$j3" "$j4"; r=$?
    case $r in
      0) echo "OK $(( $(date +%s) - t0 ))" > "$Q/status" ;;
      3) echo "FAIL camera left; saved in background $SAVED" > "$Q/status" ;;
      *) echo "FAIL see /data/adb/oppocam/s960d.log" > "$Q/status"; note "960 processing failed (see s960d.log)" ;;
    esac
  fi
  sleep 1
done
