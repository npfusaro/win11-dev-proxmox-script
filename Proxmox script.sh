#!/bin/bash

# --- Default Configuration ---
VMID="1022"
VM_NAME="win11-ide"
VM_MEMORY="16384"       # 16GB for VS2022 + AI
VM_CORES="6"            # 6 Cores for compilation
VM_SOCKET="1"
ADMIN_PASSWORD="Password123!" # Default Password (Change this!)

# Parse command line arguments
while getopts "i:n:m:c:p:h" opt; do
  case $opt in
    i) VMID="$OPTARG" ;;
    n) VM_NAME="$OPTARG" ;;
    m) VM_MEMORY="$OPTARG" ;;
    c) VM_CORES="$OPTARG" ;;
    p) ADMIN_PASSWORD="$OPTARG" ;;
    h) echo "Usage: $0 [-i VMID] [-n NAME] [-m MEMORY] [-c CORES] [-p PASSWORD]" ; exit 0 ;;
    *) echo "Invalid option: -$OPTARG" >&2 ; exit 1 ;;
  esac
done

# PROXMOX STORAGE IDs (The name of the storage in Datacenter -> Storage)
DISK_STORAGE="local-lvm"      # Where the VM disk goes
ISO_STORAGE_ID="nfs"          # The Proxmox Storage ID for ISOs

# FILESYSTEM PATHS (For verification checks)
# Ensure this path matches where ISO_STORAGE_ID points to
ISO_PATH_ROOT="/mnt/pve/nfs/template/iso" 

# FILE NAMES
VIRTIO_ISO="virtio-win-0.1.240.iso"
OEM_ISO="win11-unattend-${VMID}.iso" # Generated ISO name
ANSWER_FILE="autounattend.xml"

DISK_SIZE="130G"
OS_TYPE="win11"

# --- Cleanup Trap ---
# Remove generated ISO if script fails to prevent orphaned files
cleanup() {
    if [ -f "$ISO_PATH_ROOT/$OEM_ISO" ]; then
        echo "Cleaning up generated ISO..."
        rm -f "$ISO_PATH_ROOT/$OEM_ISO"
    fi
}
trap cleanup ERR

# --- Download Windows ISO ---
download_windows_iso() {
    echo "================================================"
    echo "Windows 11 ISO Setup"
    echo "================================================"
    echo "To download the latest Windows 11 ISO:"
    echo "1. Go to: https://www.microsoft.com/software-download/windows11"
    echo "2. Scroll to 'Download Windows 11 Disk Image (ISO) for x64 devices'"
    echo "3. Select 'Windows 11 (multi-edition ISO)' and click Download"
    echo "4. Select your language and click Confirm"
    echo "5. Right-click the '64-bit Download' button and Copy Link Address"
    echo ""
    read -p "Paste the download link here: " DOWNLOAD_URL
    echo ""

    if [ -z "$DOWNLOAD_URL" ]; then
        echo "Error: No URL provided."
        return 1
    fi

    echo "Analyzing link..."
    
    # Try to extract filename from URL or headers
    # Default name if extraction fails
    local target_filename="Win11_English_x64.iso"
    
    # Use curl to get the filename from headers if possible
    if command -v curl &> /dev/null; then
        local header_name=$(curl -sI "$DOWNLOAD_URL" | grep -i "content-disposition" | sed -n 's/.*filename="\?\([^"]*\)"\?.*/\1/p' | tr -d '\r')
        if [ -n "$header_name" ]; then
            target_filename="$header_name"
        fi
    fi

    echo "Target filename: $target_filename"
    echo "Downloading to: $ISO_PATH_ROOT/$target_filename"
    
    if command -v wget &> /dev/null; then
        wget --progress=bar:force --show-progress -O "$ISO_PATH_ROOT/$target_filename" \
            "$DOWNLOAD_URL" || {
            echo "Error: Download failed."
            return 1
        }
    elif command -v curl &> /dev/null; then
        curl -L --progress-bar -o "$ISO_PATH_ROOT/$target_filename" \
            "$DOWNLOAD_URL" || {
            echo "Error: Download failed."
            return 1
        }
    else
        echo "Error: Neither wget nor curl found."
        return 1
    fi
    
    # Verify download
    if [ -f "$ISO_PATH_ROOT/$target_filename" ]; then
        FILE_SIZE=$(stat -c%s "$ISO_PATH_ROOT/$target_filename" 2>/dev/null || stat -f%z "$ISO_PATH_ROOT/$target_filename" 2>/dev/null)
        if [ "$FILE_SIZE" -lt 4000000000 ]; then
            echo "Warning: Downloaded file seems small ($FILE_SIZE bytes)"
            read -p "Continue anyway? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                return 1
            fi
        fi
        echo "Download successful!"
        WIN_ISO="$target_filename"
        return 0
    else
        return 1
    fi
}

# --- Checks ---

# Check if VM ID exists
if qm status $VMID &>/dev/null; then
    echo "Error: VM ID $VMID already exists"
    exit 1
fi

# Check if Storage IDs exist in Proxmox
if ! pvesm status | grep -q "^$DISK_STORAGE"; then
    echo "Error: Disk Storage '$DISK_STORAGE' not found"
    exit 1
fi

if ! pvesm status | grep -q "^$ISO_STORAGE_ID"; then
    echo "Error: ISO Storage '$ISO_STORAGE_ID' not found"
    exit 1
fi

# Check for Windows 11 ISO
echo "Searching for Windows 11 ISO..."
# Find any ISO starting with Win11
FOUND_ISO=$(find "$ISO_PATH_ROOT" -maxdepth 1 -name "Win11*.iso" -type f | head -n 1)

if [ -n "$FOUND_ISO" ]; then
    WIN_ISO=$(basename "$FOUND_ISO")
    echo "Found local ISO: $WIN_ISO"
    echo ""
    read -p "Use this ISO? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        if ! download_windows_iso; then
            echo "Setup cancelled."
            exit 1
        fi
    fi
else
    echo "No Windows 11 ISO found locally."
    if ! download_windows_iso; then
        echo "Please download the ISO manually and place it in $ISO_PATH_ROOT"
        exit 1
    fi
fi

if [ ! -f "$ISO_PATH_ROOT/$VIRTIO_ISO" ]; then
    echo "Error: VirtIO ISO not found at $ISO_PATH_ROOT/$VIRTIO_ISO"
    echo "Download from: https://github.com/virtio-win/virtio-win-pkg-scripts/blob/master/README.md"
    exit 1
fi

# Check for local answer file
if [ ! -f "$ANSWER_FILE" ]; then
    echo "Error: '$ANSWER_FILE' not found in current directory."
    echo "Please upload it to the same folder as this script."
    exit 1
fi

# Check for ISO generation tool
if ! command -v genisoimage &> /dev/null; then
    echo "Error: 'genisoimage' is not installed. Install it with: apt install genisoimage"
    exit 1
fi

# --- ISO Generation ---

echo "Generating Unattended ISO from $ANSWER_FILE..."
TMP_ISO_DIR=$(mktemp -d)
cp "$ANSWER_FILE" "$TMP_ISO_DIR/"

# Inject Password into the XML
# We use a delimiter other than / in case the password contains it
sed -i "s|PASSWORD_PLACEHOLDER|$ADMIN_PASSWORD|g" "$TMP_ISO_DIR/$ANSWER_FILE"

# -V "OEMDRV" is important for some Windows versions to detect it automatically
genisoimage -o "$ISO_PATH_ROOT/$OEM_ISO" -J -R -V "OEMDRV" "$TMP_ISO_DIR"
rm -rf "$TMP_ISO_DIR"

# --- VM Creation ---

echo "Creating VM $VMID ($VM_NAME)..."

# 1. Create the base VM with Memory, CPU, Network, and OS Type
# We use virtio-scsi-pci for the controller to allow for better disk features
qm create $VMID \
  --name "$VM_NAME" \
  --memory "$VM_MEMORY" \
  --cores "$VM_CORES" \
  --sockets "$VM_SOCKET" \
  --net0 virtio,bridge=vmbr0 \
  --ostype "$OS_TYPE" \
  --scsihw virtio-scsi-pci \
  --cpu host \
  --machine q35 \
  --bios ovmf

# 2. Add the Main Disk (SCSI) with SSD emulation and Discard
# This command automatically allocates the volume on the storage
echo "Allocating Main Disk..."
qm set $VMID --scsi0 $DISK_STORAGE:$DISK_SIZE,ssd=1,discard=on

# 3. Add EFI Disk and TPM (Required for Win11)
# We let Proxmox handle the allocation logic
echo "Configuring TPM and UEFI..."
qm set $VMID --efidisk0 $DISK_STORAGE:0,efitype=4m,pre-enrolled-keys=1
qm set $VMID --tpmstate0 $DISK_STORAGE:0,version=v2.0

# 4. Attach ISOs
echo "Attaching ISOs..."
qm set $VMID --ide2 $ISO_STORAGE_ID:iso/$WIN_ISO,media=cdrom
qm set $VMID --ide3 $ISO_STORAGE_ID:iso/$VIRTIO_ISO,media=cdrom
# Attach the generated answer file ISO
qm set $VMID --sata0 $ISO_STORAGE_ID:iso/$OEM_ISO,media=cdrom

# 5. Set Boot Order and Other Settings
echo "Finalizing Configuration..."
qm set $VMID --boot order='ide2;ide3;sata0;scsi0'
qm set $VMID --agent enabled=1,fstrim_cloned_disks=1
qm set $VMID --tablet 1

echo "================================================"
echo "VM $VMID created successfully!"
echo "================================================"
echo "Windows ISO used: $WIN_ISO"
echo ""
echo "Next Steps:"
echo "1. Start the VM: qm start $VMID"
echo "2. Open Console to monitor installation progress"
echo "3. The installation will proceed automatically (30-60 minutes)"
echo "   - Windows setup: ~10 minutes"
echo "   - Software installation (VS2022, VS Code, Git): ~20-30 minutes"
echo "================================================"