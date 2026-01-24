#!/bin/zsh
# ------------------------------------------------------------------------------
# 9. Utility. KWin Sync & Apply Manager
# Syncs KWin rules with repository and applies them to the system.
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES:
#
# 1. Safety: `setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB`.
# 2. Syntax: Native Zsh modifiers (e.g. ${VAR:t}).
# 3. Heredocs: Use language ID (e.g. <<ZSH, <<INI), unique IDs for nesting, and quote 'ID' to disable expansion.
# 4. Structure:
#    a) Sandwich numbered section separators (# ------) with 1 line padding before.
#    b) Purpose comment block (1 line padding) at start of every numbered section summarising code.
#    c) No inline/meta comments. Compact vertical layout (minimise blank lines)
#    d) Retain frequent context info markers (%F{cyan}) inside dense logic blocks to prevent 'frozen' UI state.
#    e) Code wrapped in '# BEGIN' and '# END' markers.
#    f) Kate modeline at EOF.
# 5. Idempotency: Re-runnable scripts. Check state before changes.
# 6. UI Hierarchy Print -P
#    a) Process marker:          Green Block (%K{green}%F{black}). Used at Start/End.
#    b) Section marker:          Blue Block  (%K{blue}%F{black}). Numbered.
#    c) Sub-section marker:      Yellow Block (%K{yellow}%F{black}).
#    d) Interaction:             Yellow description (%F{yellow}) + minimal `read` prompt.
#    e) Context/Status:          Cyan (Info ℹ), Green (Success), Red (Error/Warning).
#    f) Marker spacing:          i)  Use `\n...%k%f\n`.
#                                ii) Omit top `\n` on consecutive markers.
#                                ii) Context (Cyan) markers MUST include a trailing `\n`.
#
# ------------------------------------------------------------------------------

# BEGIN
setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB
SCRIPT_DIR=${0:a:h}
REPO_ROOT=${SCRIPT_DIR:h}
print -P "\n%K{green}%F{black} KWIN SYNC & APPLY %k%f\n"
# END

# ------------------------------------------------------------------------------
# 1. Configuration & Paths
# ------------------------------------------------------------------------------

# Purpose: Validate profile target and define resource paths.

# BEGIN
print -P "%K{blue}%F{black} 1. CONFIGURATION & PATHS %k%f\n"
PROFILE="${1:-${SYS_PROFILE:-}}"
if [[ -z "$PROFILE" ]]; then
    print -P "%F{red}Error: No profile specified and SYS_PROFILE not set.%f"
    exit 1
fi
RULES_DIR="$REPO_ROOT/Resources/Kwin"
TEMPLATE="$RULES_DIR/${PROFILE}.rule.template"
COMMON="$RULES_DIR/common.kwinrule.fragment"
GENERATED="$RULES_DIR/${PROFILE}.generated.kwinrule"
CONFIG_FILE="$HOME/.config/kwinrulesrc"
print -P "Profile:      %F{green}$PROFILE%f"
print -P "Template:     %F{green}${TEMPLATE:t}%f"
print -P "Root:         %F{cyan}$REPO_ROOT%f"
# END

# ------------------------------------------------------------------------------
# 2. Fragment Check
# ------------------------------------------------------------------------------

# Purpose: Check for local changes in the common rule fragment and commit them if found.

# BEGIN
print -P "\n%K{blue}%F{black} 2. FRAGMENT CHECK %k%f\n"
FRAGMENT="Resources/Kwin/common.kwinrule.fragment"
if git -C "$REPO_ROOT" status --porcelain "$FRAGMENT" | grep -q '^ M'; then
    print -P "%F{yellow}Changes detected in common fragment. Committing...%f"
    git -C "$REPO_ROOT" add "$FRAGMENT"
    git -C "$REPO_ROOT" commit -m "AUTOSYNC: KWin common fragment update from ${HOST}"
    print -P "Status: %F{green}Committed changes%f"
else
    print -P "Status: %F{green}No changes in common fragment%f"
fi
# END

# ------------------------------------------------------------------------------
# 3. Repository Update
# ------------------------------------------------------------------------------

# Purpose: Pull the latest changes from the remote repository.

# BEGIN
print -P "\n%K{blue}%F{black} 3. REPOSITORY UPDATE %k%f\n"
print -P "%F{cyan}ℹ Pulling latest changes...%f\n"
if git -C "$REPO_ROOT" pull; then
    print -P "Status: %F{green}Pull Successful%f"
else
    print -P "%F{red}Error: Git pull failed.%f"
    exit 1
fi
# END

# ------------------------------------------------------------------------------
# 4. Generate Rules
# ------------------------------------------------------------------------------

# Purpose: Generate the final rule file by merging common fragments with the profile template.

# BEGIN
print -P "\n%K{blue}%F{black} 4. GENERATE RULES %k%f\n"
print -P "%F{cyan}ℹ Parsing templates and merging fragments...%f\n"
SMALL_SIZE=$(grep -E '^# *Small:' "$TEMPLATE" | awk '{print $3}')
TALL_SIZE=$(grep -E '^# *Tall:'  "$TEMPLATE" | awk '{print $3}')
WIDE_SIZE=$(grep -E '^# *Wide:'  "$TEMPLATE" | awk '{print $3}')
BOXY_SIZE=$(grep -E '^# *Boxy:'  "$TEMPLATE" | awk '{print $3}')
sed -E \
    -e "/^\\[Start Small\\]/a size=$SMALL_SIZE" \
    -e "/^\\[Start Tall\\]/a size=$TALL_SIZE" \
    -e "/^\\[Start Wide\\]/a size=$WIDE_SIZE" \
    -e "/^\\[Start Boxy\\]/a size=$BOXY_SIZE" \
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
# 5. Apply Configuration
# ------------------------------------------------------------------------------

# Purpose: Apply the generated rules to the system.

# BEGIN
print -P "\n%K{blue}%F{black} 5. APPLY CONFIGURATION %k%f\n"
if [[ ! -f "$GENERATED" ]]; then
    print -P "%F{red}Error: Generated file not found.%f"
    exit 1
fi
if [[ -f "$CONFIG_FILE" ]]; then
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    print -P "%F{cyan}ℹ Backed up existing config to ${CONFIG_FILE:t}.bak%f\n"
fi
print -P "%F{cyan}ℹ Writing new rules to ${CONFIG_FILE:t}...%f\n"
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
# END

# ------------------------------------------------------------------------------
# 6. Reload KWin
# ------------------------------------------------------------------------------

# Purpose: Reload KWin configuration using DBus.

# BEGIN
print -P "\n%K{blue}%F{black} 6. RELOAD KWIN %k%f\n"
print -P "%F{cyan}ℹ Triggering KWin reconfigure...%f\n"
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