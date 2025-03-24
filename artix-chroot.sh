!#/usr/bin/env bash
bold=$(tput setaf 2 bold)      # makes text bold and sets color to 2
bolderror=$(tput setaf 3 bold) # makes text bold and sets color to 3
normal=$(tput sgr0)            # resets text settings back to normal


error() {\
    printf "%s\n" "${bolderror}ERROR:${normal}\\n%s\\n" "$1" >&2; exit 1;
}


inststuff() {\
    pacman -Sy --noconfirm --needed yay git base-devel fakeroot lightdm lightdm-openrc lightdm-gtk-greeter cinnamon brave-bin
}
inststuff || error "Error installing packages"


addlocales() {
    printf "%s\n" "Enter your locale, you can skip it if you are using the us one e.g. "en_US.UTF-8 UTF-8" without quotes"
    read alocale
    echo $alocale >> /etc/locale.gen 
    locale-gen
}
addlocales || error "Cannot generate locales"


USERADD() {\
    printf "%s\n" "Choose non-root user account name"
    read username
    useradd -m -G audio,video,wheel $username 
    printf "%s\n" "Enter the account password\n"
    passwd $username
}
USERADD || error "Error adding ${username} to your install" 


zfsservice() {\
    su $username -c "cd && git clone https://aur.archlinux.org/zfs-openrc.git && cd zfs-openrc && makepkg -sri --noconfirm"
    rc-update add zfs-import boot
    rc-update add zfs-load-key boot
    rc-update add zfs-share boot
    rc-update add zfs-zed boot
    rc-update add zfs-mount boot
}
zfsservice || error "Error installing zfs services"


enableservices() {\
    rc-update add NetworkManager default
    rc-update add lightdm default
    rc-update add dbus default
    rc-update add metalog default
    rc-update add acpid default
    rc-update add bluetoothd default
    rc-update add cronie default
    rc-update add elogind boot
}
enableservices || error "Error enabling Services"


passwdroot() {\
	printf "%s\n" "${bold}Input your desired password for root"
	passwd
}
passwdroot || error "Wrong password!"


cachefile() {
    printf "%s\n" "${bold}Creating cachefile to be included in initcpio"
    zpool set cachefile=/etc/zfs/zpool.cache rpool_$INST_UUID
    zpool set cachefile=/etc/zfs/zpool.cache bpool_$INST_UUID
}
cachefile || error "Failed to generate cachefile"


regenerate_initcpio() {
   	printf "%s\n" "${bold}Regenerating initramfs"
    mkinitcpio -P
}
regenerate_initcpio || error "Error generating initcpio!!"


printf "%s\n" "Finish!"