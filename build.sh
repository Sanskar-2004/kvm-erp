#!/bin/bash
set -e

echo "=== Starting Flutter Web Build on Vercel ==="

# Clean any broken/partial Flutter installation
if [ -d "_flutter" ] && [ ! -f "_flutter/bin/flutter" ]; then
    echo "Cleaning corrupt Flutter folder..."
    rm -rf _flutter
fi

# Clone Flutter SDK if not present
if [ ! -d "_flutter" ]; then
    echo "Cloning Flutter SDK..."
    git clone https://github.com/flutter/flutter.git --depth 1 -b stable _flutter
else
    echo "Flutter SDK directory exists."
fi

echo "Setting PATH..."
export PATH="$PATH:$(pwd)/_flutter/bin"

echo "Enabling Flutter Web..."
./_flutter/bin/flutter config --enable-web

echo "Getting Flutter packages..."
./_flutter/bin/flutter pub get

echo "Building Flutter Web Release..."
./_flutter/bin/flutter build web --release

echo "=== Flutter Web Build Complete ==="
