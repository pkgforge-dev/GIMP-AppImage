#!/bin/sh

set -eu

export ARCH="$(uname -m)"
export APPIMAGE_EXTRACT_AND_RUN=1
export VERSION="$(pacman -Q gimp | awk 'NR==1 {print $2; exit}')"
export STRACE_TIME=20
UPINFO="gh-releases-zsync|$(echo $GITHUB_REPOSITORY | tr '/' '|')|continuous|*$ARCH.AppImage.zsync"
LIB4BN="https://raw.githubusercontent.com/VHSgunzo/sharun/refs/heads/main/lib4bin"
URUNTIME="https://github.com/VHSgunzo/uruntime/releases/latest/download/uruntime-appimage-dwarfs-$ARCH"

# Prepare AppDir
mkdir -p ./AppDir/etc ./AppDir/share/icons
cd ./AppDir

# ADD LIBRARIES
wget "$LIB4BN" -O ./lib4bin
chmod +x ./lib4bin
xvfb-run -a -- ./lib4bin -p -v -k -s -e -y \
	--python-pkg PyGObject \
	/usr/bin/gimp* \
	/usr/lib/libgimp* \
	/usr/lib/gimp/*/modules/* \
	/usr/lib/gdk-pixbuf-*/*/*/* \
	/usr/lib/gtk-*/*/*/* \
	/usr/lib/gio/*/* \
	/usr/lib/babl-*/* \
	/usr/lib/gegl-*/* \
	/usr/lib/gvfs/* \
	/usr/lib/libcfitsio.so* \
	/usr/lib/libgthread-2.0.so* \
	/usr/lib/libheif/* \
	/usr/lib/libjbig2dec* \
	/usr/lib/libgpm* \
	/usr/lib/libpaper* \
	/usr/lib/libSDL* \
	/usr/lib/libXpm.so* \
	/usr/lib/libheif.so* \
	/usr/lib/libwmf* \
	/usr/lib/libudev.so* \
	/usr/lib/libaa.so* \
	/usr/lib/libmng.so* 

cp -vr /usr/share/gimp           ./share
cp -vr /usr/share/locale         ./share
cp -vr /usr/lib/locale           ./shared/lib
cp -vr /usr/share/pixmaps        ./share
cp -vr /usr/share/icons/hicolor  ./share/icons
cp -vr /etc/gimp                 ./etc
cp -vr /usr/share/vala           ./share
cp -vr /usr/share/gir-1.0        ./share
cp -vn /usr/lib/gegl-*/*.json    ./shared/lib/gegl-*
cp -rvn /usr/lib/gimp            ./shared/lib

cp /usr/share/applications/gimp.desktop            ./
cp /usr/share/icons/hicolor/256x256/apps/gimp.png  ./
cp /usr/share/icons/hicolor/256x256/apps/gimp.png  ./.DirIcon

# sharun the gimp plugins
echo "Sharunning the gimp plugins..."
bins_to_find="$(find ./lib/gimp -exec file {} \; | grep -i 'elf.*executable' | awk -F':' '{print $1}')"
for plugin in $bins_to_find; do
	mv -v "$plugin" ./shared/bin && ln -sfr ./sharun "$plugin"
	echo "Sharan $plugin"
done

# FIXME For some reason libgimpwidgets is hardcoded to looks  for /usr/share and doesn't check XDG_DATA_DIRS
# So we will fix it with binary patching because ld-preload-open did not work as libgimpwidgets 
# uses the openat function which ld-preload-open doesn't work with 😭
find ./lib -type f -name 'libgimpwidgets*' -exec sed -i 's|/usr|././|g' {} \;

# PREPARE SHARUN
echo 'SHARUN_WORKING_DIR=${SHARUN_DIR}
GIMP3_DATADIR=${SHARUN_DIR}/share/gimp/3.0
GIMP3_SYSCONFDIR=${SHARUN_DIR}/etc/gimp/3.0
GIMP3_LOCALEDIR=${SHARUN_DIR}/share/locale
GIMP3_PLUGINDIR=${SHARUN_DIR}/shared/lib/gimp/3.0' > ./.env

ln ./sharun ./AppRun
./sharun -g

# MAKE APPIMAGE WITH URUNTIME
cd ..
wget -q "$URUNTIME" -O ./uruntime
chmod +x ./uruntime

# Keep the mount point (speeds up launch time)
sed -i 's|URUNTIME_MOUNT=[0-9]|URUNTIME_MOUNT=0|' ./uruntime

#Add udpate info to runtime
echo "Adding update information \"$UPINFO\" to runtime..."
./uruntime --appimage-addupdinfo "$UPINFO"

echo "Generating AppImage..."
./uruntime --appimage-mkdwarfs -f \
	--set-owner 0 --set-group 0 \
	--no-history --no-create-timestamp \
	--compression zstd:level=22 -S23 -B32 \
	--header uruntime \
	-i ./AppDir -o ./GIMP-"$VERSION"-"$ARCH".AppImage

echo "Generating zsync file..."
zsyncmake *.AppImage -u *.AppImage
echo "All Done!"
