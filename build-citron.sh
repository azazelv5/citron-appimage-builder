#!/bin/bash
set -e  # Exit on error

# ============================================
# Citron Build Script for Docker with WSL
# ============================================
# This script:
# - Clones or updates the Citron repository
# - Checks out a specific version (default: master)
# - Builds Citron using CMake and Ninja
# - Creates an AppImage package
# - Saves the output to /output
#
# Usage:
# - Default version (latest master): `docker run --rm -v ${PWD}:/output citron-builder`
# - Specific version: `docker run --rm -e CITRON_VERSION=v0.4-canary-refresh -v ${PWD}:/output citron-builder`
# ============================================

# Set the Citron version (default to 'master' if not provided)
CITRON_VERSION=${CITRON_VERSION:-master}

echo "🛠️ Building Citron (Version: ${CITRON_VERSION})"

# Clone or update Citron repo
if [ -d "/root/Citron" ]; then
    echo "🔄 Updating Citron repository..."
    cd /root/Citron
    git fetch --all
    git reset --hard origin/master  # Ensure a clean state
    git checkout ${CITRON_VERSION} || git checkout tags/${CITRON_VERSION}
    git pull
else
    echo "📥 Cloning Citron repository..."
    git clone --recursive https://git.citron-emu.org/Citron/Citron.git /root/Citron
    cd /root/Citron
    git checkout ${CITRON_VERSION} || git checkout tags/${CITRON_VERSION}
fi

# Build Citron
mkdir -p /root/Citron/build
cd /root/Citron/build
cmake .. -GNinja -DCITRON_USE_BUNDLED_VCPKG=ON -DCITRON_TESTS=OFF -DCITRON_USE_LLVM_DEMANGLE=OFF \
    -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_CXX_FLAGS="-march=native -mtune=native -O3 -flto" \
    -DCMAKE_C_FLAGS="-march=native -mtune=native -O3 -flto" -DUSE_DISCORD_PRESENCE=ON -DBUNDLE_SPEEX=ON
ninja
sudo ninja install

# Build the AppImage
cd /root/Citron
sudo /root/Citron/appimage-builder.sh citron /root/Citron/build

# Prepare AppImage deployment
cd /root/Citron/build/deploy-linux
sudo cp /usr/lib/libSDL3.so* /root/Citron/build/deploy-linux/AppDir/usr/lib/
sudo wget https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage
# Workaround for lack of FUSE support in WSL
./appimagetool-x86_64.AppImage --appimage-extract
chmod +x ./squashfs-root/AppRun
./squashfs-root/AppRun AppDir

# Set output file name
if [[ "$CITRON_VERSION" == "master" ]]; then
    OUTPUT_NAME="citron-nightly.AppImage"
else
    OUTPUT_NAME="citron-${CITRON_VERSION}.AppImage"
fi

# Move the most recently created AppImage to a shared output folder
mkdir -p /output
APPIMAGE_PATH=$(ls -t /root/Citron/build/deploy-linux/*.AppImage 2>/dev/null | head -n 1)

if [[ -n "$APPIMAGE_PATH" ]]; then
    mv -f "$APPIMAGE_PATH" "/output/${OUTPUT_NAME}"
    echo "✅ Build complete! The AppImage is located in /output/${OUTPUT_NAME}"
else
    echo "❌ Error: No .AppImage file found in /root/Citron/build/deploy-linux/"
    exit 1
fi
