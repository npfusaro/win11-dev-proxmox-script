#!/bin/bash

GITHUB_RAW_URL="https://raw.githubusercontent.com/npfusaro/win11-dev-proxmox-script/main"

SCRIPT_NAME="Proxmox script.sh"
XML_NAME="autounattend.xml"

# --- Colors ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color


echo -e "${GREEN}Starting Windows 11 Dev Enviorment VM Installer...${NC}"

# 1. Install Dependencies
echo -e "${YELLOW}Checking dependencies...${NC}"
if ! command -v genisoimage &> /dev/null; then
    echo "Installing genisoimage..."
    apt-get update && apt-get install -y genisoimage
else
    echo "genisoimage is already installed."
fi

# 2. Download Files
echo -e "${YELLOW}Downloading scripts from GitHub...${NC}"

# Download Main Script
wget -q "${GITHUB_RAW_URL}/${SCRIPT_NAME}" -O "$SCRIPT_NAME"
if [ $? -ne 0 ]; then
    echo -e "${RED}Error downloading $SCRIPT_NAME. Check your URL.${NC}"
    exit 1
fi

# Download Answer File
wget -q "${GITHUB_RAW_URL}/${XML_NAME}" -O "$XML_NAME"
if [ $? -ne 0 ]; then
    echo -e "${RED}Error downloading $XML_NAME. Check your URL.${NC}"
    exit 1
fi


# Fix line endings (convert CRLF to LF) in case file was saved on Windows
sed -i 's/\r$//' "$SCRIPT_NAME"

chmod +x "$SCRIPT_NAME" || {
    echo -e "${RED}Failed to make script executable${NC}"
    exit 1
}

# 3. Run the Script
echo -e "${GREEN}Files downloaded successfully.${NC}"
echo -e "${YELLOW}Launching VM Creation Script...${NC}"

# Pass all arguments received by this installer to the main script
bash "$SCRIPT_NAME" "$@"

