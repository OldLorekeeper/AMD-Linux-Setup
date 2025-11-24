#!/bin/bash
# Usage: ./sync_kwin_rules.sh [desktop|laptop]

set -e
PROFILE="$1"
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &>/dev/null && pwd )"
RULES_DIR="$SCRIPT_DIR/../5-Resources/Window-Rules"
TEMPLATE="$RULES_DIR/${PROFILE}.rule.template"
COMMON="$RULES_DIR/common.kwinrule.fragment"
GENERATED="$RULES_DIR/${PROFILE}.generated.kwinrule"

# Extract sizes from the immutable template
read SMALL_SIZE <<<"$(grep -E '^# *Small:' "$TEMPLATE" | awk '{print $3}')"
read TALL_SIZE  <<<"$(grep -E '^# *Tall:'  "$TEMPLATE" | awk '{print $3}')"
read WIDE_SIZE  <<<"$(grep -E '^# *Wide:'  "$TEMPLATE" | awk '{print $3}')"
read BOXY_SIZE  <<<"$(grep -E '^# *Boxy:'  "$TEMPLATE" | awk '{print $3}')"

# Insert sizes into common fragment
# UPDATE: Added 'Boxy' size injection
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
  # Strip the size header lines (including Boxy) from the template when copying unique rules
  grep -vE '^# *SIZES:|^# *Small:|^# *Tall:|^# *Wide:|^# *Boxy:' "$TEMPLATE" | grep -vE '^[[:space:]]*$'
} > "$GENERATED"

rm "$GENERATED.tmp"
echo "Generated $GENERATED"
