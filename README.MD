## Install any debian based distro on rooted android

### Requirements:

  1. Rooted Device

  2. Termux (from fdroid store)

  3. Busybox ( Prefer Magisk module - 'Busybox for android NDK' )

  4. git - installed in termux to clone repository (pkg install git)

### Steps: 

1. Clone repository in termux 
```
git clone https://github.com/NurMd07/linux-distro-android.git
```

2. Change dir to linux-distros-android
```
cd linux-distro-android
```

3. Giving execute permissions to 'install.sh' script
```
chmod +x ./install.sh
```

4. Run install.sh script to initiate installation process
```
./install.sh
```

5. Give which distro to install base image url in formate tar.gz , 
 Search ' DistroName:Version base image ' to get base image download url 
 e.g https://cdimage.ubuntu.com/ubuntu-base/releases/jammy/release/ubuntu-base-22.04-base-arm64.tar.gz (for ubuntu 22.04)
 
After providing info it will automatically install distro to your specified 
 directory e.g /data/local/tmp/ubuntu

It will add startup script to your shell automatically,

6. Start your distro (replace after _ part with your specified installed foldername)
```
start_foldername
``` 
e.g start_ubuntu for /data/local/tmp/ubuntu 

(You can check foldername in /data/local/tmp or in .bashrc or .zshrc ending line)

### Done.

### Uninstall: 

  currently uninstall script not added , 

You can menually remove dir from /data/local/tmp/destrofoldername
and remove single line alias from .bashrc or .zshrc last line.


