#!/usr/bin/env zsh
# media_optimizer.zsh
# Optimizes media library using AMD GPU hardware encoding (HEVC/VAAPI).
# Enforces a strict processing window of 01:00 AM to 05:00 AM.

setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB

# region [Initialization]

print -P "\n%K{green}%F{black} START: Media Optimizer %k%f\n"

readonly MEDIA_DIR="/mnt/Media"
readonly TEMP_DIR="/tmp/media_optimizer"
mkdir -p "$TEMP_DIR"

# endregion

# ------------------------------------------------------------------------------
# 1. Verification & Pre-flight Checks
# ------------------------------------------------------------------------------

# region [Verification]
# Check time window and dependencies before processing.

print -P "\n%K{blue}%F{black} 1: Verification %k%f\n"

print -P "%F{cyan}ℹ Checking dependencies...%f\n"
if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
    print -P "%F{red}✖ ffmpeg or ffprobe not found. Exiting.%f\n"
    exit 1
fi
print -P "%F{green}✔ Dependencies met.%f\n"

local current_hour
current_hour=$(date +%H)
if [[ $current_hour -lt 1 || $current_hour -ge 5 ]]; then
    print -P "%F{yellow}⚠ Current time ($current_hour:00) is outside processing window (01:00 - 05:00). Exiting early.%f\n"
    print -P "\n%K{green}%F{black} END: Media Optimizer %k%f\n"
    exit 0
fi

# endregion

# ------------------------------------------------------------------------------
# 2. Scanning and Transcoding
# ------------------------------------------------------------------------------

# region [Transcoding]
# Find unoptimized files and transcode them utilizing VAAPI if inside time window.

print -P "\n%K{blue}%F{black} 2: Media Processing %k%f\n"

print -P "%F{cyan}ℹ Searching for unoptimized media in $MEDIA_DIR...%f\n"

local -a files
files=("${(@f)$(find "$MEDIA_DIR" -type f \( -name '*.mkv' -o -name '*.mp4' \))}")

for file in "${files[@]}"; do
    # Re-check time limit before starting a new file
    local hour
    hour=$(date +%H)
    if [[ $hour -lt 1 || $hour -ge 5 ]]; then
        print -P "%F{yellow}⚠ Window closed. Current time is $hour:00. Halting process.%f\n"
        break
    fi

    # Check codec
    local codec
    codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$file" || true)
    
    if [[ "$codec" == "h264" ]]; then
        local filename="${file:t}"
        local dirname="${file:h}"
        local temp_file="$TEMP_DIR/$filename.temp.mkv"
        local final_file="$dirname/${filename:r}.mkv"
        local skip_flag="$dirname/.${filename:r}.skip"
        
        if [[ -f "$skip_flag" ]]; then
            print -P "%F{yellow}⚠ Skipping previously failed file: $filename%f\n"
            continue
        fi
        
        print -P "\n%F{cyan}ℹ Optimizing: $filename%f\n"
        
        # Software decode -> Hardware Encode via VAAPI
        # We use format=nv12,hwupload to upload frames to GPU memory. 
        # qp 24 yields excellent quality for HEVC VAAPI.
        if timeout 30m ffmpeg -v error -stats -y -vaapi_device /dev/dri/renderD128 \
            -i "$file" -map 0 \
            -vf 'format=nv12,hwupload' \
            -c:v hevc_vaapi -qp 24 \
            -c:a copy -c:s copy "$temp_file"; then
            
            # Replace original
            mv "$temp_file" "$final_file"
            if [[ "$file" != "$final_file" ]]; then
                rm -f "$file"
            fi
            print -P "%F{green}✔ Optimized $filename%f\n"
        else
            print -P "%F{red}✖ Failed to optimize $filename. Marking to skip in future.%f\n"
            rm -f "$temp_file"
            touch "$skip_flag"
        fi
    fi
done

# endregion

# region [Cleanup]

print -P "\n%K{green}%F{black} END: Media Optimizer %k%f\n"

# endregion
