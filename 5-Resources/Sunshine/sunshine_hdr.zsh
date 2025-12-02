#!/bin/zsh
# ------------------------------------------------------------------------------
# Sunshine HDR & Resolution Switcher
# ------------------------------------------------------------------------------

setopt ERR_EXIT
setopt NO_UNSET
setopt PIPE_FAIL

# Configuration
MONITOR="DP-2"
STREAM_MODE="7"
DEFAULT_MODE="1"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

case "$1" in
    enable)
        # Set Stream Mode, Enable HDR and Scale to 120%
        kscreen-doctor output.$MONITOR.mode.$STREAM_MODE output.$MONITOR.hdr.enable output.$MONITOR.scale.1.2
        ;;
    disable)
        # Disable HDR, Revert Mode and Scale to 100%
        kscreen-doctor output.$MONITOR.hdr.disable output.$MONITOR.mode.$DEFAULT_MODE output.$MONITOR.scale.1.0
        ;;
    *)
        print "Usage: $0 {enable|disable}"
        exit 1
        ;;
esac
