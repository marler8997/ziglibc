#!/usr/bin/env bash

# Define variables
LIBC=true
LINUX=true
ALLOCA=true
POSIX=true
WIN32=false
LOCATION=/usr/include # Modify it as needed
echo "Installing header files to $LOCATION!"
# Function to copy directory contents if boolean is true
copy_directory_contents() {
    if [ "$2" = true ]; then
        echo "Copying contents of $1 to $LOCATION"
        cp -r "$1"/* $LOCATION
        # Perform replacements in copied files
        find $LOCATION -type f -exec bash -c '
            file="$1"
            # Replace "#include "../private/file"" with "#include "private/file""
            sed -i "s/#include \"\.\.\/private\//\#include \"private\//g" "$file"
            # Replace "#include "../../private/file"" with "#include "../private/file""
            sed -i "s/#include \"\.\.\/\.\.\/private\//\#include \"\.\.\/private\//g" "$file"
        ' _ {} \;
    else
        echo "$1 is not selected. Skipping copy."
    fi
}
# Copy directory contents based on boolean variables
copy_directory_contents "inc/libc" "$LIBC"
copy_directory_contents "inc/linux" "$LINUX"
copy_directory_contents "inc/alloca" "$ALLOCA"
copy_directory_contents "inc/posix" "$POSIX"
copy_directory_contents "inc/win32" "$WIN32"
cp -r "inc/private" "$LOCATION/"
