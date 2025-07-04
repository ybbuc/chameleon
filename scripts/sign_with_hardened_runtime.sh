#!/bin/bash

# Sign all binaries and libraries with Hardened Runtime for App Store distribution

echo "Signing executables with Hardened Runtime..."

# Sign main executables
for binary in Chameleon/ffmpeg Chameleon/ffprobe Chameleon/magick; do
    if [ -f "$binary" ]; then
        echo "Signing $binary..."
        codesign --force --options runtime --sign - "$binary"
    fi
done

echo ""
echo "Signing dynamic libraries with Hardened Runtime..."

# Sign all dynamic libraries
find Chameleon/Frameworks -name "*.dylib" -type f | while read -r lib; do
    echo "Signing $lib..."
    codesign --force --options runtime --sign - "$lib"
done

echo ""
echo "Verification:"
echo "============="

# Verify executables
for binary in Chameleon/ffmpeg Chameleon/ffprobe Chameleon/magick; do
    if [ -f "$binary" ]; then
        echo ""
        echo "$binary:"
        codesign -dvv "$binary" 2>&1 | grep -E "flags="
    fi
done

echo ""
echo "Done! All binaries have been signed with Hardened Runtime."