#!/bin/bash

# Debug script to test MediaInfo integration and see why fallbacks occur

echo "Testing MediaInfo debug output..."
echo "================================="

# Check if MediaInfo CLI is available for comparison
if command -v mediainfo &> /dev/null; then
    echo "✓ MediaInfo CLI found at: $(which mediainfo)"
    echo "  Version: $(mediainfo --Version | head -1)"
else
    echo "✗ MediaInfo CLI not found (optional, for comparison only)"
fi

echo ""
echo "To test MediaInfo debugging:"
echo "1. Run the Chameleon app"
echo "2. Drop various file types (MP3, M4A, WAV, FLAC, etc.)"
echo "3. Watch the console output for:"
echo "   - Which detection method is used"
echo "   - What MediaInfo detects vs what's missing"
echo "   - Why fallbacks occur"
echo ""
echo "Common reasons for MediaInfo fallback:"
echo "- File format not supported by MediaInfo"
echo "- Missing audio stream information"
echo "- Corrupted or incomplete file"
echo "- DRM-protected files"
echo "- Codec not recognized by MediaInfo"