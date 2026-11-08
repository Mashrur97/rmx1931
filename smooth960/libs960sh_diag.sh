#!/system/bin/sh
# DIAGNOSTIC build of libs960sh.so: run ffmpeg several ways inside the camera's sandbox
# and report which survive (exit 159 = killed by seccomp/SIGSYS). Always reports failure.
FF="$(dirname "$0")/libffmpeg_s960.so"
t() {
  name="$1"; shift
  "$@" > /dev/null 2>&1
  echo "TEST $name -> exit $?"
}
echo "PROGRESS 0 1"
echo "TEST info: $(id) / $(uname -r)"
t "1 version"                        $FF -hide_banner -version
t "2 version rseq-off"               env GLIBC_TUNABLES=glibc.pthread.rseq=0 $FF -hide_banner -version
t "3 encode 1-thread"                $FF -hide_banner -nostdin -f lavfi -i testsrc=s=320x240:d=1 -threads 1 -filter_threads 1 -c:v libx264 -f null -
t "4 encode 1-thread rseq-off"       env GLIBC_TUNABLES=glibc.pthread.rseq=0 $FF -hide_banner -nostdin -f lavfi -i testsrc=s=320x240:d=1 -threads 1 -filter_threads 1 -c:v libx264 -f null -
t "5 encode threads rseq-off"        env GLIBC_TUNABLES=glibc.pthread.rseq=0 $FF -hide_banner -nostdin -f lavfi -i testsrc=s=320x240:d=1 -c:v libx264 -f null -
t "6 read source rseq-off"           env GLIBC_TUNABLES=glibc.pthread.rseq=0 $FF -hide_banner -nostdin -threads 1 -i "$1" -frames:v 1 -f null -
exit 1
