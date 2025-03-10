#!/bin/bash

# Title: Citron AppImage Build Linux Script
# Description: Builds and runs the Arch Linux Podman container to create a Citron AppImage.

set -e

# Check if Podman is installed
echo "Checking for Podman installation..."
if ! command -v podman &>/dev/null; then
    echo "Podman is not installed. Please install it first."
    exit 1
fi

# Define image name
IMAGE_NAME="localhost/citron-builder"

# Ask user for version
echo "========================================"
echo "  Choose the version to build:"
echo "  1. [Default] Latest master branch (nightly build)"
echo "  2. Citron Canary Refresh Version 0.5"
echo "  3. Citron Canary Refresh Version 0.4"
echo "  4. Specific version (Tag, Branch name or Commit Hash)"
echo "========================================"
read -rp "Enter choice ([1]/2/3/4): " VERSION_CHOICE
case "$VERSION_CHOICE" in
    2) CITRON_VERSION="v0.5-canary-refresh" ;;
    3) CITRON_VERSION="v0.4-canary-refresh" ;;
    4) read -rp "Enter the version (Tag, Branch or Commit Hash): " CITRON_VERSION ;;
    *) CITRON_VERSION="master" ;;
esac

# Ask user for build mode
echo "========================================"
echo "  Choose the build mode:"
echo "  1. [Default] SteamDeck optimizations"
echo "  2. Release mode"
echo "  3. Compatibility mode (for older architectures)"
echo "  4. Debug mode"
echo "========================================"
read -rp "Enter choice ([1]/2/3/4): " BUILD_MODE_CHOICE
case "$BUILD_MODE_CHOICE" in
    2) CITRON_BUILD_MODE="release" ;;
    3) CITRON_BUILD_MODE="compatibility" ;;
    4) CITRON_BUILD_MODE="debug" ;;
    *) CITRON_BUILD_MODE="steamdeck" ;;
esac

# Ask user if they want to cache the Git repository
echo "========================================"
echo "  Do you want to cache the Git repository?"
echo "  1. Yes"
echo "  2. [Default] No"
echo "========================================"
read -rp "Enter choice (1/[2]): " CACHE_REPO
USE_CACHE=false
if [[ "$CACHE_REPO" == "1" ]]; then USE_CACHE=true; fi

# Ask user if they want to output Linux binaries
echo "========================================"
echo "  Do you want to output Linux binaries?"
echo "  1. Yes"
echo "  2. [Default] No"
echo "========================================"
read -rp "Enter choice (1/[2]): " OUTPUT_BINARIES
OUTPUT_LINUX_BINARIES=false
if [[ "$OUTPUT_BINARIES" == "1" ]]; then OUTPUT_LINUX_BINARIES=true; fi

# Build the new image
echo "Building the Podman image..."
podman build -t "$IMAGE_NAME" .

# Run the container with selected options
echo "Running the build container..."
podman run --rm \
    -e CITRON_VERSION="$CITRON_VERSION" \
    -e CITRON_BUILD_MODE="$CITRON_BUILD_MODE" \
    -e OUTPUT_LINUX_BINARIES="$OUTPUT_LINUX_BINARIES" \
    -e USE_CACHE="$USE_CACHE" \
    -v "$(pwd)":/output \
    "$IMAGE_NAME"

# Ask the user if they want to delete the Podman image
echo "========================================"
echo "  Do you want to remove the $IMAGE_NAME image to save disk space? (Y/n)"
echo "========================================"
read -rp "Enter choice: " DELETE_IMAGE
if [[ -z "$DELETE_IMAGE" || "$DELETE_IMAGE" =~ ^[Yy]$ ]]; then
    echo "Removing $IMAGE_NAME image..."
    podman rmi -f "$IMAGE_NAME"
fi

# Ask the user if they want to delete the cached repository
if [[ -f citron.tar.zst ]]; then
    echo "========================================"
    echo "  Do you want to delete the cached repository file citron.tar.zst? (y/[N])"
    echo "========================================"
    read -rp "Enter choice: " DELETE_CACHE
    if [[ "$DELETE_CACHE" =~ ^[Yy]$ ]]; then
        echo "Deleting cached repository..."
        rm -f citron.tar.zst
    fi
fi
