#!/bin/bash

# Test script to verify subtitle detection functionality

echo "Testing subtitle detection in Chameleon..."
echo "=========================================="

# Find a video file with subtitles for testing
TEST_VIDEO=""

# Check common locations for test videos
if [ -f "$HOME/Downloads/test_video_with_subtitles.mp4" ]; then
    TEST_VIDEO="$HOME/Downloads/test_video_with_subtitles.mp4"
elif [ -f "$HOME/Movies/test_video_with_subtitles.mp4" ]; then
    TEST_VIDEO="$HOME/Movies/test_video_with_subtitles.mp4"
fi

if [ -z "$TEST_VIDEO" ]; then
    echo "Creating a test video with subtitles..."
    
    # Create a simple test video with subtitles using ffmpeg
    if command -v ffmpeg &> /dev/null; then
        # Create temporary directory
        TEMP_DIR=$(mktemp -d)
        
        # Create a simple subtitle file
        cat > "$TEMP_DIR/test.srt" << EOF
1
00:00:00,000 --> 00:00:05,000
This is a test subtitle

2
00:00:05,000 --> 00:00:10,000
Testing subtitle detection
EOF
        
        # Create a test video with subtitles embedded
        ffmpeg -f lavfi -i testsrc=duration=10:size=640x480:rate=30 \
               -f lavfi -i sine=frequency=1000:duration=10 \
               -i "$TEMP_DIR/test.srt" \
               -c:v libx264 -c:a aac -c:s mov_text \
               -map 0:v -map 1:a -map 2:s \
               "$HOME/Downloads/test_video_with_subtitles.mp4" -y 2>/dev/null
        
        if [ $? -eq 0 ]; then
            TEST_VIDEO="$HOME/Downloads/test_video_with_subtitles.mp4"
            echo "Created test video at: $TEST_VIDEO"
        else
            echo "Failed to create test video"
            exit 1
        fi
        
        # Clean up
        rm -rf "$TEMP_DIR"
    else
        echo "FFmpeg not found. Please install ffmpeg or provide a test video with subtitles."
        exit 1
    fi
fi

echo ""
echo "Using test video: $TEST_VIDEO"
echo ""

# Open Chameleon with the test video
echo "Opening Chameleon..."
open -a Chameleon "$TEST_VIDEO"

echo ""
echo "Instructions:"
echo "1. Check if a subtitle button (captions.bubble icon) appears next to the video file"
echo "2. Click the subtitle button to open the subtitle selection popover"
echo "3. The popover should show:"
echo "   - A list of all subtitle tracks with checkboxes"
echo "   - Track names, languages, and codec information"
echo "   - 'FORCED' and 'DEFAULT' badges where applicable"
echo "   - 'Select All' and 'Deselect All' buttons"
echo "4. Toggle checkboxes to select/deselect subtitle tracks"
echo ""
echo "To create more test videos with subtitles:"
echo "ffmpeg -i input.mp4 -i subtitles.srt -c copy -c:s mov_text output.mp4"
echo ""
echo "To create a video with multiple subtitle tracks:"
echo "ffmpeg -i input.mp4 -i english.srt -i spanish.srt -i french.srt \\"
echo "  -map 0:v -map 0:a -map 1 -map 2 -map 3 \\"
echo "  -c copy -c:s mov_text \\"
echo "  -metadata:s:s:0 language=eng -metadata:s:s:0 title=\"English\" \\"
echo "  -metadata:s:s:1 language=spa -metadata:s:s:1 title=\"Spanish\" \\"
echo "  -metadata:s:s:2 language=fra -metadata:s:s:2 title=\"French\" \\"
echo "  output.mp4"