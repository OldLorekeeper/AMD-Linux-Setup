#!/bin/zsh
# ------------------------------------------------------------------------------
# KWin Rule Applicator
# Generates and applies window rules by merging common fragments with device profiles.
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

# Load Colours
autoload -Uz colors && colors
GREEN="${fg[green]}"
YELLOW="${fg[yellow]}"
RED="${fg[red]}"
NC="${reset_color}"

# 1. Configuration & Paths
PROFILE="$1"
if [[ -z "$PROFILE" ]]; then
    print "${RED}Error: No profile specified. Use 'desktop' or 'laptop'.${NC}"
    exit 1
fi

SCRIPT_DIR=${0:a:h}
REPO_ROOT=${SCRIPT_DIR:h}
RULES_DIR="$REPO_ROOT/5-Resources/Window-Rules"
TEMPLATE="$RULES_DIR/${PROFILE}.rule.template"
COMMON="$RULES_DIR/common.kwinrule.fragment"
GENERATED="$RULES_DIR/${PROFILE}.generated.kwinrule"
CONFIG_FILE="$HOME/.config/kwinrulesrc"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 2. Sync Logic: Extract Sizes and Generate File
print "${GREEN}--- Generating Rules for $PROFILE ---${NC}"

# Extract sizes directly into variables
SMALL_SIZE=$(grep -E '^# *Small:' "$TEMPLATE" | awk '{print $3}')
TALL_SIZE=$(grep -E '^# *Tall:'  "$TEMPLATE" | awk '{print $3}')
WIDE_SIZE=$(grep -E '^# *Wide:'  "$TEMPLATE" | awk '{print $3}')
BOXY_SIZE=$(grep -E '^# *Boxy:'  "$TEMPLATE" | awk '{print $3}')

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
print "Generated $GENERATED"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 3. Update Logic: Apply to KWin
print "${GREEN}--- Applying Rules to KWin ---${NC}"

if [[ ! -f "$GENERATED" ]]; then
    print "${RED}Error: Generated file not found.${NC}"
    exit 1
fi

# Back up the existing KWin rules configuration
if [[ -f "$CONFIG_FILE" ]]; then
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    print "Backed up existing config to ${CONFIG_FILE}.bak"
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

print "Wrote numbered rules to $CONFIG_FILE"

# Reload KWin (Wayland)
if pgrep -x kwin_wayland >/dev/null; then
    # Find first available qdbus binary
    DBUS_CMD=""
    for cmd in qdbus-qt6 qdbus6 qdbus; do
        if (( $+commands[$cmd] )); then
            DBUS_CMD=$cmd
            break
        fi
    done

    if [[ -n "$DBUS_CMD" ]]; then
        "$DBUS_CMD" org.kde.KWin /KWin reconfigure || print "${YELLOW}Warning: DBus reconfigure failed.${NC}"
        print "${GREEN}Success: Rules updated and KWin reconfigured.${NC}"
    else
        print "${YELLOW}Warning: qdbus command not found; rules written but not auto-reloaded.${NC}"
    fi
else
    print "${YELLOW}Warning: kwin_wayland not running. Rules written but not applied.${NC}"
fi
