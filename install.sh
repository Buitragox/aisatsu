#!/bin/bash

# Exports the Godot project and installs to /usr/local/bin/.
# Automatically downloads Godot export templates if they are missing.
#
# Usage: ./install.sh [debug|release]
#   release  Export and install release template (default)
#   debug    Export and install debug template

set -e

# ANSI color codes
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

TARGET="release"

for arg in "$@"; do
    case "$arg" in
        release|debug)
            TARGET="$arg"
            ;;
        *)
            echo "Usage: $0 [release|debug]"
            echo "  release      Export and install release template (default)"
            echo "  debug        Install debug template "
            exit 1
            ;;
    esac
done

if ! command -v godot &> /dev/null; then
    echo -e "${RED}Error: 'godot' is required but was not found.${NC}"
    exit 1
fi

echo -e "${CYAN}Checking for Godot export templates...${NC}"
GODOT_VERSION=$(godot --version | head -n1 | grep -oE '^[0-9]+\.[0-9]+(\.[0-9]+)?\.[a-z]+')
TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/$GODOT_VERSION"

if [ ! -f "$TEMPLATE_DIR/linux_debug.x86_64" ] || [ ! -f "$TEMPLATE_DIR/linux_release.x86_64" ]; then
    if ! command -v unzip &> /dev/null; then
        echo "${RED}Error: 'unzip' is required to extract export templates but was not found.${NC}"
        exit 1
    fi
    # Convert version format from "x.y.z.stable" to "x.y.z-stable" for the download URL
    DOWNLOAD_VERSION=$(echo "$GODOT_VERSION" | sed 's/\.\([a-z]*\)$/-\1/')
    TEMPLATE_URL="https://github.com/godotengine/godot/releases/download/$DOWNLOAD_VERSION/Godot_v${DOWNLOAD_VERSION}_export_templates.tpz"

    echo -e "${CYAN}Export templates not found, downloading from:${NC}"
    echo "  $TEMPLATE_URL"

    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT

    curl -L -o "$TEMP_DIR/templates.tpz" "$TEMPLATE_URL"
    mkdir -p "$TEMPLATE_DIR"
    unzip -o "$TEMP_DIR/templates.tpz" -d "$TEMP_DIR/extracted"
    cp -r "$TEMP_DIR/extracted/templates/"* "$TEMPLATE_DIR/"

    echo -e "${CYAN}Export templates installed to $TEMPLATE_DIR${NC}"
else
    echo -e "${CYAN}Export templates found at $TEMPLATE_DIR${NC}"
fi

echo -e "${CYAN}Exporting Godot project...${NC}"
if [ "$TARGET" = "debug" ]; then
    godot --headless --export-debug "aisatsu"
else
    godot --headless --export-release "aisatsu"
fi

echo -e "${CYAN}Installing binary to /usr/local/bin/...${NC}"
sudo cp bin/aisatsu.x86_64 /usr/local/bin/

echo -e "${CYAN}Installation complete!${NC}"
