#!/bin/sh

su -c "setenforce 0"

clear

if [ "$(whoami)" != "root" ]; then
     echo -e "\n [x] This script must be run as root. Exit"
     echo "Exiting ... "
     exit 1
fi

if [ ! -x /system/bin/busybox ] && [ ! -x /system/xbin/busybox ]; then
    echo -e "\n [x] Busybox is not present in system\n"
    echo "Exiting ... "
    exit 1
fi

HOME="$1"

error() {
    echo -e "\e[1;31m[x] Error: $1\e[0m"
    echo -e "\e[1;31m[x] Try again or restart device to remove files from /data/local/tmp\e[0m"
    exit 1
}

goodbye() {
    echo -e "\e[1;31m[!] Something went wrong. Exiting...\e[0m"
    exit 1
}

progress() {
    echo -e "\e[1;36m[+] $1\e[0m"
}

success() {
    echo -e "\e[1;32m[✓] $1\e[0m"
}

userinput() {
    progress "Provide Your Preference/Settings ... \n "
    
    echo -e "\e[1;33mEnter new user name: \e[0m"
    read username
    [ -z "$username" ] && error "Username cannot be empty."
    
    echo -e "\e[1;33m\nEnter new user password: \e[0m"
    read password
    [ -z "$password" ] && error "Password cannot be empty."
    
    echo -e "\e[1;33m\nDistro FolderName: \e[0m"
    read foldername
    [ -z "$foldername" ] && error "Folder name cannot be empty."
    
    echo -e "\e[1;33m\nEnter distro download url: \e[0m"
    read url
    [ -z "$url" ] && error "URL cannot be empty."
    
    success "Successfully got all Preferences/Settings"
}

preparing() {
    progress "Preparing ... "
    mkdir -p /data/local/tmp/$foldername || error "Failed to create directory."
    cd /data/local/tmp/$foldername || goodbye
    success "Successfully Prepared"
}

downloading() {
    progress "Downloading distro ... "
    distrofile="${url##*/}"

    if [ ! -f "$distrofile" ]; then
        wget "$url" || error "Failed to download distro."
    else
        REMOTE_SIZE=$(curl -sI "$url" | grep -i Content-Length | awk '{print $2}' | tr -d '\r')
        FILE_SIZE=$(stat -c %s "$distrofile")
        
        if [ "$FILE_SIZE" -ne "$REMOTE_SIZE" ]; then
            rm "$distrofile" || error "Failed to remove old distro file."
            wget "$url" || error "Failed to download updated distro."
        fi
    fi
    success "Successfully Downloaded Distro"
}

extracting() {
     progress "Extracting Distro Files ..."
     tar xpvf "$distrofile" --numeric-owner --overwrite || error "Failed to extract distro files."
     success "Successfully Extracted Distro Files"
}

settingup() {
    progress "Setting Up Mounts And Paths ... "
    UBUNTUPATH="/data/local/tmp/$foldername"

    mkdir -p $UBUNTUPATH/sdcard || error "Failed to create sdcard directory."

    busybox mount -o remount,dev,suid /data || error "Failed to remount /data."

    busybox mount --bind /dev $UBUNTUPATH/dev || error "Failed to mount /dev."
    busybox mount --bind /sys $UBUNTUPATH/sys || error "Failed to mount /sys."
    busybox mount --bind /proc $UBUNTUPATH/proc || error "Failed to mount /proc."
    busybox mount -t devpts devpts $UBUNTUPATH/dev/pts || error "Failed to mount devpts."

    mkdir -p $UBUNTUPATH/dev/shm || error "Failed to create dev/shm directory."

    busybox mount -t tmpfs -o size=256M tmpfs $UBUNTUPATH/dev/shm || error "Failed to mount tmpfs."

    busybox mount --bind /sdcard $UBUNTUPATH/sdcard || error "Failed to mount /sdcard."
    success "Successfully set Mounts and Paths"
}

settingupdistro() {
    progress "Setting Up distro ... "
    busybox chroot $UBUNTUPATH /bin/su - root -c "\
        echo 'nameserver 8.8.8.8' > /etc/resolv.conf; \
        echo '127.0.0.1 localhost' > /etc/hosts; \
        groupadd -g 3003 aid_inet; \
        groupadd -g 3004 aid_net_raw; \
        groupadd -g 1003 aid_graphics; \
        usermod -g 3003 -G 3003,3004 -a _apt; \
        usermod -G 3003 -a root; \
        apt update; \
        apt upgrade -y; \
        apt install nano vim net-tools sudo git -y; \
        ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime; \
        apt install locales; \
        locale-gen en_US.UTF-8; \
        apt-get autopurge snapd " || error "Failed to set up distro."

busybox chroot $UBUNTUPATH /bin/su - root -c "\

cat <<EOF | sudo tee /etc/apt/preferences.d/nosnap.pref
# To prevent repository packages from triggering the installation of Snap,
# this file forbids snapd from being installed by APT.
# For more information: https://linuxmint-user-guide.readthedocs.io/en/latest/snap.html
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

"
    success "Successfully set up Distro"
}

addinguser() {
   progress "Adding new user ..."
    busybox chroot $UBUNTUPATH /bin/env username="$username" password="$password" /bin/su - root -c "\
        adduser --disabled-password --gecos '' '$username'; \
        echo '$username:$password' | chpasswd; \
        groupadd storage; \
        groupadd wheel; \
        usermod -aG wheel,audio,video,storage,aid_inet '$username'; \
        echo '$username ALL=(ALL:ALL) ALL' >> /etc/sudoers;" || error "Failed to add new user."
    echo ""
    success "New User added Successfully"
}

cleanup() {
    progress "Cleaning up ... "
    busybox umount $UBUNTUPATH/dev/shm || error "Failed to unmount /dev/shm."
    busybox umount $UBUNTUPATH/dev/pts || error "Failed to unmount /dev/pts."
    busybox umount $UBUNTUPATH/dev || error "Failed to unmount /dev."
    busybox umount $UBUNTUPATH/proc || error "Failed to unmount /proc."
    busybox umount $UBUNTUPATH/sys || error "Failed to unmount /sys."
    busybox umount $UBUNTUPATH/sdcard || error "Failed to unmount /sdcard."
    success "Exited Successfully"
}

addtopath() {
alias_command="alias start_$foldername='su -c \"/data/local/tmp/start_$foldername.sh\"'"
alias_name="start_$foldername"

bash_file="$HOME/.bashrc"
zsh_file="$HOME/.zshrc"
profile_file="$HOME/.profile"

add_alias() {
  file=$1
  if [ -f "$file" ]; then
    if ! grep -q "$alias_name" "$file"; then
      echo "$alias_command" >> "$file"
    fi
  fi
}

add_alias "$bash_file"
add_alias "$zsh_file"
add_alias "$profile_file"
}

startingup() {
    echo ""
    progress "Starting User Script 'start_$foldername.sh' and distro dir located at \n /data/local/tmp\n"
    progress "Just Type 'start_$foldername' to start distro\n"
    progress "Restart Termux to Use 'start_$foldername' command\n"
    success "Starting Up User Session ... "
    echo ""
    su -c "/data/local/tmp/start_$foldername.sh" || error "Failed to start user session."
}

setupstartingscript() {
    scriptname="/data/local/tmp/start_$foldername.sh"
    cat <<EOF > "$scriptname"
#!/bin/sh

su -c "setenforce 0"

UBUNTUPATH="$UBUNTUPATH"
USERNAME="$username"

busybox mount -o remount,dev,suid /data

busybox mount --bind /dev $UBUNTUPATH/dev
busybox mount --bind /sys $UBUNTUPATH/sys
busybox mount --bind /proc $UBUNTUPATH/proc
busybox mount -t devpts devpts $UBUNTUPATH/dev/pts

mkdir -p $UBUNTUPATH/dev/shm

busybox mount -t tmpfs -o size=256M tmpfs $UBUNTUPATH/dev/shm

busybox mount --bind /sdcard $UBUNTUPATH/sdcard

command="\$1"

if [ -n "\$command" ]; then
    busybox chroot $UBUNTUPATH /bin/su - \$USERNAME -c "\$command"
else
    busybox chroot $UBUNTUPATH /bin/su - \$USERNAME
fi

busybox umount $UBUNTUPATH/dev/shm
busybox umount $UBUNTUPATH/dev/pts
busybox umount $UBUNTUPATH/dev
busybox umount $UBUNTUPATH/proc
busybox umount $UBUNTUPATH/sys
busybox umount $UBUNTUPATH/sdcard
EOF

    chmod +x "$scriptname"
}

main() {
    userinput
    preparing
    downloading
    extracting
    settingup
    settingupdistro
    addinguser
    setupstartingscript
    addtopath
    startingup
}

echo ""
echo -e "\e[33m$ \e[32mInstall Any Distro in Chroot Android \e[33m$"
echo ""
echo -e "        \e[1;37m---- \e[1;35mBy NurMd\e[1;37m ----\e[32m"
echo -e "\e[0m"

main
