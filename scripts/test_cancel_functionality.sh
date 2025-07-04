#!/bin/bash

# Test script to verify cancel button functionality

echo "Testing Chameleon cancel button functionality..."

# Create a large test video file that will take time to convert
echo "Creating test video file..."
ffmpeg -f lavfi -i testsrc=duration=60:size=1920x1080:rate=30 -f lavfi -i sine=frequency=1000:duration=60 -pix_fmt yuv420p /tmp/test_video.mp4 2>/dev/null

if [ ! -f /tmp/test_video.mp4 ]; then
    echo "Failed to create test video file"
    exit 1
fi

echo "Test video created at /tmp/test_video.mp4"

# Launch Chameleon
echo "Launching Chameleon..."
open /Users/A200273741/Library/Developer/Xcode/DerivedData/Chameleon-gghxwlfnhzgvrpdcoqulvnxotwpw/Build/Products/Debug/Chameleon.app

echo ""
echo "Test Instructions:"
echo "1. Drag /tmp/test_video.mp4 into Chameleon"
echo "2. Select a format that takes time (e.g., convert to GIF or another video format)"
echo "3. Click Convert to start the conversion"
echo "4. While converting, click the Cancel button"
echo "5. Check if the ffmpeg process is terminated"
echo ""
echo "Press Enter to check for ffmpeg processes before conversion..."
read

# Check for any ffmpeg processes before
echo "Checking for ffmpeg processes before conversion..."
ps aux | grep -E "ffmpeg" | grep -v grep

echo ""
echo "Now start the conversion in Chameleon and press Enter when it's running..."
read

# Check for running ffmpeg process
echo "Checking for running ffmpeg process..."
ps aux | grep -E "ffmpeg" | grep -v grep

echo ""
echo "Now click Cancel in Chameleon and press Enter..."
read

# Check if ffmpeg process was terminated
echo "Checking if ffmpeg process was terminated..."
ps aux | grep -E "ffmpeg" | grep -v grep

echo ""
echo "If no ffmpeg processes are shown above, the cancel functionality is working correctly!"

# Cleanup
rm -f /tmp/test_video.mp4

echo "Test complete!"