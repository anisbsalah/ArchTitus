#!/usr/bin/env bash
#
# @file Setup
# @brief Configures installed system, installs base packages, and creates user.

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
echo "[*] sourcing '${HOME}/ArchTitus/configs/setup.conf'..."
source "${HOME}/ArchTitus/configs/setup.conf"

echo "
--------------------------------------------------------------------------
 Network Setup
--------------------------------------------------------------------------
"
pacman -S --noconfirm --needed networkmanager dhclient
systemctl enable --now NetworkManager

echo "
--------------------------------------------------------------------------
 Setting up mirrors for optimal download
--------------------------------------------------------------------------
"
pacman -S --noconfirm --needed curl git pacman-contrib reflector rsync
pacman -S --noconfirm --needed arch-install-scripts
cp -v /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak

nc=$(grep -c ^processor /proc/cpuinfo) # nc=$(nproc)
echo "
--------------------------------------------------------------------------
 You have ${nc} cores. And changing the makeflags for ${nc} cores.
 Aswell as changing the compression settings.
--------------------------------------------------------------------------
"
TOTAL_MEM=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
if [[ ${TOTAL_MEM} -gt 8000000 ]]; then
	sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j${nc}\"/g" /etc/makepkg.conf
	sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T ${nc} -z -)/g" /etc/makepkg.conf
fi

echo "
--------------------------------------------------------------------------
 Setup Language to US and set locale
--------------------------------------------------------------------------
"
ln -s "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime

sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

{
	echo 'LANG=en_US.UTF-8'
	echo 'LC_TIME=C'
} >>/etc/locale.conf

# Set console font and keymap
echo "KEYMAP=${KEYMAP}" >>/etc/vconsole.conf
echo 'FONT=ter-v18b' >>/etc/vconsole.conf

echo "
--------------------------------------------------------------------------
 Add sudo no password rights
--------------------------------------------------------------------------
"
# Add sudo no password rights
sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

echo "
--------------------------------------------------------------------------
 Configure pacman
--------------------------------------------------------------------------
"
# Add color
sed -i 's/^#Color/Color\nILoveCandy/' /etc/pacman.conf

# Add parallel downloading
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

# Enable multilib
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Sy --noconfirm --needed

echo "
--------------------------------------------------------------------------
 Installing Base System
--------------------------------------------------------------------------
"
# sed $INSTALL_TYPE is using install type to check for MINIMAL installation, if it's true, stop
# stop the script and move on, not installing any more packages below that line
if [[ ${DESKTOP_ENV} != server ]]; then
	sed -n '/'${INSTALL_TYPE}'/q;p' "${HOME}/ArchTitus/pkg-files/pacman-pkgs.txt" | while read line; do
		if [[ ${line} == '--END OF MINIMAL INSTALL--' ]]; then
			# If selected installation type is FULL, skip the --END OF THE MINIMAL INSTALLATION-- line
			continue
		fi
		echo "INSTALLING: ${line}"
		sudo pacman -S --noconfirm --needed "${line}"
	done
fi

echo "
--------------------------------------------------------------------------
 Installing Microcode
--------------------------------------------------------------------------
"
# determine processor type and install microcode
proc_type=$(lscpu)
if grep -E "GenuineIntel" <<<"${proc_type}"; then
	echo "Installing Intel microcode"
	pacman -S --noconfirm --needed intel-ucode
	proc_ucode=intel-ucode.img
elif grep -E "AuthenticAMD" <<<"${proc_type}"; then
	echo "Installing AMD microcode"
	pacman -S --noconfirm --needed amd-ucode
	proc_ucode=amd-ucode.img
fi

echo "
--------------------------------------------------------------------------
 Installing Graphics Drivers
--------------------------------------------------------------------------
"
# Graphics Drivers find and install
gpu_type=$(lspci | grep -A1 -e VGA -e 3D)
if grep -E "NVIDIA|GeForce" <<<"${gpu_type}"; then
	pacman -S --noconfirm --needed nvidia
	nvidia-xconfig
elif grep -E "Radeon|AMD" <<<"${gpu_type}"; then
	pacman -S --noconfirm --needed xf86-video-amdgpu
elif grep -E "Integrated Graphics Controller" <<<"${gpu_type}"; then
	pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils
elif grep -E "Intel Corporation UHD" <<<"${gpu_type}"; then
	pacman -S --needed --noconfirm libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils
fi

echo "
--------------------------------------------------------------------------
 Installing Wireless Card Drivers
--------------------------------------------------------------------------
"
# Wireless Card Drivers find and install
wireless_card=$(lspci | grep -i network)
if grep -E "Broadcom" <<<"${wireless_card}"; then
	if grep -E "BCM43" <<<"${wireless_card}"; then
		pacman -S --noconfirm --needed dkms broadcom-wl-dkms
	fi
else
	echo "Nothing to do."
fi

# IF SETUP IS WRONG THIS IS RUN
if ! source "${HOME}/ArchTitus/configs/setup.conf"; then
	# Loop through user input until the user gives a valid username
	while true; do
		read -erp "Please enter username:" username
		# username regex per response here https://unix.stackexchange.com/questions/157426/what-is-the-regex-to-validate-linux-users
		# lowercase the username to test regex
		if [[ ${username,,} =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]; then
			break
		fi
		echo "Incorrect username."
	done

	# convert name to lowercase before saving to setup.conf
	echo "username=${username,,}" >>"${HOME}/ArchTitus/configs/setup.conf"

	# Set Password
	read -rep "Please enter password:" password
	echo "password=${password,,}" >>"${HOME}/ArchTitus/configs/setup.conf"

	# Loop through user input until the user gives a valid hostname, but allow the user to force save
	while true; do
		read -erp "Please name your machine:" name_of_machine
		# hostname regex (!!couldn't find spec for computer name!!)
		if [[ ${name_of_machine,,} =~ ^[a-z][a-z0-9_.-]{0,62}[a-z0-9]$ ]]; then
			break
		fi
		# if validation fails allow the user to force saving of the hostname
		read -erp "Hostname doesn't seem correct. Do you still want to save it? (y/n)" force
		if [[ ${force,,} == "y" ]]; then
			break
		fi
	done

	echo "NAME_OF_MACHINE=${name_of_machine,,}" >>"${HOME}/ArchTitus/configs/setup.conf"
fi

echo "
--------------------------------------------------------------------------
 Adding User
--------------------------------------------------------------------------
"
if [[ "$(whoami)" == "root" ]]; then
	useradd -m -g users -G audio,video,network,wheel,storage,rfkill -s /bin/bash "${USERNAME}"
	echo "${USERNAME} created, home directory created, added to audio,video,network,wheel,storage,rfkill groups, default shell set to: /bin/bash"

	# use chpasswd to enter $USERNAME:$password
	echo "${USERNAME}:${PASSWORD}" | chpasswd
	echo "${USERNAME} password set"

	cp -R "${HOME}/ArchTitus" "/home/${USERNAME}/"
	chown -R "${USERNAME}": "/home/${USERNAME}/ArchTitus"
	echo "'ArchTitus' copied to home directory"

	# enter $NAME_OF_MACHINE to /etc/hostname
	echo "${NAME_OF_MACHINE}" >/etc/hostname
else
	echo "You are already a user. Proceed with AUR installs"
fi

echo "
--------------------------------------------------------------------------
                        SYSTEM READY FOR 2-user.sh
--------------------------------------------------------------------------
"
sleep 1
clear
