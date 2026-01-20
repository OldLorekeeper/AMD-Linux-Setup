#!/bin/zsh
# ------------------------------------------------------------------------------
# 2. Utility. KWin Rule Applicator
# Generates and applies window rules by merging common fragments with device profiles.
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES (Read before editing):
# 1. Formatting: Keep layout compact. No vertical whitespace inside blocks.
# 2. Separators: Use 'Sandwich' headers (# ------) with strict spacing (1 line before).
# 3. Idempotency: Scripts must be safe to re-run. Check state before changes.
# 4. Safety: Use 'setopt ERR_EXIT NO_UNSET PIPE_FAIL'.
# 5. Context: No hardcoded secrets.
# 6. Syntax: Use Zsh native modifiers and tooling
# 8. Documentation: Start section with 'Purpose' comment block (1 line before and after). No meta or inline comments within code.
#
# ------------------------------------------------------------------------------

setopt ERR_EXIT NO_UNSET PIPE_FAIL

# ------------------------------------------------------------------------------
# 1. Configuration & Paths
# ------------------------------------------------------------------------------

# Purpose: Validate input and define resource paths.

PROFILE="$1"
if [[ -z "$PROFILE" ]]; then
    print -P "%F{red}Error: No profile specified. Use 'desktop' or 'laptop'.%f"
    exit 1
fi
SCRIPT_DIR=${0:a:h}
REPO_ROOT=${SCRIPT_DIR:h}
RULES_DIR="$REPO_ROOT/Resources/Kwin"
TEMPLATE="$RULES_DIR/${PROFILE}.rule.template"
COMMON="$RULES_DIR/common.kwinrule.fragment"
GENERATED="$RULES_DIR/${PROFILE}.generated.kwinrule"
CONFIG_FILE="$HOME/.config/kwinrulesrc"

# ------------------------------------------------------------------------------
# 2. Sync Logic
# ------------------------------------------------------------------------------

# Purpose: Generate the final rule file.
# - Extraction: Reads profile-specific window sizes (Small, Tall, etc.) from the template.
# - Injection: Inserts these sizes into the common rule fragment using sed.
# - Assembly: Combines the processed common rules with unique template rules (stripping headers).

print -P "%F{green}--- Generating Rules for $PROFILE ---%f"
SMALL_SIZE=$(grep -E '^# *Small:' "$TEMPLATE" | awk '{print $3}')
TALL_SIZE=$(grep -E '^# *Tall:'  "$TEMPLATE" | awk '{print $3}')
WIDE_SIZE=$(grep -E '^# *Wide:'  "$TEMPLATE" | awk '{print $3}')
BOXY_SIZE=$(grep -E '^# *Boxy:'  "$TEMPLATE" | awk '{print $3}')
sed -E \
    -e "/^\[Start Small\]/a size=$SMALL_SIZE" \
    -e "/^\[Start Tall\]/a size=$TALL_SIZE" \
    -e "/^\[Start Wide\]/a size=$WIDE_SIZE" \
    -e "/^\[Start Boxy\]/a size=$BOXY_SIZE" \
    "$COMMON" > "$GENERATED.tmp"
{
    printf "# SIZES:\n# Small: %s\n# Tall: %s\n# Wide: %s\n# Boxy: %s\n\n" "$SMALL_SIZE" "$TALL_SIZE" "$WIDE_SIZE" "$BOXY_SIZE"
    cat "$GENERATED.tmp"
    grep -vE '^# *SIZES:|^# *Small:|^# *Tall:|^# *Wide:|^# *Boxy:' "$TEMPLATE" | grep -vE '^[[:space:]]*$'
} > "$GENERATED"
rm "$GENERATED.tmp"
print "Generated $GENERATED"

# ------------------------------------------------------------------------------
# 3. Update Logic
# ------------------------------------------------------------------------------

# Purpose: Apply the generated rules to the system.
# - Backup: Saves existing kwinrulesrc.
# - Format: Uses awk to assign sequential section numbers (required by KWin).
# - Reload: Triggers KWin reconfiguration via DBus.

print -P "%F{green}--- Applying Rules to KWin ---%f"
if [[ ! -f "$GENERATED" ]]; then
    print -P "%F{red}Error: Generated file not found.%f"
    exit 1
fi
if [[ -f "$CONFIG_FILE" ]]; then
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    print "Backed up existing config to ${CONFIG_FILE}.bak"
fi
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
if pgrep -x kwin_wayland >/dev/null; then
    DBUS_CMD=""
    for cmd in qdbus-qt6 qdbus6 qdbus; do
        if (( $+commands[$cmd] )); then
            DBUS_CMD=$cmd
            break
        fi
    done
    if [[ -n "$DBUS_CMD" ]]; then
        "$DBUS_CMD" org.kde.KWin /KWin reconfigure || print -P "%F{yellow}Warning: DBus reconfigure failed.%f"
        print -P "%F{green}Success: Rules updated and KWin reconfigured.%f"
    else
        print -P "%F{yellow}Warning: qdbus command not found; rules written but not auto-reloaded.%f"
    fi
else
    print -P "%F{yellow}Warning: kwin_wayland not running. Rules written but not applied.%f"
fi

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------
