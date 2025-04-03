#!/usr/bin/env bash
bold=$(tput setaf 2 bold)      # makes text bold and sets color to 2
bolderror=$(tput setaf 3 bold) # makes text bold and sets color to 3
normal=$(tput sgr0)            # resets text settings back to normal

error() {\
    printf "%s\n" "${bolderror}ERROR:${normal}\\n%s\\n" "$1" >&2; exit 1;
}

if ! command -v dialog &> /dev/null; then
    echo "dialog is not installed. Installing it now..."
    pacman -Sy --noconfirm dialog || { echo "Failed to install dialog. Please install it manually."; exit 1; }
fi


check_root() {
    if [[ $EUID -ne 0 ]]; then
        dialog --title "Permission Denied" --msgbox "\
${bolderror}ERROR:${normal} This script must be run as root.\n\n\
Please run it with sudo or as the root user." 10 50
        exit 1
    fi
}
check_root 


chaoticaur() {
    printf "%s\n" "## Installing Chaotic AUR ##"

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Receiving key for Chaotic AUR..."; sleep 1
        pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com && echo "30"
        echo "Signing key for Chaotic AUR..."; sleep 1
        pacman-key --lsign-key 3056513887B78AEB && echo "50"
        echo "Updating package database..."; sleep 1
        pacman -Sy && echo "70"
        echo "Installing Chaotic AUR keyring..."; sleep 1
        yes | LC_ALL=en_US.UTF-8 pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' && echo "85"
        echo "Installing Chaotic AUR mirrorlist..."; sleep 1
        yes | LC_ALL=en_US.UTF-8 pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' && echo "100"
    ) | dialog --gauge "Installing Chaotic AUR..." 10 70 0

    # Check if the installation was successful
    if [[ $? -ne 0 ]]; then
        error "Error installing Chaotic AUR!"
    fi

    printf "%s\n" "${bold}Chaotic AUR installed successfully!"
}
chaoticaur || error "Error installing Chaotic AUR!"


addrepo() {
    printf "%s\n" "## Adding repos to /etc/pacman.conf."

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Installing artix-archlinux-support package..."; sleep 1
        pacman -Sy --noconfirm artix-archlinux-support && echo "50"
        echo "Copying pacman.conf to /etc/..."; sleep 1
        cp pacman.conf /etc/ && echo "100"
    ) | dialog --gauge "Adding repositories to pacman.conf..." 10 70 0

    # Check if the operation was successful
    if [[ $? -ne 0 ]]; then
        error "Error adding repos!"
    fi

    printf "%s\n" "${bold}Repositories added successfully!"
}
addrepo || error "Error adding repos!"


installzfs() {
    printf "%s\n" "${bold}# Installing the ZFS modules"

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Updating package database..."; sleep 1
        pacman -Sy --noconfirm --needed zfs-dkms-git zfs-utils-git gptfdisk && echo "50"
        echo "Installing ZFS OpenRC package..."; sleep 1
        pacman -U --noconfirm zfs-openrc-20241023-1-any.pkg.tar.zst && echo "70"
        echo "Loading ZFS kernel module..."; sleep 1
        modprobe zfs && echo "80"
        echo "Enabling ZFS services..."; sleep 1
        rc-update add zfs-zed boot && rc-service zfs-zed start && echo "100"
    ) | dialog --gauge "Installing ZFS modules..." 10 70 0

    # Check if ZFS was installed successfully
    if ! modinfo zfs &>/dev/null; then
        error "Error installing ZFS!"
    fi

    printf "%s\n" "${bold}Done!"
}
installzfs || error "Error installing ZFS!"


installtz() {
    printf "%s\n" "${bold}## Setting install variables"

    # Generate a list of regions from /usr/share/zoneinfo
    region_list=$(find /usr/share/zoneinfo -mindepth 1 -maxdepth 1 -type d | sed 's|/usr/share/zoneinfo/||' | sort)

    # Prepare the list of regions for the dialog menu
    dialog_options=()
    index=1
    while IFS= read -r region; do
        dialog_options+=("$index" "$region")
        index=$((index + 1))
    done <<< "$region_list"

    # Create a dialog menu for regions
    region_index=$(dialog --clear --title "Region Selection" \
        --menu "Choose your region:" 20 60 15 "${dialog_options[@]}" 3>&1 1>&2 2>&3)

    # Check if the user selected a region
    if [[ -z "$region_index" ]]; then
        error "No region selected!"
    fi

    # Map the selected index back to the region
    region=$(echo "$region_list" | sed -n "${region_index}p")

    # Generate a list of cities for the selected region
    city_list=$(find "/usr/share/zoneinfo/$region" -type f | sed "s|/usr/share/zoneinfo/$region/||" | sort)

    # Prepare the list of cities for the dialog menu
    dialog_options=()
    index=1
    while IFS= read -r city; do
        dialog_options+=("$index" "$city")
        index=$((index + 1))
    done <<< "$city_list"

    # Create a dialog menu for cities
    city_index=$(dialog --clear --title "City Selection" \
        --menu "Choose your city in $region:" 20 60 15 "${dialog_options[@]}" 3>&1 1>&2 2>&3)

    # Check if the user selected a city
    if [[ -z "$city_index" ]]; then
        error "No city selected!"
    fi

    # Map the selected index back to the city
    city=$(echo "$city_list" | sed -n "${city_index}p")

    # Set the selected timezone
    INST_TZ="/usr/share/zoneinfo/$region/$city"
    printf "%s\n" "${bold}Timezone set to $region/$city"
}
installtz || error "Error selecting timezone!"


installhost() {
    printf "%s\n" "${bold}## Set desired hostname"

    # Create a dialog input box for the hostname
    INST_HOST=$(dialog --clear --title "Hostname Configuration" \
        --inputbox "Enter your desired hostname:" 10 50 3>&1 1>&2 2>&3)

    # Check if the user provided a hostname
    if [[ -z "$INST_HOST" ]]; then
        error "No hostname provided!"
    fi

    printf "%s\n" "${bold}Hostname set to $INST_HOST"
}
installhost || error "Error setting hostname!"

installkrn() {
    printf "%s\n" "${bold}Select the kernel you want to install"
    kernel_choice=$(dialog --clear --title "Kernel Selection" \
        --menu "Choose one of the following kernels:" 15 50 3 \
        1 "linux" \
        2 "linux-zen" \
        3 "linux-lts" \
        3>&1 1>&2 2>&3)

    case $kernel_choice in
        1) INST_LINVAR="linux" ;;
        2) INST_LINVAR="linux-zen" ;;
        3) INST_LINVAR="linux-lts" ;;
        *) error "Invalid kernel choice!" ;;
    esac

    printf "%s\n" "${bold}Kernel selected: $INST_LINVAR"
}
installkrn || error "Error selecting kernel!"


selectdisk() {
    printf "%s\n" "${bold}## Decide which disk you want to use"

    # Generate a list of disks from /dev/disk/by-id
    disk_list=$(ls -1 /dev/disk/by-id)

    # Prepare the list for the whiptail menu
    dialog_options=()
    for disk in $disk_list; do
        dialog_options+=("$disk" "Disk")
    done

    # Create a whiptail menu for disk selection with a larger box
    disk=$(whiptail --title "Disk Selection" \
        --menu "Choose a disk to use:" 30 80 20 "${dialog_options[@]}" 3>&1 1>&2 2>&3)

    # Check if the user selected a disk
    if [[ -z "$disk" ]]; then
        error "No disk selected!"
    fi

    # Set the selected disk
    DISK="/dev/disk/by-id/$disk"
    printf "%s\n" "${bold}Disk selected: $DISK"
}
selectdisk || error "Disk doesn't exist!"


settingup() {\
	printf "%s\n" "${bold}Creating temporary folder for installation"
	INST_MNT=$(mktemp -d)
	printf "%s\n" "${bold}Giving your zpools a unique identifier"
	INST_UUID=$(dd if=/dev/urandom of=/dev/stdout bs=1 count=100 2>/dev/null |tr -dc 'a-z0-9' | cut -c-6)
}
settingup || error "Error setting up the installation!"


partdrive() {
    # Display the joke in a dialog infobox
    dialog --infobox "Starting install, it will take time, so go GRUB a cup of coffee" 5 50
    sleep 3  # Pause for a few seconds to let the user read the message

    printf "%s\n" "${bold}Partitioning drive"

    # Prompt the user for the swap partition size
    SWAP_SIZE=$(dialog --clear --title "Swap Partition Size" \
        --inputbox "Enter the size of the swap partition in GB (e.g., 8 for 8GB):" 10 50 3>&1 1>&2 2>&3)

    # Validate the input
    if [[ -z "$SWAP_SIZE" || ! "$SWAP_SIZE" =~ ^[0-9]+$ ]]; then
        error "Invalid swap size entered!"
    fi

    # Partition the drive
    sgdisk --zap-all $DISK
    sgdisk -n1:0:+1G -t1:EF00 $DISK  # EFI System Partition
    sgdisk -n2:0:-${SWAP_SIZE}G -t2:BF00 $DISK  # ZFS Pool Partition
    sgdisk -n3:0:0 -t3:8308 $DISK  # Swap Partition
    partprobe || true

    printf "%s\n" "${bold}Partitioning completed successfully!"
}
partdrive || error "Error setting up the drive!"


rootpool() {
    printf "%s\n" "${bold}Creating root pool"

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Creating ZFS root pool..."; sleep 1
        zpool create -f -o ashift=12 -O acltype=posixacl -O canmount=off -O compression=zstd \
            -O dnodesize=auto -O normalization=formD -O relatime=on -O xattr=sa \
            -O mountpoint=/ -R $INST_MNT rpool_$INST_UUID $DISK-part2 && echo "50"
        sleep 1
        echo "Finalizing setup..."; sleep 1
        echo "100"
    ) | dialog --gauge "Setting up the ZFS root pool..." 10 70 0

    # Check if the pool was created successfully
    if ! zpool status rpool_$INST_UUID &>/dev/null; then
        error "Error setting up the root pool!"
    fi

    printf "%s\n" "${bold}Root pool created successfully!"
}
rootpool || error "Error setting up the root pool"


createdatasets() {
    printf "%s\n" "${bold}Creating datasets"

    # Start the progress bar
    (
        echo "10"; sleep 1
        zfs create -o mountpoint=none rpool_$INST_UUID/DATA && echo "20"
        zfs create -o mountpoint=none rpool_$INST_UUID/ROOT && echo "40"
        zfs create -o mountpoint=/ -o canmount=noauto rpool_$INST_UUID/ROOT/default && echo "60"
        zfs create -o mountpoint=/home rpool_$INST_UUID/DATA/home && echo "70"
        zfs create -o mountpoint=/var -o canmount=off rpool_$INST_UUID/var && echo "80"
        zfs create rpool_$INST_UUID/var/log && echo "90"
        zfs create -o mountpoint=/var/lib -o canmount=off rpool_$INST_UUID/var/lib && echo "100"
    ) | dialog --gauge "Creating ZFS datasets..." 10 70 0

    # Check if datasets were created successfully
    if ! zfs list rpool_$INST_UUID &>/dev/null; then
        error "Error creating the datasets!"
    fi

    printf "%s\n" "${bold}Datasets created successfully!"
}
createdatasets || error "Error creating the datasets"


mountall() {
    printf "%s\n" "${bold}Mounting everything"

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Mounting root dataset..."; sleep 1
        zfs mount rpool_$INST_UUID/ROOT/default && echo "50"
        echo "Mounting all other datasets..."; sleep 1
        zfs mount -a && echo "100"
    ) | dialog --gauge "Mounting ZFS datasets..." 10 70 0

    # Check if all datasets are mounted successfully
    if ! zfs mount | grep -q "rpool_$INST_UUID"; then
        error "Error mounting partitions!"
    fi

    printf "%s\n" "${bold}All datasets mounted successfully!"
}
mountall || error "Error mounting partitions!"


permissions() {
    printf "%s\n" "${bold}Giving correct permissions to /root and /var/tmp"

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Creating /root directory..."; sleep 1
        mkdir $INST_MNT/root && echo "30"
        echo "Creating /var/tmp directory..."; sleep 1
        mkdir -p $INST_MNT/var/tmp && echo "60"
        echo "Setting permissions for /root..."; sleep 1
        chmod 750 $INST_MNT/root && echo "80"
        echo "Setting permissions for /var/tmp..."; sleep 1
        chmod 1777 $INST_MNT/var/tmp && echo "100"
    ) | dialog --gauge "Setting up permissions..." 10 70 0

    # Check if the directories and permissions were set correctly
    if [[ ! -d "$INST_MNT/root" || ! -d "$INST_MNT/var/tmp" ]]; then
        error "Error setting up permissions!"
    fi

    printf "%s\n" "${bold}Permissions set successfully!"
}
permissions || error "Wrong permissions!"


efiswap() {
    printf "%s\n" "${bold}Formatting and mounting boot, EFI system partition, and swap"

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Creating swap partition..."; sleep 1
        mkswap -L SWAP ${DISK}-part3 && echo "30"
        echo "Activating swap partition..."; sleep 1
        swapon ${DISK}-part3 && echo "50"
        echo "Formatting EFI partition..."; sleep 1
        echo "Mounting EFI partition..."; sleep 1
        mkdir -p $INST_MNT/boot/efi && mount -t vfat ${DISK}-part1 $INST_MNT/boot/efi && echo "100"
    ) | dialog --gauge "Setting up EFI and swap partitions..." 10 70 0

    # Check if the EFI partition is mounted
    if ! mount | grep -q "$INST_MNT/boot/efi"; then
        error "EFI partition is not mounted!"
    fi

    # Check if the swap partition is active using UUID
    swap_uuid=$(blkid -s UUID -o value ${DISK}-part3)
    if ! swapon --show | grep -q "$swap_uuid"; then
        error "Swap partition is not active!"
    fi

    printf "%s\n" "${bold}EFI and swap partitions set up successfully!"
}
efiswap || error "Error setting up EFI and swap partitions!"

installpkgs() {
    printf "%s\n" "${bold}Installing packages"

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Installing base packages..."; sleep 1
        basestrap $INST_MNT - < pkglist.txt && echo "50"
        echo "Installing kernel and ZFS packages..."; sleep 1
        basestrap $INST_MNT $INST_LINVAR ${INST_LINVAR}-headers linux-firmware zfs-dkms-git zfs-utils-git && echo "80"
        echo "Copying pacman configuration..."; sleep 1
        rm -rf $INST_MNT/etc/pacman.d
        rm $INST_MNT/etc/pacman.conf
        cp -r /etc/pacman.d $INST_MNT/etc
        cp /etc/pacman.conf $INST_MNT/etc && echo "100"
    ) | dialog --gauge "Installing packages..." 10 70 0

    # Check if the packages were installed successfully
    if [[ $? -ne 0 ]]; then
        error "Error installing packages!"
    fi

    printf "%s\n" "${bold}Packages installed successfully!"
}
installpkgs

fstab() {
    printf "%s\n" "${bold}Generating fstab"

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Adding EFI partition to fstab..."; sleep 1
        echo "UUID=$(blkid -s UUID -o value ${DISK}-part1) /boot/efi vfat umask=0022,fmask=0022,dmask=0022 0 1" >> $INST_MNT/etc/fstab && echo "50"
        echo "Adding swap partition to fstab..."; sleep 1
        echo "UUID=$(blkid -s UUID -o value ${DISK}-part3) none swap defaults 0 0" >> $INST_MNT/etc/fstab && echo "100"
    ) | dialog --gauge "Generating fstab..." 10 70 0

    # Check if fstab was generated successfully
    if [[ ! -f "$INST_MNT/etc/fstab" ]]; then
        error "Error generating fstab!"
    fi

    printf "%s\n" "${bold}fstab generated successfully!"
}
fstab || error "Error generating fstab" && exportpools


mkinitram() {
    printf "%s\n" "${bold}Creating new mkinitcpio configuration and regenerating initramfs"

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Backing up existing mkinitcpio.conf..."; sleep 1
        mv $INST_MNT/etc/mkinitcpio.conf $INST_MNT/etc/mkinitcpio.conf.back && echo "30"
        echo "Writing new mkinitcpio.conf..."; sleep 1
        tee $INST_MNT/etc/mkinitcpio.conf <<EOF
HOOKS=(base udev autodetect modconf block keyboard zfs filesystems)
EOF
        echo "Regenerating initramfs..."; sleep 1
        artix-chroot $INST_MNT /bin/bash -c mkinitcpio -P && echo "100"
    ) | dialog --gauge "Creating new mkinitcpio configuration..." 10 70 0

    # Check if the initramfs was regenerated successfully
    if [[ $? -ne 0 ]]; then
        error "Error creating new mkinitcpio!"
    fi

    printf "%s\n" "${bold}mkinitcpio configuration and initramfs created successfully!"
}
mkinitram || error "Error creating new mkinitcpio"


finishtouch() {
    printf "%s\n" "${bold}Finalizing installation"

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Setting hostname..."; sleep 1
        echo $INST_HOST > $INST_MNT/etc/hostname && echo "20"
        echo "Setting timezone..."; sleep 1
        ln -sf $INST_TZ $INST_MNT/etc/localtime && echo "40"
        echo "Generating locale..."; sleep 1
        echo "en_US.UTF-8 UTF-8" >> $INST_MNT/etc/locale.gen
        echo "LANG=en_US.UTF-8" >> $INST_MNT/etc/locale.conf
        artix-chroot $INST_MNT /bin/bash -c locale-gen && echo "60"
        echo "Preparing installation scripts..."; sleep 1
        mkdir $INST_MNT/install
        cp zfs-openrc-20241023-1-any.pkg.tar.zst $INST_MNT/install/
        awk -v n=5 -v s="INST_UUID=${INST_UUID}" 'NR == n {print s} {print}' artix-chroot.sh > artix-chroot-new.sh
        awk -v n=6 -v s="DISK=${DISK}" 'NR == n {print s} {print}' artix-chroot-new.sh > artix-chroot-new2.sh
        rm artix-chroot-new.sh
        mv artix-chroot-new2.sh $INST_MNT/install/artix-chroot.sh
        chmod +x $INST_MNT/install/artix-chroot.sh && echo "80"
        echo "Running final chroot script..."; sleep 1
        artix-chroot $INST_MNT /bin/bash /install/artix-chroot.sh && echo "100"
    ) | dialog --gauge "Finalizing installation..." 10 70 0

    # Check if the final steps were completed successfully
    if [[ $? -ne 0 ]]; then
        error "Something went wrong, re-run the script with correct values!"
    fi

    printf "%s\n" "${bold}Installation finalized successfully!"
}
finishtouch || error "Something went wrong, re-run the script with correct values!"

exportpools() {
    printf "%s\n" "${bold}Unmounting partitions and exporting pools"

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Removing installation files..."; sleep 1
        rm -rf $INST_MNT/install && echo "30"
        echo "Unmounting EFI partition..."; sleep 1
        umount $INST_MNT/boot/efi && echo "50"
        echo "Deactivating swap..."; sleep 1
        swapoff $DISK-part4 && echo "70"
        echo "Exporting ZFS pool..."; sleep 1
        zpool export rpool_${INST_UUID} && echo "100"
    ) | dialog --gauge "Unmounting and exporting ZFS pools..." 10 70 0

    # Check if the pools were exported successfully
    if [[ $? -ne 0 ]]; then
        error "Something went wrong!"
    fi

    printf "%s\n" "${bold}Pools exported successfully!"
}
exportpools || error "Something went wrong!"

# Display final messages in a dialog box
dialog --title "Installation Complete" --msgbox "\
${bold}You can reboot now!${normal}\n\n\
${bolderror}If you have any problem, open an issue on this script's repository!${normal}" 10 50