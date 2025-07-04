#!/bin/bash

echo "Testing media info button feature..."

# Create test files with different properties
echo "Creating test media files..."

# Audio file with specific properties
ffmpeg -f lavfi -i "sine=frequency=1000:duration=5" -ar 48000 -ac 2 -b:a 192k test_audio.mp3 -y

# Video file with audio
ffmpeg -f lavfi -i testsrc=duration=5:size=1280x720:rate=30 -f lavfi -i "sine=frequency=440:duration=5" \
  -c:v libx264 -crf 23 -c:a aac -b:a 128k test_video.mp4 -y

echo -e "\nTest files created!"
echo -e "\nTo test the info button:"
echo "1. Run Chameleon"
echo "2. Drop test_audio.mp3 or test_video.mp4 into the app"
echo "3. Hover over the file row"
echo "4. Click the info button (circle with 'i')"
echo "5. A popover should show detailed media information"

echo -e "\nPress Enter when ready to clean up test files..."
read

# Cleanup
rm -f test_audio.mp3 test_video.mp4

echo "Test complete!"