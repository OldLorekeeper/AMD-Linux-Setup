#!/bin/bash
#
# Usage: ./sync_kwin_rules.sh [desktop|laptop]
# Generates the final .kwinrule file by combining common fragment
# with device-specific size variables (extracted from the file header).
#
# FIX: Uses command grouping to ensure all file sections (Header, Fragment Rules, Unique Rules)
# are written correctly, resolving the issue where only the header was saved.

set -e

# Define paths relative to this script's location
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
RULES_DIR="$SCRIPT_DIR/../5-Resources/Window-Rules"
FRAGMENT="$RULES_DIR/common.kwinrule.fragment"

PROFILE=$1
DEVICE_FILE="$RULES_DIR/$PROFILE.kwinrule"
TEMP_FILE=$(mktemp)

# Validation
if [[ -z "$PROFILE" ]]; then echo "Error: No profile specified."; exit 1; fi
if [[ ! -f "$FRAGMENT" ]]; then echo "Error: Common fragment not found."; exit 1; fi
if [[ ! -f "$DEVICE_FILE" ]]; then echo "Error: Device rule file not found."; exit 1; fi

echo "--- Generating $DEVICE_FILE, preserving static header and sizes... ---"

# --- 1. Extract Permanent Static Header Content ---
# Captures all lines before the first rule block ([...]), which includes the SIZES block.
STATIC_HEADER_CONTENT=$(awk '/^\[/ {exit} {print}' "$DEVICE_FILE")

# --- 2. Extract Unique Rules Content ---
# Captures all content after the major separator (e.g., # ---), which holds unique device rules.
UNIQUE_RULES_CONTENT=$(awk '/^# \-\-\-\s*$/ {found=1; next} {if (found) print}' "$DEVICE_FILE" | grep -vE '^\s*$')

# --- 3. Extract Size Variables (from the extracted header content) ---
SMALL_SIZE=$(echo "$STATIC_HEADER_CONTENT" | grep -E '^# Small:' | awk '{print $3}')
TALL_SIZE=$(echo "$STATIC_HEADER_CONTENT" | grep -E '^# Tall:' | awk '{print $3}')
WIDE_SIZE=$(echo "$STATIC_HEADER_CONTENT" | grep -E '^# Wide:' | awk '{print $3}')
BOXY_SIZE=$(echo "$STATIC_HEADER_CONTENT" | grep -E '^# Boxy:' | awk '{print $3}')

if [[ -z "$SMALL_SIZE" || -z "$TALL_SIZE" || -z "$WIDE_SIZE" ]]; then
    echo "Error: Could not extract all required size variables from $DEVICE_FILE header."
    rm "$TEMP_FILE"
    exit 1
fi

# --- 4. Generate Merged Rule Block (Using Command Grouping) ---
# All output is reliably directed to the temporary file in one operation.
{
    # a) Print the Permanent Static Header Content (SIZES block, etc.)
    echo "$STATIC_HEADER_CONTENT"

    # b) Print the Merged Rule Logic (fragment + injected sizes)
    # The sed commands inject the size= line after finding the rule name in the fragment.
    sed -E \
        -e '/^\[Start Small\]/a size='$SMALL_SIZE \
        -e '/^\[Start Tall\]/a size='$TALL_SIZE \
        -e '/^\[Start Wide\]/a size='$WIDE_SIZE \
        -e '/^\[Start Boxy\]/a size='$BOXY_SIZE \
        "$FRAGMENT"

    # c) Append Unique Rules (if any)
    if [[ -n "$UNIQUE_RULES_CONTENT" ]]; then
        echo "" # Add separation
        echo "# -------------------" # Re-insert the major divider
        echo "$UNIQUE_RULES_CONTENT"
    fi

} > "$TEMP_FILE"

# --- 5. Overwrite Device File and Cleanup ---
mv "$TEMP_FILE" "$DEVICE_FILE"

echo "Generated final $DEVICE_FILE. KWin rules ready to be applied."
