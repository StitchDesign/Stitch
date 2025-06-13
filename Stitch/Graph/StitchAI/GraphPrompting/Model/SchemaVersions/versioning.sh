# First argument is our new version NumberFormatter
root_dir="$(dirname $0)/Stitch/Graph/StitchAI/GraphPrompting/Model/SchemaVersions"

new_version=$1
new_version_path="$root_dir/V$new_version"

old_version="$((new_version - 1))"
old_version_path="$root_dir/V$old_version"

# Update permissions of new version
# sudo chmod -R u+w new_version_path

# Function to recursively copy files and update versioning
create_new_version() {
    local old_version_path="$1"
    local new_version_path="$2"
    
    # Create destination folder if it doesn't exist
    mkdir -p "$new_version_path"
                                    
    # Iterate through each file in the source folder
    for file in "$old_version_path"/*; do
        if [ -d "$file" ]; then
            # If it's a directory, recursively call the function for the subfolder
            create_new_version "$file" "$new_version_path/$(basename "$file")"
        elif [ -f "$file" ]; then
            # If it's a file, perform the versioning and copy to the destination folder
            file_name=$(basename "$file")
            file_extension="${file_name##*.}"
                                    
            # Copy file with new file path
            new_file_name="${file_name/_V$old_version/_V$new_version}"
            cp "$file" "$new_version_path$destination_folder/$new_file_name"
            echo "Copied: $file -> $new_version_path$destination_folder/$new_file_name"
        fi
    done
}

echo "Creating v$new_version"
echo "$new_version_path"
echo "Copies from $old_version_path"

# Invoke versioning function
create_new_version "$old_version_path" "$new_version_path"
echo "Versioning complete"
