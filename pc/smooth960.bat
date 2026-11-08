@echo off
setlocal enabledelayedexpansion
rem smooth960.bat - turn a 480fps slow-mo clip on the phone into a smooth "960".
rem Put this next to adb.exe, smooth960_adb.sh and the downloaded ffmpeg-*-arm64-static.tar.xz
rem usage:  smooth960            (shows your latest videos and asks)
rem         smooth960 VID20261107210737.mp4 10 4   (file in DCIM/Camera, start sec, duration sec)
cd /d "%~dp0"
set SEVENZ=C:\Program Files\7-Zip\7z.exe

rem --- 1. get ffmpeg + ffprobe (arm64) ready in .\ffmpeg_arm64 ---
if not exist "ffmpeg_arm64\ffmpeg" (
  set ARCHIVE=
  for %%f in (ffmpeg-*arm64*static*.tar.xz) do set ARCHIVE=%%f
  if "!ARCHIVE!"=="" (
    echo Could not find ffmpeg-...-arm64-static.tar.xz in this folder.
    echo Download it from johnvansickle.com/ffmpeg ^(arm64 release^) and put it here.
    exit /b 1
  )
  if not exist "%SEVENZ%" ( echo 7-Zip not found at %SEVENZ% & exit /b 1 )
  echo Extracting !ARCHIVE! ...
  rmdir /s /q ffmpeg_tmp 2>nul
  "%SEVENZ%" x -y "!ARCHIVE!" -offmpeg_tmp >nul || exit /b 1
  for %%t in (ffmpeg_tmp\*.tar) do "%SEVENZ%" x -y "%%t" -offmpeg_tmp >nul
  mkdir ffmpeg_arm64 2>nul
  for /d %%d in (ffmpeg_tmp\ffmpeg-*) do (
    copy /y "%%d\ffmpeg" ffmpeg_arm64\ >nul
    copy /y "%%d\ffprobe" ffmpeg_arm64\ >nul
  )
  rmdir /s /q ffmpeg_tmp
  if not exist "ffmpeg_arm64\ffmpeg" ( echo Extraction failed. & exit /b 1 )
  echo ffmpeg ready.
)
if not exist "smooth960_adb.sh" ( echo smooth960_adb.sh missing from this folder. & exit /b 1 )

rem --- 2. push to the phone (only if missing there) ---
adb get-state >nul 2>&1 || ( echo Phone not connected over adb. & exit /b 1 )
adb shell "[ -x /data/local/tmp/ffmpeg ] && [ -x /data/local/tmp/ffprobe ]" >nul 2>&1
if errorlevel 1 (
  echo Pushing ffmpeg to the phone ...
  adb push ffmpeg_arm64\ffmpeg /data/local/tmp/ >nul || exit /b 1
  adb push ffmpeg_arm64\ffprobe /data/local/tmp/ >nul || exit /b 1
  adb shell chmod 755 /data/local/tmp/ffmpeg /data/local/tmp/ffprobe
)
adb push smooth960_adb.sh /data/local/tmp/ >nul

rem --- 3. pick the video ---
set VID=%~1
if "%VID%"=="" (
  echo.
  echo Latest videos in DCIM/Camera:
  adb shell "ls -t /sdcard/DCIM/Camera/ | grep -i '\.mp4$' | grep -v smooth960 | head -8"
  echo.
  set /p VID=Type the file name: 
  set /p SS=Start at second ^(Enter = from the beginning^): 
  set /p DUR=How many seconds ^(Enter = all^): 
) else (
  set SS=%~2
  set DUR=%~3
)

rem --- 4. run it on the phone ---
echo.
adb shell sh /data/local/tmp/smooth960_adb.sh "/sdcard/DCIM/Camera/!VID!" !SS! !DUR!
echo.
pause
