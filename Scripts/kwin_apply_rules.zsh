#!/bin/zsh
# ------------------------------------------------------------------------------
# 2. Utility. KWin Rule Applicator
# Generates and applies window rules by merging common fragments with device profiles.
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES:
#
# 1. Safety: `setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB`.
# 2. Syntax: Native Zsh modifiers (e.g. ${VAR:t}).
# 3. Heredocs: Use language ID (e.g. <<ZSH, <<INI), unique IDs for nesting, and quote 'ID' to disable expansion.
# 4. Structure:
#    - Sandwich numbered section separators (# ------) with 1 line padding before.
#    - Purpose comment block (1 line padding) at start of every numbered section summarising code.
#    - No inline/meta comments. Compact vertical layout (minimise blank lines)
#    - Retain frequent context info markers (%F{cyan}) inside dense logic blocks to prevent 'frozen' UI state.
#    - Code wrapped in '# BEGIN' and '# END' markers.
#    - Kate modeline at EOF.
# 5. Idempotency: Re-runnable scripts. Check state before changes.
# 6. UI Hierarchy Print -P
#    - Process marker:          Green Block (%K{green}%F{black}). Used at Start/End.
#    - Section marker:          Blue Block  (%K{blue}%F{black}). Numbered.
#    - Sub-section marker:      Yellow Block (%K{yellow}%F{black}).
#    - Interaction:             Yellow description (%F{yellow}) + minimal `read` prompt.
#    - Context/Status:          Cyan (Info ℹ), Green (Success), Red (Error/Warning).
#    - Marker spacing:          Use `\n...%k%f\n`. Omit top `\n` on consecutive markers.
#
# ------------------------------------------------------------------------------

# BEGIN
setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB
SCRIPT_DIR=${0:a:h}
print -P "\n%K{green}%F{black} STARTING KWIN RULE APPLY %k%f\n"
# END

# ------------------------------------------------------------------------------
# 1. Configuration & Paths
# ------------------------------------------------------------------------------

# Purpose: Validate input and define resource paths.

# BEGIN
print -P "%K{blue}%F{black} 1. CONFIGURATION & PATHS %k%f\n"
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
# END

# ------------------------------------------------------------------------------
# 2. Sync Logic
# ------------------------------------------------------------------------------

# Purpose: Generate the final rule file by merging common fragments with the profile template.

# BEGIN
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
# END

# ------------------------------------------------------------------------------
# 3. Update Logic
# ------------------------------------------------------------------------------

# Purpose: Apply the generated rules to the system and reconfigure KWin.

# BEGIN
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
# END

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------

# BEGIN
print -P "\n%K{green}%F{black} PROCESS COMPLETE %k%f\n"
# END

# kate: hl Zsh; folding-markers on;
