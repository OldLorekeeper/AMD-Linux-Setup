#!/bin/bash
# ------------------------------------------------------------------------------
# [Script Title]
# [Brief description of what this script does]
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES (Read before editing):
# 1. Formatting: Keep layout compact. Remove vertical whitespace within logical blocks.
# 2. Separators: Use double dotted lines (# ------) to separate major stages.
# 3. Safety: Always use 'set -e'. Verify conditions before destructive actions.
# 4. Tooling: Use 'echo -e' for colored output.
#
# ------------------------------------------------------------------------------

set -e

# Visual Formatting
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Path Resolution
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

echo -e "${GREEN}--- Starting [Process Name] ---${NC}"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 1. Prerequisite Checks
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}Error: Run this as your normal user, NOT root/sudo.${NC}"
   exit 1
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 2. Main Logic
echo -e "${GREEN}--- Section Title ---${NC}"

# Example: Idempotent Check
if ! grep -q "Pattern" /path/to/config; then
    echo "Applying configuration..."
    # Command here
else
    echo -e "${YELLOW}Configuration already present. Skipping.${NC}"
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

echo -e "${GREEN}--- [Process Name] Complete ---${NC}"
