# Arch Linux Build Environment for Android 16 AOSP

This guide provides a complete walkthrough for setting up a customized Arch Linux environment optimized for building Android. It features the KDE Plasma desktop, configured to be user-friendly for those coming from Windows, while retaining the power and flexibility of Arch.

## Features

- **OS**: Arch Linux (rolling release)
- **Desktop Environment**: KDE Plasma (highly customizable, Windows-like feel)
- **Optimized for Android**: All necessary dependencies and tools for AOSP builds are included.
- **User-Friendly**: Includes quality-of-life packages and a familiar desktop layout.
- **Automated Setup**: Scripts are provided to automate most of the installation and configuration process.
- **VM Ready**: Includes guest utilities for a smooth experience in VirtualBox or VMware.

## Installation Process Overview

The installation is broken down into a few main steps:

1.  **Preparation**: Download the Arch Linux ISO and create a bootable USB drive.
2.  **Booting**: Boot your PC or VM from the live Arch environment.
3.  **Running the Installer**: Run the main `install.sh` script which will guide you through partitioning and the base installation.
4.  **System Configuration**: The script will automatically handle the setup of the desktop environment, users, and all required software.
5.  **First Boot**: Reboot into your new, fully configured Arch Linux system.

--- 

## Step 1: Preparation

1.  **Download Arch Linux ISO**:
    Go to the [official Arch Linux download page](https://archlinux.org/download/) and get the latest ISO file.

2.  **Create a Bootable USB Drive**:
    Use a tool like [Rufus](https://rufus.ie/) or [balenaEtcher](https://www.balena.io/etcher/) to write the downloaded ISO to a USB drive (8GB minimum recommended).

3.  **For Virtual Machine Setup**:
    -   **VMware/VirtualBox**: Create a new Linux virtual machine.
    -   **Type**: Linux, Version: Arch Linux (64-bit).
    -   **Memory (RAM)**: **16 GB** minimum (32 GB+ recommended for Android builds).
    -   **CPU Cores**: **8 cores** minimum (12+ recommended).
    -   **Virtual Disk Size**: **500 GB** minimum.
    -   **Graphics**: Enable 3D acceleration.
    -   Mount the downloaded Arch Linux ISO file in the virtual CD/DVD drive.

--- 

## Step 2: Boot and Run the Installer

1.  **Boot from Live Media**:
    Start your PC or VM, ensuring it boots from the Arch Linux ISO/USB you just created.

2.  **Connect to the Internet**:
    -   **Ethernet**: Should work automatically.
    -   **Wi-Fi**: Use the `iwctl` command-line tool to connect.
        ```bash
        # Start the tool
        iwctl
        # List devices (e.g., wlan0)
        device list
        # Scan for networks
        station [device_name] scan
        # List available networks
        station [device_name] get-networks
        # Connect to your network
        station [device_name] connect "Your_Network_Name"
        # Exit the tool
        exit
        ```
    -   Verify your connection: `ping archlinux.org`

3.  **Download the Setup Scripts**:
    Clone this repository to get the installation scripts.
    ```bash
    # Install git first
    pacman -Sy git

    # Clone the repository (replace with your repo URL if needed)
    git clone https://github.com/your-username/your-repo-name.git arch-setup
    cd arch-setup/arch_build_env
    ```

4.  **Run the Installer**:
    Execute the main installation script. It will guide you through the process.
    ```bash
    chmod +x install.sh
    ./install.sh
    ```

--- 

## Post-Installation

Once the script is finished and you've rebooted, you will be greeted by the KDE Plasma desktop. 

-   **Login**: Use the username and password you created during the installation.
-   **Android Build Environment**: The `~/android` directory from this project will be available. You can navigate there and use the `make` commands as previously defined.
-   **System Updates**: To keep your system up-to-date, run the following command in the terminal (Konsole):
    ```bash
    sudo pacman -Syu
    ```

## Included Software

-   **Desktop**: KDE Plasma, SDDM (Display Manager)
-   **Android Build Tools**: All dependencies from the `setup_environment.sh` script are included (`jdk11-openjdk`, `git`, `repo`, `ccache`, etc.).
-   **Web Browser**: Firefox
-   **Terminal**: Konsole
-   **File Manager**: Dolphin
-   **Text Editor**: Kate, VS Code (with C++, Python, and Shell extensions)
-   **System Tools**: `htop`, `neofetch`, `gparted`
-   **VM Utilities**: `virtualbox-guest-utils` and `open-vm-tools` will be installed for better integration.
