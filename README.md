# Proxmox Windows 11 IDE Automation

This project automates the creation of a fully configured Windows 11 Development VM on Proxmox. It handles VM creation, unattended Windows installation, debloating, and the installation of essential development tools (VS2022, VS Code, Git, OpenSSH).

## ✨ Features

- **Fully Automated VM Creation**: One-command deployment from Proxmox shell
- **Unattended Windows 11 Installation**: No manual intervention required
- **VirtIO Drivers**: Automatically loads storage and network drivers during setup
- **Debloated Windows**: Telemetry, bloatware, and search suggestions disabled
- **Pre-installed Development Environment**:
  - Visual Studio 2022 Professional with .NET Desktop workload
  - Visual Studio Code
  - Git
- **SSH Access Enabled**: OpenSSH server pre-configured and ready
- **Resource Optimized**: 16GB RAM and 6 CPU cores by default (customizable)

## 🚀 Quick Start


```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/npfusaro/win11-dev-proxmox-script/main/install.sh)" -- -i 3000 -n "Dev-VM" -p "SecurePass123"
```
## ⚙️ Configuration

### Command Line Arguments
The `Proxmox script.sh` accepts the following flags to customize the deployment without editing files:

| Flag | Description | Default |
|------|-------------|---------|
| `-i` | **VM ID**: The unique ID for the new VM. | `1022` |
| `-n` | **VM Name**: The name label for the VM. | `win11-ide` |
| `-m` | **Memory (MB)**: RAM allocated to the VM. | `16384` (16GB) |
| `-c` | **Cores**: Number of CPU cores allocated. | `6` |
| `-p` | **Password**: Local `Admin` user password. | `Password123!` |

**Example:**
```bash
./Proxmox\ script.sh -i 4000 -n "Build-Server" -m 32768 -c 8 -p "MySecretPassword!"
```

### Script Variables (Advanced)
Open `Proxmox script.sh` to edit these variables if your Proxmox environment differs from the defaults:

*   **`DISK_STORAGE`**: Storage ID for the VM disk (Default: `local-lvm`).
*   **`ISO_STORAGE_ID`**: Storage ID for ISOs (Default: `nfs`).
*   **`ISO_PATH_ROOT`**: Filesystem path to your ISO storage (Default: `/mnt/pve/nfs/template/iso`).
*   **`WIN_ISO`**: Filename of your Windows 11 ISO.
*   **`VIRTIO_ISO`**: Filename of your VirtIO drivers ISO.

### Unattended Installation (`autounattend.xml`)
The answer file handles the Windows setup. Key configurations include:

*   **User**: Creates a local user named `Admin`.
*   **Debloat**: Automatically disables Telemetry, "Consumer Features" (Candy Crush, etc.), and Search Suggestions.
*   **Software**: Automatically installs the following via Chocolatey:
    *   Git
    *   Visual Studio Code
    *   Visual Studio 2022 Professional (NetDesktop Workload)
    *   OpenSSH Server (Enabled & Firewall Rule Added)

## 📋 Prerequisites

### 1. Proxmox VE
Tested on Proxmox VE 8.x. Should work on 7.x as well.

### 2. Required ISOs
You must upload these ISOs to your Proxmox ISO storage before running the script:

**Windows 11 ISO:**
- **Auto-Download:** The script will ask for a download link if the ISO is missing.
- **Get Link:** Go to [Microsoft](https://www.microsoft.com/software-download/windows11), select "Windows 11 (multi-edition ISO)", choose language, and copy the "64-bit Download" link.
- **Manual Upload:** Alternatively, download it yourself and upload to Proxmox.
- Filename in script: `Win11_23H2_x64v2_auto.iso` (or whatever the download provides)

**VirtIO Drivers ISO:**
- Download from [Fedora Project](https://github.com/virtio-win/virtio-win-pkg-scripts/blob/master/README.md)
- Latest stable release: [virtio-win-0.1.240.iso](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso)
- Filename in script: `virtio-win-0.1.240.iso`

### 3. Tools
The script requires `genisoimage` to generate the answer file ISO:
```bash
apt install genisoimage
```
*(The install.sh wrapper handles this automatically)*

## 🎯 Post-Installation

After the VM finishes installing (approximately 30-60 minutes depending on your hardware):

### Default Credentials
- **Username:** `Admin`
- **Password:** As configured via `-p` flag or default `Password123!`

### Access Methods
- **Console:** Via Proxmox web interface
- **RDP:** Port 3389 (use Remote Desktop)
  ```bash
  mstsc /v:<VM-IP>
  ```
- **SSH:** Port 22
  ```bash
  ssh Admin@<VM-IP>
  ```

### Verify Installation
1. Check that Visual Studio 2022, VS Code, and Git are installed
2. Verify OpenSSH is running:
   ```powershell
   Get-Service sshd
   ```
3. Confirm debloat settings via Registry Editor

## ⚠️ Troubleshooting

### "File not found" errors
Ensure `ISO_PATH_ROOT` in the script matches the actual path on your Proxmox host where your ISO storage is mounted. Check with:
```bash
pvesm path nfs:iso/Win11_23H2_x64v2_auto.iso
```

### Installation appears stalled
The VS2022 installation is large (~10GB download). If the VM seems idle after first login:
- Open Task Manager and check for `choco.exe` or `vs_installer.exe` processes
- Allow 20-30 minutes for Visual Studio to complete
- Check `C:\ProgramData\chocolatey\logs` for installation logs

### Network issues
- The VM requires internet access on `vmbr0` during first login to download packages
- Ensure your Proxmox bridge has DHCP or configure static IP in `autounattend.xml`

### VirtIO drivers not loading
- Verify the VirtIO ISO is correctly attached to the VM
- The answer file checks both `E:\` and `F:\` drive letters automatically
- If needed, manually browse to the VirtIO ISO during Windows setup

## 📝 License

This project is open source and available under the MIT License.

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the issues page or submit a pull request.

