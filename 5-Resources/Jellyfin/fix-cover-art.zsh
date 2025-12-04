#!/bin/zsh
# ------------------------------------------------------------------------------
# Audio Cover Art Embedder (Kid3 Wrapper)
# Recursively embeds cover art (cover.jpg/png) into audio files using kid3-cli.
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES (Read before editing):
# 1. Formatting: Keep layout compact. No vertical whitespace inside blocks.
# 2. Separators: Use double dotted lines (# ------) for major sections.
# 3. Idempotency: Scripts must be safe to re-run. Check state before changes.
# 4. Safety: Use 'setopt ERR_EXIT NO_UNSET PIPE_FAIL'.
# 5. Context: Hardcoded for AMD Ryzen 7000/Radeon 7000. No hardcoded secrets.
# 6. Syntax: Use Zsh native modifiers (e.g. ${VAR:h}) over subshells.
# 7. Output: Use 'print'. Do NOT use 'echo'.
#
# ------------------------------------------------------------------------------

# Safety Options
setopt ERR_EXIT     # Exit on error
setopt NO_UNSET     # Error on unset variables
setopt PIPE_FAIL    # Fail if any part of a pipe fails

# Logic Options
setopt globstarshort
setopt nullglob

# Load Colours
autoload -Uz colors && colors
GREEN="${fg[green]}"
YELLOW="${fg[yellow]}"
RED="${fg[red]}"
BLUE="${fg[blue]}"
NC="${reset_color}"

# Check for dependency
if ! (( $+commands[kid3-cli] )); then
    print "${RED}Error: kid3-cli is not installed.${NC}"
    exit 1
fi

# Ensure we use the Absolute Path of the target directory
TARGET_DIR="${1:-$PWD}"
TARGET_DIR=${TARGET_DIR:A} # Zsh modifier for absolute path (realpath)
print "${BLUE}Scanning: $TARGET_DIR${NC}"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 1. Discovery
# Define the condition for a "valid" folder (contains any of the 4 image types)
local match_code='[[ -f $REPLY/cover.jpg || -f $REPLY/cover.png || -f $REPLY/folder.jpg || -f $REPLY/folder.png ]]'

# Build list of target folders
local -a target_folders
target_folders=("$TARGET_DIR" "$TARGET_DIR"/**/*(/e:"$match_code":))

if (( ${#target_folders} == 0 )); then
    print "${YELLOW}No directories with valid cover art found.${NC}"
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
        print "${GREEN}Processing: ${folder:t}${NC}"
        print "  Source: ${cover_img:t}"

        for file in $audio_files; do
            # Embed image using absolute path
            if output=$(kid3-cli -c "set picture:\"$cover_img\" \"\"" "$file" 2>&1); then
                 : # Success - silent
            else
                 print "${RED}    Failed: ${file:t} -> $output${NC}"
            fi
        done

        # Trigger folder update for Jellyfin
        touch "$folder"
    fi
done

print "${BLUE}Batch operation complete.${NC}"
