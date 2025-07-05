#!/bin/bash

# Test script to explore MediaInfo parameters

echo "MediaInfo Parameter Explorer"
echo "==========================="
echo ""

# Check if mediainfo is installed
if ! command -v mediainfo &> /dev/null; then
    echo "Error: mediainfo command not found. Please install MediaInfo CLI:"
    echo "  brew install mediainfo"
    exit 1
fi

# Find a test file
TEST_FILE="$1"
if [ -z "$TEST_FILE" ]; then
    # Try to find a test file
    if [ -f ~/Desktop/*.mp4 ]; then
        TEST_FILE=$(ls ~/Desktop/*.mp4 2>/dev/null | head -1)
    elif [ -f ~/Downloads/*.mp4 ]; then
        TEST_FILE=$(ls ~/Downloads/*.mp4 2>/dev/null | head -1)
    elif [ -f ~/Downloads/*.m4a ]; then
        TEST_FILE=$(ls ~/Downloads/*.m4a 2>/dev/null | head -1)
    fi
fi

if [ -z "$TEST_FILE" ] || [ ! -f "$TEST_FILE" ]; then
    echo "Usage: $0 <media_file>"
    echo "No media file provided or found automatically."
    exit 1
fi

echo "Testing file: $TEST_FILE"
echo ""

# Show all available parameters
echo "=== All Available MediaInfo Parameters ==="
mediainfo --Info-Parameters | head -100
echo ""

echo "=== Audio-specific Parameters containing 'Format' ==="
mediainfo --Info-Parameters | grep -i "audio.*format" | head -20
echo ""

echo "=== Parameters with 'Commercial' or 'String' ==="
mediainfo --Info-Parameters | grep -E "Commercial|/String" | head -20
echo ""

echo "=== Testing Audio Format Parameters on File ==="
echo "Basic format info:"
mediainfo --Inform="Audio;Format: %Format%\n" "$TEST_FILE"
echo ""

echo "Testing expanded format parameters:"
mediainfo --Inform="Audio;Format: %Format%\nFormat/String: %Format/String%\nFormat_Commercial: %Format_Commercial%\nFormat_Commercial_IfAny: %Format_Commercial_IfAny%\nFormat_Version: %Format_Version%\nFormat_Profile: %Format_Profile%\nFormat_Settings: %Format_Settings%\n" "$TEST_FILE"
echo ""

echo "=== Full Audio Stream Info ==="
mediainfo --Inform="Audio;===Audio Stream===\nFormat: %Format%\nFormat/String: %Format/String%\nFormat/Info: %Format/Info%\nFormat_Commercial: %Format_Commercial%\nFormat_Commercial_IfAny: %Format_Commercial_IfAny%\nFormat_Version: %Format_Version%\nFormat_Profile: %Format_Profile%\nFormat_Level: %Format_Level%\nFormat_Settings: %Format_Settings%\nFormat_Settings_Endianness: %Format_Settings_Endianness%\nFormat_Settings_JOC: %Format_Settings_JOC%\nFormat_AdditionalFeatures: %Format_AdditionalFeatures%\nCodecID: %CodecID%\nCodecID/String: %CodecID/String%\nCodecID/Info: %CodecID/Info%\nCodecID/Hint: %CodecID/Hint%\nCodecID_Description: %CodecID_Description%\n" "$TEST_FILE"
echo ""

echo "=== Testing with Different Output Formats ==="
echo "XML output (first 50 lines):"
mediainfo --Output=XML "$TEST_FILE" | head -50
echo ""

echo "Done! Check the output above to see which format parameters are available."
echo ""
echo "Note: Not all parameters will have values for every file type."
echo "Look for non-empty values to see what MediaInfo provides for your file."