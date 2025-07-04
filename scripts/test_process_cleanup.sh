#!/bin/bash

# Test script to verify process cleanup on app termination

echo "Starting Chameleon process cleanup test..."

# Start a long-running conversion in the background
cat > /tmp/test_video.txt << 'EOF'
This is a test file that will be converted to simulate a long-running process.
We'll convert this to a video format using FFmpeg which should take some time.
EOF

# Launch Chameleon in background
echo "Launching Chameleon..."
open /Users/A200273741/Library/Developer/Xcode/DerivedData/Chameleon-gghxwlfnhzgvrpdcoqulvnxotwpw/Build/Products/Debug/Chameleon.app

# Wait for app to start
sleep 3

# Check for any ffmpeg/pandoc/magick processes before
echo "Checking for processes before conversion..."
ps aux | grep -E "(ffmpeg|pandoc|magick)" | grep -v grep

# Start a conversion (you'll need to manually drag a file to convert)
echo "Please drag a large video file into Chameleon to start a conversion..."
echo "Then press Enter to continue"
read

# Check for running processes
echo "Checking for running conversion processes..."
ps aux | grep -E "(ffmpeg|pandoc|magick)" | grep -v grep

# Kill the Chameleon app
echo "Terminating Chameleon app..."
pkill -TERM Chameleon

# Wait a moment
sleep 2

# Check if processes are cleaned up
echo "Checking for processes after termination..."
ps aux | grep -E "(ffmpeg|pandoc|magick)" | grep -v grep

echo "Test complete!"