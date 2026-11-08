# rife-android

GitHub Actions build of [nihui/rife-ncnn-vulkan](https://github.com/nihui/rife-ncnn-vulkan) (MIT) for Android arm64:
bionic + Vulkan, static libc++, so it runs from a root shell and only needs the system `libvulkan.so`.

Workflow: `.github/workflows/rife-android.yml` (runs on changes here or by hand). Artifact
`rife-ncnn-vulkan-android-arm64`: the binary, the `rife-v4` model, `BUILD_INFO.txt`.

Phase 2 (benchmark on the phone): push binary + model to `/data/local/tmp/rife`, run on frames extracted from a 480 fps
cut, compare `-g 0` (GPU), `-g -1` (CPU), both, and models, against ffmpeg `minterpolate`.
