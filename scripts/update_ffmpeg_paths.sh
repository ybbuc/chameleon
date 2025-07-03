#!/bin/bash

# Update FFmpeg and FFprobe to use bundled libraries
FRAMEWORKS_DIR="@executable_path/../Frameworks"

echo "Updating FFmpeg and FFprobe library paths..."

for tool in "./Chameleon/ffmpeg" "./Chameleon/ffprobe"; do
    if [ -f "$tool" ]; then
        echo ""
        echo "Updating $(basename $tool)..."
        
        # Get all library dependencies
        deps=$(otool -L "$tool" | grep -E "/opt/homebrew|/usr/local" | awk '{print $1}')
        
        for dep in $deps; do
            # Extract just the library filename
            libname=$(basename "$dep")
            
            # Check if we have this library bundled
            if [ -f "./Chameleon/Frameworks/$libname" ]; then
                newpath="$FRAMEWORKS_DIR/$libname"
                echo "  Updating $dep -> $newpath"
                install_name_tool -change "$dep" "$newpath" "$tool"
            else
                echo "  Warning: $libname not found in Frameworks directory"
                # For SDL2, we might not bundle it as it's primarily for FFplay
                if [[ "$libname" == "libSDL2"* ]]; then
                    echo "  Note: SDL2 is optional for FFmpeg/FFprobe operation"
                fi
            fi
        done
    fi
done

echo ""
echo "Done! FFmpeg and FFprobe updated to use bundled libraries where available."