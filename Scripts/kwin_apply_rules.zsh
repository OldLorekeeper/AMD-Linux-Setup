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
# 6. Syntax: Use Zsh native modifiers and tooling.
# 7. Documentation: Start section with 'Purpose' comment block (1 line before and after). No meta or inline comments within code.
# 8. UI & Theming:
#    - Headers: Blue (%K{blue}%F{black}) for sections, Yellow (%K{yellow}%F{black}) for sub-sections.
#    - Spacing: One empty line before and after headers. Use embedded \n to save lines.
#      * Exception: If a header follows another header immediately, omit the leading \n to avoid double gaps.
#    - Inputs: Yellow description line (%F{yellow}) followed by minimal prompt (read "VAR?Prompt: ").
#    - Context: Cyan (%F{cyan}) for info/metadata (prefixed with ℹ).
#    - Status: Green (%F{green}) for success/loaded, Red (%F{red}) for errors/warnings.
#    - Silence: Do not repeat/confirm manual user input. Only print confirmation (%F{green}) if the value was pre-loaded from secrets.
#
# ------------------------------------------------------------------------------

setopt ERR_EXIT NO_UNSET PIPE_FAIL

SCRIPT_DIR=${0:a:h}

print -P "\n%K{green}%F{black} STARTING KWIN RULE APPLY %k%f\n"

# ------------------------------------------------------------------------------
# 1. Configuration & Paths
# ------------------------------------------------------------------------------

# Purpose: Validate input and define resource paths.

print -P "\n%K{blue}%F{black} 1. CONFIGURATION & PATHS %k%f\n"
PROFILE="$1"
if [[ -z "$PROFILE" ]]; then
    print -P "%F{red}Error: No profile specified. Use 'desktop' or 'laptop'.%f"
    exit 1
fi

REPO_ROOT=${SCRIPT_DIR:h}
RULES_DIR="$REPO_ROOT/Resources/Kwin"
TEMPLATE="$RULES_DIR/${PROFILE}.rule.template"
COMMON="$RULES_DIR/common.kwinrule.fragment"
GENERATED="$RULES_DIR/${PROFILE}.generated.kwinrule"
CONFIG_FILE="$HOME/.config/kwinrulesrc"

print -P "Profile: %F{green}$PROFILE%f"
print -P "Template: %F{green}${TEMPLATE:t}%f"

# ------------------------------------------------------------------------------
# 2. Sync Logic
# ------------------------------------------------------------------------------

# Purpose: Generate the final rule file by merging common fragments with the profile template.

print -P "\n%K{blue}%F{black} 2. SYNC LOGIC %k%f\n"
print -P "%K{yellow}%F{black} GENERATING RULES %k%f\n"

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
print -P "Status: %F{green}Generated $GENERATED%f"

# ------------------------------------------------------------------------------
# 3. Update Logic
# ------------------------------------------------------------------------------

# Purpose: Apply the generated rules to the system and reconfigure KWin.

print -P "\n%K{blue}%F{black} 3. UPDATE LOGIC %k%f\n"
print -P "%K{yellow}%F{black} APPLYING CONFIGURATION %k%f\n"

if [[ ! -f "$GENERATED" ]]; then
    print -P "%F{red}Error: Generated file not found.%f"
    exit 1
fi
if [[ -f "$CONFIG_FILE" ]]; then
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    print -P "%F{cyan}ℹ Backed up existing config to ${CONFIG_FILE:t}.bak%f"
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
print -P "Write: %F{green}Numbered rules written to $CONFIG_FILE%f"

print -P "\n%K{yellow}%F{black} RELOADING KWIN %k%f\n"
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
        print -P "Status: %F{green}Success (KWin reconfigured)%f"
    else
        print -P "%F{yellow}Warning: qdbus command not found; rules written but not auto-reloaded.%f"
    fi
else
    print -P "%F{yellow}Warning: kwin_wayland not running. Rules written but not applied.%f"
fi

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------

print -P "\n%K{green}%F{black} PROCESS COMPLETE %k%f\n"
