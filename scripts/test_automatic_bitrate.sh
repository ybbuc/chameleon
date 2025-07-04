#!/bin/bash

# Test script for automatic bitrate feature

echo "Testing automatic bitrate feature..."

# Create a test audio file with known bitrate (192 kbps)
echo "Creating test audio file with 192 kbps..."
ffmpeg -f lavfi -i "sine=frequency=1000:duration=5" -b:a 192k test_audio_192k.mp3 -y

# Use MediaInfo to verify the bitrate
echo -e "\nChecking bitrate with MediaInfo:"
mediainfo test_audio_192k.mp3 | grep -i "bit rate"

# Now test conversion with automatic bitrate
echo -e "\nTesting conversion with automatic bitrate..."
echo "1. Drop test_audio_192k.mp3 into Chameleon"
echo "2. Select MP3 as output format"
echo "3. Check that 'Automatic (192 kbps)' appears in the bitrate dropdown"
echo "4. Convert and verify the output has 192 kbps"

echo -e "\nPress Enter when ready to clean up test files..."
read

# Cleanup
rm -f test_audio_192k.mp3

echo "Test complete!"