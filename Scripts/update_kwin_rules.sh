#!/bin/bash
# update_kwin_rules.sh – Apply KWin window rules for a given profile (Wayland).
# Usage: ./update_kwin_rules.sh [desktop|laptop]

set -e

PROFILE="$1"
if [[ -z "$PROFILE" ]]; then
  echo "Error: No profile specified. Use 'desktop' or 'laptop'."
  exit 1
fi

# Determine script and repository locations.
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &>/dev/null && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
RULES_DIR="$REPO_ROOT/5-Resources/Window-Rules"

# We expect a generated rules file produced by sync_kwin_rules.sh, e.g. desktop.generated.kwinrule.
SOURCE_FILE="$RULES_DIR/${PROFILE}.generated.kwinrule"
CONFIG_FILE="$HOME/.config/kwinrulesrc"

if [[ ! -f "$SOURCE_FILE" ]]; then
  echo "Error: $SOURCE_FILE not found. Run sync_kwin_rules.sh first."
  exit 1
fi

# Back up the existing KWin rules configuration if present.
if [[ -f "$CONFIG_FILE" ]]; then
  cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
  echo "Existing $CONFIG_FILE backed up to ${CONFIG_FILE}.bak"
fi

# Convert the human-readable rule file into numbered sections for kwinrulesrc.
# The AWK script:
#   - increments a counter each time a line starting with '[' is seen (a new rule).
#   - replaces the bracketed header with [1], [2], … based on the counter.
#   - appends a [General] section at the end with count and rules=1,2,... .
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
' "$SOURCE_FILE" > "$CONFIG_FILE"

echo "Wrote numbered KWin rules to $CONFIG_FILE"

# Reload KWin to apply the rules if KWin (Wayland) is running.
if pgrep -x kwin_wayland >/dev/null; then
  # Find a qdbus command in the PATH; fall back in case multiple names exist.
  DBUS_CMD="$(command -v qdbus-qt6 || command -v qdbus6 || command -v qdbus)"
  if [[ -n "$DBUS_CMD" ]]; then
    "$DBUS_CMD" org.kde.KWin /KWin reconfigure || \
      echo "Warning: DBus reconfigure call failed. You may need to log out and back in."
    echo "Rules updated and KWin reconfigured for $PROFILE."
  else
    echo "Warning: qdbus command not found; unable to signal KWin to reload rules."
  fi
else
  echo "Warning: kwin_wayland is not running. Rules written but not applied."
fi
