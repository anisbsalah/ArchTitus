#!/usr/bin/env bash
#
# @file Preinstall
# @brief Contains the steps necessary to configure and pacstrap the install to selected drive.

echo "
--------------------------------------------------------------------------
   █████╗ ██████╗  ██████╗██╗  ██╗████████╗██╗████████╗██╗   ██╗███████╗
  ██╔══██╗██╔══██╗██╔════╝██║  ██║╚══██╔══╝██║╚══██╔══╝██║   ██║██╔════╝
  ███████║██████╔╝██║     ███████║   ██║   ██║   ██║   ██║   ██║███████╗
  ██╔══██║██╔══██╗██║     ██╔══██║   ██║   ██║   ██║   ██║   ██║╚════██║
  ██║  ██║██║  ██║╚██████╗██║  ██║   ██║   ██║   ██║   ╚██████╔╝███████║
  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚═╝   ╚═╝    ╚═════╝ ╚══════╝
--------------------------------------------------------------------------
                      Automated Arch Linux Installer
--------------------------------------------------------------------------
"
echo "[*] sourcing '${CONFIGS_DIR}/setup.conf'..."
source "${CONFIGS_DIR}/setup.conf"

echo "
--------------------------------------------------------------------------
 Installing Prerequisites
--------------------------------------------------------------------------
"
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
sed -i 's/^#Color/Color\nILoveCandy/' /etc/pacman.conf

pacman -S --noconfirm archlinux-keyring # update keyrings to latest to prevent packages failing to install
pacman -S --noconfirm --needed gptfdisk btrfs-progs glibc
pacman -S --noconfirm --needed pacman-contrib reflector
pacman -S --noconfirm --needed terminus-font

timedatectl set-ntp true
setfont ter-v18b

iso=$(curl -4 ifconfig.co/country-iso)
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
echo "
--------------------------------------------------------------------------
 Setting up ${iso} mirrors for faster downloads
--------------------------------------------------------------------------
"
reflector -a 48 -c "${iso}" -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist

mkdir /mnt &>/dev/null # Hiding error message if any
echo "
--------------------------------------------------------------------------
 Formating Disk
--------------------------------------------------------------------------
"
# make sure everything is unmounted before we start
umount -A --recursive /mnt

# disk prep
sgdisk -Z "${DISK}"         # zap all on disk
sgdisk -a 2048 -o "${DISK}" # new gpt disk 2048 alignment

# create partitions
sgdisk -n 1::+1M --typecode=1:ef02 --change-name=1:'BIOSBOOT' "${DISK}"   # partition 1 (BIOS Boot Partition)
sgdisk -n 2::+1024M --typecode=2:ef00 --change-name=2:'EFIBOOT' "${DISK}" # partition 2 (UEFI Boot Partition)
sgdisk -n 3::-0 --typecode=3:8300 --change-name=3:'ROOT' "${DISK}"        # partition 3 (Root), default start, remaining
if [[ ! -d "/sys/firmware/efi" ]]; then                                   # Checking for bios system
	sgdisk -A 1:set:2 "${DISK}"
fi
partprobe "${DISK}" # reread partition table to ensure it is correct

# make filesystems
echo "
--------------------------------------------------------------------------
 Creating Filesystems
--------------------------------------------------------------------------
"
# @description Creates the btrfs subvolumes.
createsubvolumes() {
	btrfs subvolume create /mnt/@
	btrfs subvolume create /mnt/@home
	btrfs subvolume create /mnt/@snapshots
	btrfs subvolume create /mnt/@swap
	btrfs subvolume create /mnt/@tmp
	btrfs subvolume create /mnt/@var
}

# @description Mount all btrfs subvolumes after root has been mounted.
mountallsubvol() {
	mount -o "${MOUNT_OPTIONS}",subvol=@home "${partition3}" /mnt/home
	mount -o "${MOUNT_OPTIONS}",subvol=@snapshots "${partition3}" /mnt/.snapshots
	mount -o "${MOUNT_OPTIONS}",subvol=@swap "${partition3}" /mnt/swap
	mount -o "${MOUNT_OPTIONS}",subvol=@tmp "${partition3}" /mnt/tmp
	mount -o "${MOUNT_OPTIONS}",subvol=@var "${partition3}" /mnt/var
}

# @description BTRFS subvolumes creation and mounting.
subvolumesetup() {
	# create nonroot subvolumes
	createsubvolumes
	# unmount root to remount with subvolume
	umount /mnt
	# mount @ subvolume
	mount -o "${MOUNT_OPTIONS}",subvol=@ "${partition3}" /mnt
	# make directories home, .snapshots, swap, tmp, var
	mkdir -p /mnt/{home,.snapshots,swap,tmp,var}
	# mount subvolumes
	mountallsubvol
}

if [[ ${DISK} =~ "nvme" ]]; then
	partition2="${DISK}p2"
	partition3="${DISK}p3"
else
	partition2="${DISK}2"
	partition3="${DISK}3"
fi

if [[ ${FS} == "btrfs" ]]; then
	mkfs.vfat -F32 -n "EFIBOOT" "${partition2}"
	mkfs.btrfs -f -L ROOT "${partition3}"
	mount -t btrfs "${partition3}" /mnt
	subvolumesetup
elif [[ ${FS} == "ext4" ]]; then
	mkfs.vfat -F32 -n "EFIBOOT" "${partition2}"
	mkfs.ext4 -F -L ROOT "${partition3}"
	mount -t ext4 "${partition3}" /mnt
fi

# mount target
mkdir -p /mnt/boot/efi
mount -t vfat -L EFIBOOT /mnt/boot

if ! grep -qs '/mnt' /proc/mounts; then
	echo "Drive is not mounted! Can not continue."
	echo "Rebooting in 3 Seconds ..." && sleep 1
	echo "Rebooting in 2 Seconds ..." && sleep 1
	echo "Rebooting in 1 Second ..." && sleep 1
	reboot now
fi

echo "
--------------------------------------------------------------------------
 Arch Install on Main Drive
--------------------------------------------------------------------------
"
pacstrap -K /mnt base base-devel linux linux-firmware btrfs-progs grub nano sudo wget bash-completion terminus-font --noconfirm --needed
echo "keyserver hkp://keyserver.ubuntu.com" >>/mnt/etc/pacman.d/gnupg/gpg.conf
cp -R "${SCRIPT_DIR}" /mnt/root/ArchTitus
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

genfstab -U /mnt >>/mnt/etc/fstab
echo " 
  Generated /etc/fstab:
"
cat /mnt/etc/fstab

echo "
--------------------------------------------------------------------------
 GRUB BIOS Bootloader Install & Check
--------------------------------------------------------------------------
"
if [[ ! -d "/sys/firmware/efi" ]]; then
	grub-install --boot-directory=/mnt/boot "${DISK}"
else
	pacstrap /mnt efibootmgr dosfstools --noconfirm --needed
fi

echo "
--------------------------------------------------------------------------
 Checking for low memory systems <8G
--------------------------------------------------------------------------
"
# TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
# SWAPFILE_SIZE=$(free -m -t | awk 'NR == 2 {print $2}') # Equal to ram size (in MiB)
TOTAL_MEM=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
if [[ ${TOTAL_MEM} -lt 8000000 ]]; then
	# Put swap into the actual system, not into RAM disk, otherwise there is no point in it, it'll cache RAM into RAM. So, /mnt/ everything.
	if [[ ${FS} == "btrfs" ]]; then
		btrfs filesystem mkswapfile --size 4096M --uuid clear /mnt/swap/swapfile
		swapon /mnt/swap/swapfile
		echo "/swap/swapfile    none    swap    defaults  0   0" >>/mnt/etc/fstab
	elif [[ ${FS} == "ext4" ]]; then
		dd if=/dev/zero of=/mnt/swapfile bs=1M count=4096 status=progress # Create a 4GiB swap file
		chmod 600 /mnt/swapfile                                           # Set permissions
		mkswap -U clear /mnt/swapfile                                     # Format the file to swap
		swapon /mnt/swapfile                                              # Activate the swap file
		# The line below is written to /mnt/ but doesn't contain /mnt/, since it's just / for the system itself.
		echo "/swapfile    none    swap    defaults  0   0" >>/mnt/etc/fstab # Add swap to fstab, so it KEEPS working after installation.
	fi
fi

#### This method works for both btrfs and ext4 ( from ArchTitus )
#TOTAL_MEM=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
#if [[ ${TOTAL_MEM} -lt 8000000 ]]; then
#	# Put swap into the actual system, not into RAM disk, otherwise there is no point in it, it'll cache RAM into RAM. So, /mnt/ everything.
#	mkdir -p /mnt/opt/swap  # make a dir that we can apply NOCOW to to make it btrfs-friendly.
#	chattr +C /mnt/opt/swap # apply NOCOW, btrfs needs that.
#	dd if=/dev/zero of=/mnt/opt/swap/swapfile bs=1M count=2048 status=progress
#	chmod 600 /mnt/opt/swap/swapfile # set permissions.
#	chown root /mnt/opt/swap/swapfile
#	mkswap /mnt/opt/swap/swapfile
#	swapon /mnt/opt/swap/swapfile
#	# The line below is written to /mnt/ but doesn't contain /mnt/, since it's just / for the system itself.
#	echo "/opt/swap/swapfile	none	swap	sw	0	0" >>/mnt/etc/fstab # Add swap to fstab, so it KEEPS working after installation.
#fi

#### This method works for both btrfs and ext4 (from arch wiki)
#if [[ ${TOTAL_MEM} -lt 8000000 ]]; then
#	mkdir -p /mnt/swap
#	truncate -s 0 /mnt/swap/swapfile
#	chattr +C /mnt/swap/swapfile
#	fallocate -l 4096M /mnt/swap/swapfile
#	chmod 0600 /mnt/swap/swapfile
#	mkswap /mnt/swap/swapfile
#	swapon /mnt/swap/swapfile
#	echo "/swap/swapfile	none	swap	defaults	0	0" >>/mnt/etc/fstab
#fi

echo "
--------------------------------------------------------------------------
                       SYSTEM READY FOR 1-setup.sh
--------------------------------------------------------------------------
"
sleep 1
clear
