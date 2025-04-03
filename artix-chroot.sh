!#/usr/bin/env bash
bold=$(tput setaf 2 bold)      # makes text bold and sets color to 2
bolderror=$(tput setaf 3 bold) # makes text bold and sets color to 3
normal=$(tput sgr0)            # resets text settings back to normal


error() {\
    printf "%s\n" "${bolderror}ERROR:${normal}\\n%s\\n" "$1" >&2; exit 1;
}


inststuff() {
    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Updating package database..."; sleep 1
        pacman -Sy --noconfirm && echo "30"
        echo "Installing yay and git..."; sleep 1
        pacman -S --noconfirm --needed yay git && echo "50"
        echo "Installing base-devel and fakeroot..."; sleep 1
        pacman -S --noconfirm --needed base-devel fakeroot && echo "70"
        echo "Installing LightDM and Cinnamon..."; sleep 1
        pacman -S --noconfirm --needed lightdm lightdm-openrc lightdm-gtk-greeter cinnamon && echo "90"
        echo "Installing Brave browser..."; sleep 1
        pacman -S --noconfirm --needed brave-bin && echo "100"
    ) | dialog --gauge "Installing packages..." 10 70 0

    # Check if the installation was successful
    if [[ $? -ne 0 ]]; then
        error "Error installing packages!"
    fi

    printf "%s\n" "${bold}Packages installed successfully!"
}
inststuff || error "Error installing packages"


addlocales() {
    # Extract all locales from the cleaned-up locale.gen file
    locale_list=$(grep -v '^$' locale.gen | awk '{print $1}' | sort)

    # Prepare the list for the dialog menu
    dialog_options=()
    while IFS= read -r locale; do
        dialog_options+=("$locale" "$locale")
    done <<< "$locale_list"

    # Display the list of locales in a dialog menu
    alocale=$(dialog --clear --title "Locale Selection" \
        --menu "Choose your locale from the list:" 20 70 15 "${dialog_options[@]}" 3>&1 1>&2 2>&3)

    # Check if the user selected a locale
    if [[ -z "$alocale" ]]; then
        printf "%s\n" "No locale selected. Skipping locale configuration."
        return 0
    fi

    # Uncomment the selected locale in /etc/locale.gen
    sed -i "s/^#\s*\($alocale\)/\1/" /etc/locale.gen

    # Generate the selected locale
    locale-gen

    printf "%s\n" "${bold}Locale '$alocale' has been added and generated successfully!"
}
addlocales || error "Cannot generate locales"


setlocale() {\
    printf "%s\n" "${bold}Setting locale to $alocale"
    echo "LANG=$alocale" > /etc/locale.conf
}
setlocale || error "Cannot set locale"


USERADD() {
    # Prompt for the username using a dialog input box
    username=$(dialog --clear --title "Create User Account" \
        --inputbox "Enter the non-root username:" 10 50 3>&1 1>&2 2>&3)

    # Check if the username is empty
    if [[ -z "$username" ]]; then
        error "No username provided!"
    fi

    # Add the user
    useradd -m -G audio,video,wheel "$username" || error "Failed to add user $username"

    # Prompt for the password using a dialog password box
    password=$(dialog --clear --title "Set User Password" \
        --passwordbox "Enter the password for $username:" 10 50 3>&1 1>&2 2>&3)

    # Check if the password is empty
    if [[ -z "$password" ]]; then
        error "No password provided!"
    fi

    # Set the password for the user
    echo "$username:$password" | chpasswd || error "Failed to set password for $username"

    printf "%s\n" "${bold}User $username has been created successfully!"
}
USERADD || error "Error adding user to your install"


zfsbootmenu() {
    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Creating ZFSBootMenu directory..."; sleep 1
        mkdir -p /boot/efi/EFI/zbm && echo "30"
        echo "Downloading ZFSBootMenu EFI file..."; sleep 1
        wget https://get.zfsbootmenu.org/latest.EFI -O /boot/efi/EFI/zbm/zfsbootmenu.EFI && echo "70"
        echo "Configuring EFI boot entry..."; sleep 1
        efibootmgr --disk ${DISK} --part 1 --create --label "ZFSBootMenu" \
            --loader '\EFI\zbm\zfsbootmenu.EFI' \
            --unicode "spl_hostid=$(hostid) zbm.timeout=3 zbm.prefer=zroot zbm.import_policy=hostid" --verbose && echo "100"
    ) | dialog --gauge "Installing ZFSBootMenu..." 10 70 0

    # Check if the ZFSBootMenu installation was successful
    if [[ $? -ne 0 ]]; then
        error "Error installing ZFSBootMenu!"
    fi

    printf "%s\n" "${bold}ZFSBootMenu installed successfully!"
}
zfsbootmenu || error "Error installing ZFSBootMenu!"


zfsservice() {
    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Installing ZFS OpenRC package..."; sleep 1
        pacman -U --noconfirm /install/zfs-openrc-20241023-1-any.pkg.tar.zst && echo "30"
        echo "Adding zfs-import service to boot..."; sleep 1
        rc-update add zfs-import boot && echo "50"
        echo "Adding zfs-load-key service to boot..."; sleep 1
        rc-update add zfs-load-key boot && echo "60"
        echo "Adding zfs-share service to boot..."; sleep 1
        rc-update add zfs-share boot && echo "70"
        echo "Adding zfs-zed service to boot..."; sleep 1
        rc-update add zfs-zed boot && echo "80"
        echo "Adding zfs-mount service to boot..."; sleep 1
        rc-update add zfs-mount boot && echo "100"
    ) | dialog --gauge "Configuring ZFS services..." 10 70 0

    # Check if the ZFS services were configured successfully
    if [[ $? -ne 0 ]]; then
        error "Error configuring ZFS services!"
    fi

    printf "%s\n" "${bold}ZFS services configured successfully!"
}
zfsservice || error "Error configuring ZFS services!"

enableservices() {
    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Enabling NetworkManager service..."; sleep 1
        rc-update add NetworkManager default && echo "20"
        echo "Enabling LightDM service..."; sleep 1
        rc-update add lightdm default && echo "30"
        echo "Enabling D-Bus service..."; sleep 1
        rc-update add dbus default && echo "40"
        echo "Enabling Metalog service..."; sleep 1
        rc-update add metalog default && echo "50"
        echo "Enabling ACPID service..."; sleep 1
        rc-update add acpid default && echo "60"
        echo "Enabling Bluetooth service..."; sleep 1
        rc-update add bluetoothd default && echo "70"
        echo "Enabling Cronie service..."; sleep 1
        rc-update add cronie default && echo "80"
        echo "Enabling Elogind service..."; sleep 1
        rc-update add elogind boot && echo "100"
    ) | dialog --gauge "Enabling system services..." 10 70 0

    # Check if the services were enabled successfully
    if [[ $? -ne 0 ]]; then
        error "Error enabling services!"
    fi

    printf "%s\n" "${bold}Services enabled successfully!"
}
enableservices || error "Error enabling services!"


passwdroot() {
    # Prompt for the root password using a dialog password box
    root_password=$(dialog --clear --title "Set Root Password" \
        --passwordbox "Enter the desired password for the root user:" 10 50 3>&1 1>&2 2>&3)

    # Check if the password is empty
    if [[ -z "$root_password" ]]; then
        error "No password provided for root!"
    fi

    # Confirm the root password
    confirm_password=$(dialog --clear --title "Confirm Root Password" \
        --passwordbox "Re-enter the password for the root user:" 10 50 3>&1 1>&2 2>&3)

    # Check if the passwords match
    if [[ "$root_password" != "$confirm_password" ]]; then
        error "Passwords do not match!"
    fi

    # Set the root password
    echo "root:$root_password" | chpasswd || error "Failed to set root password!"

    printf "%s\n" "${bold}Root password has been set successfully!"
}
passwdroot || error "Error setting root password!"


cachefile() {
    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Setting ZFS cachefile..."; sleep 1
        zpool set cachefile=/etc/zfs/zpool.cache rpool_$INST_UUID && echo "100"
    ) | dialog --gauge "Creating ZFS cachefile for initcpio..." 10 70 0

    # Check if the cachefile was created successfully
    if [[ $? -ne 0 ]]; then
        error "Failed to generate cachefile!"
    fi

    printf "%s\n" "${bold}Cachefile created successfully!"
}
cachefile || error "Failed to generate cachefile"


regenerate_initcpio() {
    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Backing up existing initramfs..."; sleep 1
        cp /boot/initramfs-linux.img /boot/initramfs-linux.img.bak && echo "30"
        echo "Regenerating initramfs..."; sleep 1
        mkinitcpio -P && echo "100"
    ) | dialog --gauge "Regenerating initramfs..." 10 70 0

    # Check if the initramfs was regenerated successfully
    if [[ $? -ne 0 ]]; then
        error "Error regenerating initramfs!"
    fi

    printf "%s\n" "${bold}Initramfs regenerated successfully!"
}
regenerate_initcpio || error "Error regenerating initramfs!"


# Display a message box indicating the installation is complete
dialog --title "Installation Complete" --msgbox "\
${bold}Finish!${normal}\n\n\
The installation process has been completed successfully." 10 50