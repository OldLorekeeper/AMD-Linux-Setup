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
# 6. Syntax: Use Zsh native modifiers and tooling.
# 7. Documentation: Start section with 'Purpose' comment block (1 line before and after). No meta or inline comments within code.
# 8. UI & Theming:
#    - Headers: Blue (%K{blue}%F{black}) for sections, Yellow (%K{yellow}%F{black}) for sub-sections.
#    - Spacing: One empty line before and after headers. Use embedded \n to save lines.
#      * Exception: If a header follows another header immediately, omit the leading \n to avoid double gaps.
#    - Inputs: Yellow description line (%F{yellow}) followed by minimal prompt (read "VAR?Prompt: ").
#    - Context: Cyan (%F{cyan}) for info/metadata (prefixed with ℹ).
#    - Status: Green (%F{green}) for success/loaded, Red (%F{red}) for errors/warnings.
#    - Silence: Do not repeat/confirm manual user input. Only print confirmation (%F{green}) if the value was pre-loaded from secrets.
#
# ------------------------------------------------------------------------------

setopt ERR_EXIT NO_UNSET PIPE_FAIL globstarshort nullglob

SCRIPT_DIR=${0:a:h}

print -P "\n%K{green}%F{black} STARTING COVER ART FIX %k%f\n"

# ------------------------------------------------------------------------------
# 1. Prerequisite Checks
# ------------------------------------------------------------------------------

# Purpose: Validate dependencies and arguments.

print -P "\n%K{blue}%F{black} 1. PREREQUISITE CHECKS %k%f\n"
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

# ------------------------------------------------------------------------------
# 2. Processing
# ------------------------------------------------------------------------------

# Purpose: Embed images into audio files (Priority: cover.jpg > cover.png > folder.jpg > folder.png).

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
        print -P "%F{cyan}ℹ Processing: ${folder:t}%f"
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

print -P "\n%K{green}%F{black} PROCESS COMPLETE %k%f\n"
