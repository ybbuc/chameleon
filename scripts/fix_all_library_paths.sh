#!/bin/bash

cd Chameleon/Frameworks

echo "Fixing all library dependency paths..."

# First, run the existing update script to fix known paths
../../update_library_paths_frameworks.sh

# Now fix specific libraries with empty paths based on what they should be

# For each library, check original dependencies and fix empty paths
for lib in *.dylib; do
    echo "Processing $lib..."
    
    # Get the homebrew path for this library if it exists
    brew_lib="/opt/homebrew/opt/*/lib/$lib"
    brew_lib_path=$(ls $brew_lib 2>/dev/null | head -1)
    
    if [ -f "$brew_lib_path" ]; then
        echo "  Found original at: $brew_lib_path"
        
        # Get original dependencies
        orig_deps=$(otool -L "$brew_lib_path" 2>/dev/null | tail -n +2)
        
        # Get current dependencies  
        curr_deps=$(otool -L "$lib" 2>/dev/null | tail -n +2)
        
        # Count dependencies
        orig_count=$(echo "$orig_deps" | wc -l)
        curr_count=$(echo "$curr_deps" | wc -l)
        
        if [ "$orig_count" -eq "$curr_count" ]; then
            # Process each dependency
            i=1
            while IFS= read -r orig_dep && IFS= read -r curr_dep <&3; do
                orig_path=$(echo "$orig_dep" | awk '{print $1}')
                curr_path=$(echo "$curr_dep" | awk '{print $1}')
                
                # If current path is empty (just spaces), use original
                if [[ "$curr_path" == "" ]] || [[ "$curr_path" =~ ^[[:space:]]+$ ]]; then
                    echo "    Fixing empty path with: $orig_path"
                    
                    # Extract library name from original path
                    lib_name=$(basename "$orig_path")
                    
                    # Check if we have this library bundled
                    if [ -f "$lib_name" ]; then
                        new_path="@executable_path/../Frameworks/$lib_name"
                        echo "    Changing to bundled: $new_path"
                        
                        # Use the original path as the old path for install_name_tool
                        install_name_tool -change "$orig_path" "$new_path" "$lib" 2>/dev/null
                    fi
                fi
                ((i++))
            done < <(echo "$orig_deps") 3< <(echo "$curr_deps")
        fi
    else
        echo "  No original found for $lib - skipping"
    fi
done

echo "Done fixing library paths!"