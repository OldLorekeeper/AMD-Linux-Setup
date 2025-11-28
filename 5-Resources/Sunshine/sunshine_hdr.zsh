#!/usr/bin/zsh
# Configuration
MONITOR="DP-2"
STREAM_MODE="9"
DEFAULT_MODE="1"

# ------------------------------------------------------------
case "$1" in
    enable)
        # Set Stream Mode AND Enable HDR simultaneously
        kscreen-doctor output.$MONITOR.mode.$STREAM_MODE output.$MONITOR.hdr.enable
        ;;
    disable)
        # Disable HDR AND Revert to Default Mode simultaneously
        kscreen-doctor output.$MONITOR.hdr.disable output.$MONITOR.mode.$DEFAULT_MODE
        ;;
    *)
        echo "Usage: $0 {enable|disable}"
        exit 1
        ;;
esac
