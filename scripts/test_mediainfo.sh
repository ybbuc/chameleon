#!/bin/bash

# Test script to verify MediaInfo integration
echo "Testing MediaInfo integration in Chameleon..."

# Find a test media file
TEST_FILE=""
if [ -f ~/Desktop/*.mp4 ]; then
    TEST_FILE=$(ls ~/Desktop/*.mp4 | head -1)
elif [ -f ~/Downloads/*.mp4 ]; then
    TEST_FILE=$(ls ~/Downloads/*.mp4 | head -1)
elif [ -f ~/Movies/*.mp4 ]; then
    TEST_FILE=$(ls ~/Movies/*.mp4 | head -1)
fi

if [ -z "$TEST_FILE" ]; then
    echo "No test video file found. Please place an MP4 file on your Desktop, Downloads, or Movies folder."
    exit 1
fi

echo "Found test file: $TEST_FILE"

# Build and run the app
APP_PATH="/Users/A200273741/Library/Developer/Xcode/DerivedData/Chameleon-gghxwlfnhzgvrpdcoqulvnxotwpw/Build/Products/Debug/Chameleon.app"

if [ ! -d "$APP_PATH" ]; then
    echo "App not found at expected path. Please build the app first."
    exit 1
fi

# Check if MediaInfo library is included
echo -e "\nChecking for MediaInfo library in app bundle..."
if [ -f "$APP_PATH/Contents/Frameworks/libmediainfo.0.dylib" ]; then
    echo "✓ MediaInfo library found in app bundle"
    otool -L "$APP_PATH/Contents/Frameworks/libmediainfo.0.dylib" | head -5
else
    echo "✗ MediaInfo library NOT found in app bundle"
fi

echo -e "\nTo test the MediaInfo integration:"
echo "1. Open $APP_PATH"
echo "2. Drag and drop: $TEST_FILE"
echo "3. Check the console output for 'MediaInfoLib initialized successfully'"
echo "4. Convert the file to verify media analysis is working"