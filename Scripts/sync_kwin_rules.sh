#!/bin/bash
#
# Usage: ./sync_kwin_rules.sh [desktop|laptop]
# Generates the final .kwinrule file by combining common fragment
# with device-specific size variables (extracted from the file header).
#

set -e

# Define paths relative to this script's location
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
RULES_DIR="$SCRIPT_DIR/../5-Resources/Window-Rules"
FRAGMENT="$RULES_DIR/common.kwinrule.fragment"

PROFILE=$1
DEVICE_FILE="$RULES_DIR/$PROFILE.kwinrule"
TEMP_FILE=$(mktemp)

if [[ ! -f "$FRAGMENT" ]]; then
    echo "Error: Common fragment not found at $FRAGMENT"
    exit 1
fi

if [[ ! -f "$DEVICE_FILE" ]]; then
    echo "Error: Device rule file not found at $DEVICE_FILE"
    exit 1
fi

# 1. Extract size variables from the header of the device file
SMALL_SIZE=$(grep -E '^# Small:' "$DEVICE_FILE" | awk '{print $3}')
TALL_SIZE=$(grep -E '^# Tall:' "$DEVICE_FILE" | awk '{print $3}')
WIDE_SIZE=$(grep -E '^# Wide:' "$DEVICE_FILE" | awk '{print $3}')

if [[ -z "$SMALL_SIZE" || -z "$TALL_SIZE" || -z "$WIDE_SIZE" ]]; then
    echo "Error: Could not extract size variables from $DEVICE_FILE header."
    rm "$TEMP_FILE"
    exit 1
fi

# 2. Process the common fragment, inserting size lines
# Uses sed to look for the section header and append the size= line after it.
sed -E \
    -e '/^\[Start Small\]/a size='$SMALL_SIZE \
    -e '/^\[Start Tall\]/a size='$TALL_SIZE \
    -e '/^\[Start Wide\]/a size='$WIDE_SIZE \
    "$FRAGMENT" > "$TEMP_FILE"

# 3. Append the device-specific unique rules (everything after the header/sizes)
grep -vE '^# SIZES:|^# Small:|^# Tall:|^# Wide:' "$DEVICE_FILE" | grep -vE '^\s*$' >> "$TEMP_FILE"

# 4. Overwrite the device file with the complete, generated content
mv "$TEMP_FILE" "$DEVICE_FILE"

echo "Generated final $DEVICE_FILE."
