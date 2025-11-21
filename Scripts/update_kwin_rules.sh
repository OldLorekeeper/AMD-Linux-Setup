#!/bin/bash
# Usage: ./update_kwin_rules.sh [desktop|laptop]
set -e

# Paths
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
RULES_DIR="$REPO_ROOT/5-Resources/Window-Rules"
CONFIG_FILE="$HOME/.config/kwinrulesrc"
PROFILE=$1

# Validation
if [[ -z "$PROFILE" ]]; then
    echo "Error: No profile specified."
    exit 1
fi

SOURCE_FILE="$RULES_DIR/$PROFILE.kwinrule"
if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "Error: Source file not found at $SOURCE_FILE"
    exit 1
fi

# Backup
[[ -f "$CONFIG_FILE" ]] && cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

# Convert Human-Readable Headers to Numbered Sections
awk '
    BEGIN { count=0 }
    /^\[/ { count++; print "[" count "]"; next }
    { print }
    END {
        print ""; print "[General]"; print "count=" count;
        printf "rules="; for (i=1; i<=count; i++) { if (i>1) printf ","; printf i }; print ""
    }
' "$SOURCE_FILE" > "$CONFIG_FILE"

# Reload KWin
if pgrep -x "kwin_wayland" > /dev/null; then
    qdbus6 org.kde.KWin /KWin reconfigure
    echo "Rules updated and KWin reloaded for $PROFILE."
else
    echo "Rules updated (KWin not running)."
fi
