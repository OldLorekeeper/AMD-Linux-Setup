#!/usr/bin/zsh
# ------------------------------------------------------------------------------
# Audio Cover Art Embedder (Kid3 Wrapper)
# ------------------------------------------------------------------------------

# Safety Options
setopt ERR_EXIT
setopt NO_UNSET
setopt PIPE_FAIL

# Logic Options
setopt globstarshort
setopt nullglob

# Check for dependency
if ! (( $+commands[kid3-cli] )); then
    print -P "%F{red}Error: kid3-cli is not installed.%f"
    exit 1
fi

# Ensure we use the Absolute Path of the target directory
TARGET_DIR="${1:-$PWD}"
TARGET_DIR=${TARGET_DIR:A} # Zsh modifier for absolute path (realpath)
print -P "%F{blue}Scanning: $TARGET_DIR%f"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 1. Discovery
# Define the condition for a "valid" folder (contains any of the 4 image types)
local match_code='[[ -f $REPLY/cover.jpg || \
-f $REPLY/cover.png || -f $REPLY/folder.jpg || -f $REPLY/folder.png ]]'

# Build list of target folders
local -a target_folders
target_folders=("$TARGET_DIR" "$TARGET_DIR"/**/*(/e:"$match_code":))

if (( ${#target_folders} == 0 )); then
    print -P "%F{yellow}No directories with valid cover art found.%f"
    exit 0
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 2. Processing
for folder in $target_folders; do
    local cover_img=""

    # Priority Hierarchy
    if [[ -f "$folder/cover.jpg" ]]; then
        cover_img="$folder/cover.jpg"
    elif [[ -f "$folder/cover.png" ]]; then
        cover_img="$folder/cover.png"
    elif [[ -f "$folder/folder.jpg" ]]; then
        cover_img="$folder/folder.jpg"
    elif [[ -f "$folder/folder.png" ]]; then
        cover_img="$folder/folder.png"
    fi

    # Find audio files
    local -a audio_files
    audio_files=("$folder"/*.{mp3,flac,m4a,ogg}(N))

    if (( ${#audio_files} > 0 )); then
        print -P "%F{green}Processing: ${folder:t}%f"
        print -P "  Source: ${cover_img:t}"

        for file in $audio_files; do
            # Embed image using absolute path
            if output=$(kid3-cli -c "set picture:\"$cover_img\" \"\"" "$file" 2>&1); then
                 # Success - silent
                 :
            else
                 print -P "%F{red}    Failed: ${file:t} -> $output%f"
            fi
        done

        # Trigger folder update for Jellyfin
        touch "$folder"
    fi
done

print -P "%F{blue}Batch operation complete.%f"
