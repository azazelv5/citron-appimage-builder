#!/bin/bash
# Title: Citron AppImage Build Script (Linux & macOS)
# Description: Builds and runs the Arch Linux Docker container to create a Citron AppImage.

set -e  # Exit on any error

# Check if Docker is installed
echo "Checking for Docker installation..."
if ! command -v docker &> /dev/null; then
    echo "=============================================================="
    echo "  Docker is not installed on your system."
    echo "  Please install Docker from: https://docs.docker.com/get-docker/"
    echo "=============================================================="
    exit 1
fi

# Check if Docker is running
echo "Checking if Docker is running..."
if ! docker info &> /dev/null; then
    echo "=============================================================="
    echo "  Docker is not running. Please start Docker and try again."
    echo "=============================================================="
    exit 1
fi

# Ask user for version
echo "========================================================"
echo "  Choose the version to build:"
echo "  1. [Default] Latest master branch (nightly build)"
echo "  2. Citron Canary Refresh Version 0.5"
echo "  3. Citron Canary Refresh Version 0.4"
echo "  4. Specific version (Tag, Branch name or Commit Hash)"
echo "========================================================"
read -p "Enter choice ([1]/2/3/4): " VERSION_CHOICE
case "$VERSION_CHOICE" in
    2) CITRON_VERSION="v0.5-canary-refresh" ;;
    3) CITRON_VERSION="v0.4-canary-refresh" ;;
    4) read -p "Enter the version (Tag, Branch or Commit Hash): " CITRON_VERSION ;;
    *) CITRON_VERSION="master" ;;
esac

# Ask user for build mode
echo "========================================================"
echo "  Choose the build mode:"
echo "  1. [Default] SteamDeck optimizations"
echo "  2. Release mode"
echo "  3. Compatibility mode (for older architectures)"
echo "  4. Debug mode"
echo "========================================================"
read -p "Enter choice ([1]/2/3/4): " BUILD_MODE_CHOICE
case "$BUILD_MODE_CHOICE" in
    2) CITRON_BUILD_MODE="release" ;;
    3) CITRON_BUILD_MODE="compatibility" ;;
    4) CITRON_BUILD_MODE="debug" ;;
    *) CITRON_BUILD_MODE="steamdeck" ;;
esac

# Ask user if they want to cache the Git repository
echo "========================================================"
echo "  Do you want to cache the Git repository for "
echo "  subsequent builds? (This may speed up builds but "
echo "  will consume around 1 GB of disk space.)"
echo "  1. Yes"
echo "  2. [Default] No"
echo "========================================================"
read -p "Enter choice (1/[2]): " CACHE_REPO
USE_CACHE=false
[ "$CACHE_REPO" = "1" ] && USE_CACHE=true

# Ask user if they want to output Linux binaries
echo "========================================================"
echo "  Do you want to output Linux binaries?"
echo "  1. Yes"
echo "  2. [Default] No"
echo "========================================================"
read -p "Enter choice (1/[2]): " OUTPUT_BINARIES
OUTPUT_LINUX_BINARIES=false
[ "$OUTPUT_BINARIES" = "1" ] && OUTPUT_LINUX_BINARIES=true

# Detect system architecture
ARCH=$(uname -m)

if [ "$ARCH" = "arm64" ]; then
    echo "ARM device detected"
    # Detect if host is macOS
    if [ "$(uname)" = "Darwin" ]; then
        echo "Mac Detected"
        
        # Check if Rosetta 2 is installed using pkgutil
        if ! pkgutil --pkgs | grep -q "com.apple.pkg.RosettaUpdateAuto"; then
            echo "=============================================================="
            echo "  Rosetta 2 is required to run the ARM64 Docker container on"
            echo "  macOS. Please install Rosetta 2 and try again."
            echo "  Command to install Rosetta 2: softwareupdate --install-rosetta --agree-to-license"
            echo "=============================================================="
            exit 1
        fi
    fi

    echo "Building Citron AppImage for ARM64..."

    # Build the new image for ARM64
    docker build --platform=linux/amd64 -t citron-builder .

    # Run the container with the selected options
    docker run --platform=linux/amd64 --rm \
        -e CITRON_VERSION=$CITRON_VERSION \
        -e CITRON_BUILD_MODE=$CITRON_BUILD_MODE \
        -e OUTPUT_LINUX_BINARIES=$OUTPUT_LINUX_BINARIES \
        -e USE_CACHE=$USE_CACHE \
        -v "$(pwd)":/output \
        citron-builder

else
    # Build the new image
    docker build -t citron-builder .

    # Run the container with the selected options
    docker run --rm \
        -e CITRON_VERSION=$CITRON_VERSION \
        -e CITRON_BUILD_MODE=$CITRON_BUILD_MODE \
        -e OUTPUT_LINUX_BINARIES=$OUTPUT_LINUX_BINARIES \
        -e USE_CACHE=$USE_CACHE \
        -v "$(pwd)":/output \
        citron-builder
fi

# Ask user if they want to remove the Docker image
echo "========================================================"
echo "  Do you want to remove the citron-builder image "
echo "  to save disk space? (Y/n)"
echo "========================================================"
read -p "Enter choice: " DELETE_IMAGE
if [[ -z "$DELETE_IMAGE" || "$DELETE_IMAGE" =~ ^[Yy]$ ]]; then
    echo "Removing citron-builder image..."
    docker rmi -f citron-builder
fi

# Ask user if they want to delete the cached Git repository
if [ -f citron.tar.zst ]; then
    echo "========================================================"
    echo "  Do you want to delete the cached repository "
    echo "  file citron.tar.zst to free up space? (y/[N])"
    echo "========================================================"
    read -p "Enter choice: " DELETE_CACHE
    if [[ "$DELETE_CACHE" =~ ^[Yy]$ ]]; then
        echo "Deleting cached repository..."
        rm -f citron.tar.zst
    fi
fi
