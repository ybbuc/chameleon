#!/bin/bash

# Fix libraries with empty dependency paths
cd Chameleon/Frameworks

echo "Searching for libraries with empty dependency paths..."

for lib in *.dylib; do
    echo "Checking $lib..."
    
    # Get dependencies and look for lines starting with just a space
    deps=$(otool -L "$lib" 2>&1)
    
    # Check if there are any dependencies with missing paths (lines starting with space)
    if echo "$deps" | grep -q "^[[:space:]][[:space:]](compatibility"; then
        echo "Found library with missing paths: $lib"
        echo "Dependencies:"
        echo "$deps"
        echo "---"
        
        # Try to fix based on known patterns
        # For libtiff
        if [[ "$lib" == "libtiff.6.dylib" ]]; then
            echo "Fixing libtiff.6.dylib..."
            # Get the original to see what the dependencies should be
            orig_deps=$(otool -L /opt/homebrew/opt/libtiff/lib/libtiff.6.dylib 2>/dev/null)
            
            # Fix each dependency
            install_name_tool -change "/opt/homebrew/opt/zstd/lib/libzstd.1.dylib" "@executable_path/../Frameworks/libzstd.1.dylib" "$lib"
            install_name_tool -change "/opt/homebrew/opt/xz/lib/liblzma.5.dylib" "@executable_path/../Frameworks/liblzma.5.dylib" "$lib"
            install_name_tool -change "/opt/homebrew/opt/jpeg-turbo/lib/libjpeg.8.dylib" "@executable_path/../Frameworks/libjpeg.8.dylib" "$lib"
        fi
    fi
done

echo "Done checking libraries."