#!/bin/zsh
# ------------------------------------------------------------------------------
# 1. Utility. Audio Cover Art Embedder
# Recursively embeds cover art (cover.jpg/png) into audio files using kid3-cli.
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES (Read before editing):
# 1. Formatting: Keep layout compact. No vertical whitespace inside blocks.
# 2. Separators: Use 'Sandwich' headers (# ------) with strict spacing (1 line before).
# 3. Idempotency: Scripts must be safe to re-run. Check state before changes.
# 4. Safety: Use 'setopt ERR_EXIT NO_UNSET PIPE_FAIL'.
# 5. Context: No hardcoded secrets.
# 6. Syntax: Use Zsh native modifiers and tooling
# 8. Documentation: Start section with 'Purpose' comment block (1 line before and after). No meta or inline comments within code.
#
# ------------------------------------------------------------------------------

setopt ERR_EXIT NO_UNSET PIPE_FAIL globstarshort nullglob

print -P "%F{green}--- Starting Cover Art Fix ---%f"

# ------------------------------------------------------------------------------
# 1. Prerequisite Checks
# ------------------------------------------------------------------------------

# Purpose: Validate dependencies and arguments.
# - Dependency: Checks for kid3-cli.
# - Path: defaults to current directory if no argument provided.

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

# ------------------------------------------------------------------------------
# 2. Processing
# ------------------------------------------------------------------------------

# Purpose: Embed images into audio files.
# - Priority: cover.jpg > cover.png > folder.jpg > folder.png.
# - Action: Applies image to all supported audio files in the folder.

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
        print -P "%F{green}Processing: ${folder:t}%f"
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

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------

print -P "%F{green}--- Cover Art Fix Complete ---%f"
