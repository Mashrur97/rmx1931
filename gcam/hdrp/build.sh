#!/bin/sh
# Java glue -> classes5.dex -> rezip into out/OppoCamera.apk -> sign -> tagged copies out/OppoCamera_<tag>.apk + hdrpe_install_<tag>.sh
set -e
T=/home/claude/tools; H=/home/claude/hdrp; O=/home/claude/out
cd $H; rm -rf cls dex; mkdir cls dex
javac -nowarn --release 8 -cp $T/android.jar:stubcls -d cls $(find src -name "*.java") 2>&1 | grep -E "error|\.java:" && exit 1
java -cp $T/r8.jar com.android.tools.r8.D8 --release --min-api 29 --lib $T/android.jar --classpath stubcls --output dex $(find cls -name "*.class") 2>&1 | grep -v JAVA_TOOL || true
cd $O; python3 ../rmx1931/tools/rezip.py OppoCamera.apk u.apk classes5.dex=$H/dex/classes.dex >/dev/null
java -jar $T/uber-apk-signer-1.3.0.jar -a u.apk --overwrite 2>&1 | grep -q "signature verified" || { echo SIGN FAILED; exit 1; }
mv u.apk OppoCamera.apk
M=$(md5sum OppoCamera.apk | cut -c1-12); TAG=$(echo $M | cut -c1-4)
rm -f OppoCamera_????.apk hdrpe_install_????.sh
cp OppoCamera.apk OppoCamera_$TAG.apk
sed "s/@TAG@/$TAG/g; s/@MD5@/$M/g" hdrpe_install.tmpl > hdrpe_install_$TAG.sh
echo "$M $TAG"
