#!/bin/bash
# apply_kwin_rules.sh – Syncs templates and applies KWin rules in one step.
# Usage: ./apply_kwin_rules.sh [desktop|laptop]

set -e

PROFILE="$1"
if [[ -z "$PROFILE" ]]; then
  echo "Error: No profile specified. Use 'desktop' or 'laptop'."
  exit 1
fi

# 1. Define Paths
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &>/dev/null && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
RULES_DIR="$REPO_ROOT/5-Resources/Window-Rules"
TEMPLATE="$RULES_DIR/${PROFILE}.rule.template"
COMMON="$RULES_DIR/common.kwinrule.fragment"
GENERATED="$RULES_DIR/${PROFILE}.generated.kwinrule"
CONFIG_FILE="$HOME/.config/kwinrulesrc"

# 2. Sync Logic: Extract Sizes and Generate File
echo "--- Generating Rules for $PROFILE ---"

# Extract sizes from the immutable template
read SMALL_SIZE <<<"$(grep -E '^# *Small:' "$TEMPLATE" | awk '{print $3}')"
read TALL_SIZE  <<<"$(grep -E '^# *Tall:'  "$TEMPLATE" | awk '{print $3}')"
read WIDE_SIZE  <<<"$(grep -E '^# *Wide:'  "$TEMPLATE" | awk '{print $3}')"
read BOXY_SIZE  <<<"$(grep -E '^# *Boxy:'  "$TEMPLATE" | awk '{print $3}')"

# Insert sizes into common fragment
sed -E \
  -e "/^\[Start Small\]/a size=$SMALL_SIZE" \
  -e "/^\[Start Tall\]/a size=$TALL_SIZE" \
  -e "/^\[Start Wide\]/a size=$WIDE_SIZE" \
  -e "/^\[Start Boxy\]/a size=$BOXY_SIZE" \
  "$COMMON" > "$GENERATED.tmp"

# Prepend header back to the generated file and append unique rules
{
  printf "# SIZES:\n# Small: %s\n# Tall: %s\n# Wide: %s\n# Boxy: %s\n\n" "$SMALL_SIZE" "$TALL_SIZE" "$WIDE_SIZE" "$BOXY_SIZE"
  cat "$GENERATED.tmp"
  # Strip the size header lines from the template when copying unique rules
  grep -vE '^# *SIZES:|^# *Small:|^# *Tall:|^# *Wide:|^# *Boxy:' "$TEMPLATE" | grep -vE '^[[:space:]]*$'
} > "$GENERATED"

rm "$GENERATED.tmp"
echo "Generated $GENERATED"

# 3. Update Logic: Apply to KWin
echo "--- Applying Rules to KWin ---"

if [[ ! -f "$GENERATED" ]]; then
  echo "Error: Generated file not found."
  exit 1
fi

# Back up the existing KWin rules configuration
if [[ -f "$CONFIG_FILE" ]]; then
  cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
  echo "Backed up existing config to ${CONFIG_FILE}.bak"
fi

# Convert to kwinrulesrc format (Numbered Sections)
awk '
  BEGIN { count = 0 }
  /^\[/ {
    count++;
    print "[" count "]";
    next
  }
  { print }
  END {
    print "";
    print "[General]";
    print "count=" count;
    printf "rules=";
    for (i = 1; i <= count; i++) {
      if (i > 1) printf ",";
      printf i;
    }
    print ""
  }
' "$GENERATED" > "$CONFIG_FILE"

echo "Wrote numbered rules to $CONFIG_FILE"

# Reload KWin (Wayland)
if pgrep -x kwin_wayland >/dev/null; then
  DBUS_CMD="$(command -v qdbus-qt6 || command -v qdbus6 || command -v qdbus)"
  if [[ -n "$DBUS_CMD" ]]; then
    "$DBUS_CMD" org.kde.KWin /KWin reconfigure || echo "Warning: DBus reconfigure failed."
    echo "Success: Rules updated and KWin reconfigured."
  else
    echo "Warning: qdbus command not found; rules written but not auto-reloaded."
  fi
else
  echo "Warning: kwin_wayland not running. Rules written but not applied."
fi
