#!/bin/zsh
# ------------------------------------------------------------------------------
# 1. Utility. Audio Cover Art Embedder
# Recursively embeds cover art (cover.jpg/png) into audio files using kid3-cli.
# ------------------------------------------------------------------------------

# region Init
setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB globstarshort nullglob
SCRIPT_DIR=${0:a:h}
print -P "\n%K{green}%F{black} STARTING COVER ART FIX %k%f\n"
# endregion

# ------------------------------------------------------------------------------
# 1. Prerequisite Checks
# ------------------------------------------------------------------------------

# Purpose: Validate dependencies and arguments.

# region 1. Prerequisite Checks
print -P "%K{blue}%F{black} 1. PREREQUISITE CHECKS %k%f\n"
if ! (( $+commands[kid3-cli] )); then
    print -P "%F{red}Error: kid3-cli is not installed.%f"
    exit 1
fi

TARGET_DIR="${1:-$PWD}"
if [[ ! -d "$TARGET_DIR" ]]; then
    print -P "%F{red}Error: Directory not found: $TARGET_DIR%f"
    exit 1
fi

local -a target_folders
target_folders=("$TARGET_DIR" "$TARGET_DIR"/**/*(/e:"$match_code":))

if (( ${#target_folders} == 0 )); then
    print -P "%F{yellow}No directories with valid cover art found.%f"
    exit 0
fi

print -P "Targets: %F{green}Found ${#target_folders} directories%f"
# endregion

# ------------------------------------------------------------------------------
# 2. Processing
# ------------------------------------------------------------------------------

# Purpose: Embed images into audio files (Priority: cover.jpg > cover.png > folder.jpg > folder.png).

# region 2. Processing
print -P "\n%K{blue}%F{black} 2. PROCESSING %k%f\n"
for folder in $target_folders; do
    local cover_img=""
    if [[ -f "$folder/cover.jpg" ]]; then
        cover_img="$folder/cover.jpg"
    elif [[ -f "$folder/cover.png" ]]; then
        cover_img="$folder/cover.png"
    elif [[ -f "$folder/folder.jpg" ]]; then
        cover_img="$folder/folder.jpg"
    elif [[ -f "$folder/folder.png" ]]; then
        cover_img="$folder/folder.png"
    fi
    
    local -a audio_files
    audio_files=("$folder"/*.{mp3,flac,m4a,ogg}(N))
    
    if (( ${#audio_files} > 0 )); then
        print -P "\n%F{cyan}ℹ Processing: ${folder:t}%f\n"
        print "  Source: ${cover_img:t}"
        for file in $audio_files; do
            if output=$(kid3-cli -c "set picture:\"$cover_img\" \"\"" "$file" 2>&1); then
                 :
            else
                 print -P "%F{red}    Failed: ${file:t}%f"
            fi
        done
    fi
done
# endregion

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------

# region End
print -P "\n%K{green}%F{black} PROCESS COMPLETE %k%f\n"
# endregion
