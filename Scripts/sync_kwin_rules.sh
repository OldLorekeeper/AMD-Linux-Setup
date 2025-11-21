#!/bin/bash
#
# Usage: ./sync_kwin_rules.sh [desktop|laptop]
# Generates the final .kwinrule file by combining common fragment
# with device-specific size variables (extracted from the file header).
#
# FIX: Ensures the static header (SIZES block) and unique rules are preserved.

set -e

# Define paths relative to this script's location
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
RULES_DIR="$SCRIPT_DIR/../5-Resources/Window-Rules"
FRAGMENT="$RULES_DIR/common.kwinrule.fragment"

PROFILE=$1
DEVICE_FILE="$RULES_DIR/$PROFILE.kwinrule"
TEMP_RULE_BLOCK=$(mktemp)

# Validation
if [[ -z "$PROFILE" ]]; then
    echo "Error: No profile specified."
    exit 1
fi
if [[ ! -f "$FRAGMENT" ]]; then
    echo "Error: Common fragment not found at $FRAGMENT"
    exit 1
fi
if [[ ! -f "$DEVICE_FILE" ]]; then
    echo "Error: Device rule file not found at $DEVICE_FILE"
    exit 1
fi

echo "--- Generating $DEVICE_FILE, preserving static header and sizes... ---"

# --- 1. Extract Permanent Static Content ---
# Capture all content before the first rule definition ([...])
STATIC_HEADER=$(awk '/^\[/ {exit} {print}' "$DEVICE_FILE" | grep -vE '^\s*$')
# Capture the unique rules (everything after the divider)
UNIQUE_RULES=$(awk '/^# ---$/ {found_divider=1; next} {if (found_divider) print}' "$DEVICE_FILE" | grep -vE '^\s*$')

# --- 2. Extract Size Variables (for injection) ---
SMALL_SIZE=$(echo "$STATIC_HEADER" | grep -E '^# Small:' | awk '{print $3}')
TALL_SIZE=$(echo "$STATIC_HEADER" | grep -E '^# Tall:' | awk '{print $3}')
WIDE_SIZE=$(echo "$STATIC_HEADER" | grep -E '^# Wide:' | awk '{print $3}')
BOXY_SIZE=$(echo "$STATIC_HEADER" | grep -E '^# Boxy:' | awk '{print $3}')


# --- 3. Generate Merged Rule Block from Fragment (into TEMP_RULE_BLOCK) ---
{
    # a) Print the Permanent Static Header (SIZES block, divider, etc.)
    echo "$STATIC_HEADER"
    echo ""

    # b) Print the Merged Rule Logic (fragment + injected sizes)
    # Note: If a size variable is empty (e.g., no Boxy), the sed command still works.
    sed -E \
        -e '/^\[Start Small\]/a size='$SMALL_SIZE \
        -e '/^\[Start Tall\]/a size='$TALL_SIZE \
        -e '/^\[Start Wide\]/a size='$WIDE_SIZE \
        -e '/^\[Start Boxy\]/a size='$BOXY_SIZE \
        "$FRAGMENT"

    # c) Append Unique Rules (if any)
    if [[ -n "$UNIQUE_RULES" ]]; then
        echo ""
        echo "# -------------------" # Re-insert the divider
        echo "$UNIQUE_RULES"
    fi
} > "$TEMP_RULE_BLOCK"

# --- 4. Overwrite Device File and Cleanup ---
mv "$TEMP_RULE_BLOCK" "$DEVICE_FILE"
rm -f "$TEMP_RULE_BLOCK"

echo "Generated final $DEVICE_FILE. KWin rules ready to be applied."
