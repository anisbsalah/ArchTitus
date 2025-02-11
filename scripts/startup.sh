#!/usr/bin/env bash
#
# @file Startup
# @brief This script will ask users about their prefrences like disk, file system, timezone, keyboard layout, user name, password, etc.
# @stdout Output routed to startup.log
# @stderror Output routed to startup.log

# @setting-header General Settings
# @setting CONFIG_FILE string[$CONFIGS_DIR/setup.conf] Location of setup.conf to be used by set_option and all subsequent scripts.
CONFIG_FILE=${CONFIGS_DIR}/setup.conf
if [[ ! -f ${CONFIG_FILE} ]]; then # check if file exists
	mkdir -p "${CONFIGS_DIR}"
	touch -f "${CONFIG_FILE}" # create file if not exists
fi

# @description set options in setup.conf
# @arg $1 string Configuration variable.
# @arg $2 string Configuration value.
set_option() {
	if grep -Eq "^${1}.*" "${CONFIG_FILE}"; then # check if option exists
		sed -i -e "/^${1}.*/d" "${CONFIG_FILE}"     # delete option if exists
	fi
	echo "${1}=${2}" >>"${CONFIG_FILE}" # add option
}

set_password() {
	read -rs -p "Please enter password: " PASSWORD1
	echo
	read -rs -p "Please confirm password: " PASSWORD2
	echo
	if [[ ${PASSWORD1} == "${PASSWORD2}" ]]; then
		set_option "$1" "${PASSWORD1}"
	else
		echo "ERROR! Passwords do not match."
		set_password
	fi
}

root_check() {
	if [[ "$(id -u)" != "0" ]]; then
		echo "ERROR! This script must be run under the 'root' user."
		exit 0
	fi
}

docker_check() {
	if awk -F/ '$2 == "docker"' /proc/self/cgroup | read -r; then
		echo "ERROR! Docker container is not supported (at the moment)"
		exit 0
	elif [[ -f /.dockerenv ]]; then
		echo "ERROR! Docker container is not supported (at the moment)"
		exit 0
	fi
}

arch_check() {
	if [[ ! -e /etc/arch-release ]]; then
		echo "ERROR! This script must be run in Arch Linux."
		exit 0
	fi
}

pacman_check() {
	if [[ -f /var/lib/pacman/db.lck ]]; then
		echo "ERROR! Pacman is blocked."
		echo "If not running, remove: /var/lib/pacman/db.lck"
		exit 0
	fi
}

background_checks() {
	root_check
	arch_check
	pacman_check
	docker_check
}

# Renders a text based list of options that can be selected by the
# user using up, down and enter keys and returns the chosen option.
#
#   Arguments   : list of options, maximum of 256
#                 "opt1" "opt2" ...
#   Return value: selected index (0 for opt1, 1 for opt2 ...)
select_option() {

	# little helpers for terminal print control and key input
	ESC=$(printf "\033")
	cursor_blink_on() { printf "$ESC[?25h"; }
	cursor_blink_off() { printf "$ESC[?25l"; }
	cursor_to() { printf "$ESC[$1;${2:-1}H"; }
	print_option() { printf "$2   $1 "; }
	print_selected() { printf "$2  $ESC[7m $1 $ESC[27m"; }
	get_cursor_row() {
		IFS=';' read -sdR -p $'\E[6n' ROW COL
		echo "${ROW#*[}"
	}
	get_cursor_col() {
		IFS=';' read -sdR -p $'\E[6n' ROW COL
		echo "${COL#*[}"
	}
	key_input() {
		local key
		IFS= read -rsn1 key 2>/dev/null >&2
		if [[ ${key} == "" ]]; then echo enter; fi
		if [[ ${key} == $'\x20' ]]; then echo space; fi
		if [[ ${key} == "k" ]]; then echo up; fi
		if [[ ${key} == "j" ]]; then echo down; fi
		if [[ ${key} == "h" ]]; then echo left; fi
		if [[ ${key} == "l" ]]; then echo right; fi
		if [[ ${key} == "a" ]]; then echo all; fi
		if [[ ${key} == "n" ]]; then echo none; fi
		if [[ ${key} == $'\x1b' ]]; then
			read -rsn2 key
			if [[ ${key} == [A || ${key} == k ]]; then echo up; fi
			if [[ ${key} == [B || ${key} == j ]]; then echo down; fi
			if [[ ${key} == [C || ${key} == l ]]; then echo right; fi
			if [[ ${key} == [D || ${key} == h ]]; then echo left; fi
		fi
	}
	print_options_multicol() {
		# print options by overwriting the last lines
		local curr_col=$1
		local curr_row=$2
		local curr_idx=0

		local idx=0
		local row=0
		local col=0

		curr_idx=$((curr_col + curr_row * colmax))

		for option in "${options[@]}"; do

			row=$((idx / colmax))
			col=$((idx - row * colmax))

			cursor_to $((startrow + row + 1)) $((offset * col + 1))
			if [[ ${idx} -eq ${curr_idx} ]]; then
				print_selected "${option}"
			else
				print_option "${option}"
			fi
			((idx++))
		done
	}

	# initially print empty new lines (scroll down if at bottom of screen)
	for opt; do printf "\n"; done

	# determine current screen position for overwriting the options
	local return_value=$1
	local lastrow=$(get_cursor_row)
	local lastcol=$(get_cursor_col)
	local startrow=$((lastrow - $#))
	local startcol=1
	local lines=$(tput lines)
	local cols=$(tput cols)
	local colmax=$2
	local offset=$((cols / colmax))

	local size=$4
	shift 4

	# ensure cursor and input echoing back on upon a ctrl+c during read -s
	trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
	cursor_blink_off

	local active_row=0
	local active_col=0
	while true; do
		print_options_multicol "${active_col}" "${active_row}"
		# user key control
		case $(key_input) in
		enter) break ;;
		up)
			((active_row--))
			if [[ ${active_row} -lt 0 ]]; then active_row=0; fi
			;;
		down)
			((active_row++))
			if [[ ${active_row} -ge $((${#options[@]} / colmax)) ]]; then active_row=$((${#options[@]} / colmax)); fi
			;;
		left)
			((active_col = active_col - 1))
			if [[ ${active_col} -lt 0 ]]; then active_col=0; fi
			;;
		right)
			((active_col = active_col + 1))
			if [[ ${active_col} -ge ${colmax} ]]; then active_col=$((colmax - 1)); fi
			;;
		esac
	done

	# cursor position back to normal
	cursor_to "${lastrow}"
	printf "\n"
	cursor_blink_on

	return $((active_col + active_row * colmax))
}

# @description Displays Arch logo
# @noargs
logo() {
	# This will be shown on every set as user is progressing
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
             Please select pre-setup settings for your system
--------------------------------------------------------------------------"
}

# @description This function will handle file systems. At this movement we are handling only
# btrfs and ext4. Others will be added in future.
filesystem() {
	echo "
Please select the appropriate file system for both boot and root:"

	options=("btrfs" "ext4")
	select_option $? 1 "${options[@]}"

	case $? in
	0) set_option FS btrfs ;;
	1) set_option FS ext4 ;;
	*)
		echo "Wrong option. Please select again."
		filesystem
		;;
	esac
}

# @description Detects and sets timezone.
timezone() {
	# Added this from arch wiki https://wiki.archlinux.org/title/System_time
	time_zone="$(curl --fail https://ipapi.co/timezone)"

	echo "
System detected your timezone to be '${time_zone}'"
	echo "Is this correct?"

	options=("Yes" "No")
	select_option $? 1 "${options[@]}"

	case ${options[$?]} in
	y | Y | yes | Yes | YES)
		echo "${time_zone} set as timezone"
		set_option TIMEZONE "${time_zone}"
		;;
	n | N | no | NO | No)
		echo "Please enter your desired timezone (e.g. Africa/Tunis):"
		read -re new_timezone
		echo "${new_timezone} set as timezone"
		set_option TIMEZONE "${new_timezone}"
		;;
	*)
		echo "Wrong option. Try again."
		timezone
		;;
	esac
}

# @description Set user's keyboard mapping.
keymap() {
	echo "
Please select your keyboard layout from this list:"
	# These are default key maps as presented in official arch repo archinstall
	options=("us" "by" "ca" "cf" "cz" "de" "dk" "es" "et" "fa" "fi" "fr" "gr" "hu" "il" "it" "lt" "lv" "mk" "nl" "no" "pl" "ro" "ru" "sg" "ua" "uk")
	select_option $? 4 "${options[@]}"
	keymap=${options[$?]}
	echo "Your keyboard layout: ${keymap}"
	set_option KEYMAP "${keymap}"
}

# @description Choose whether drive is SSD or not.
drivessd() {
	echo "Is this an ssd?:"
	options=("Yes" "No")
	select_option $? 1 "${options[@]}"

	case ${options[$?]} in
	y | Y | yes | Yes | YES)
		set_option MOUNT_OPTIONS "noatime,compress=zstd,ssd,commit=120"
		;;
	n | N | no | NO | No)
		set_option MOUNT_OPTIONS "noatime,compress=zstd,commit=120"
		;;
	*)
		echo "Wrong option. Try again."
		drivessd
		;;
	esac
}

# @description Disk selection for drive to be used with installation.
diskpart() {
	echo "
------------------------------------------------------------
 THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK.
 Please make sure you know what you are doing because after
 formating your disk there is no way to get data back.
------------------------------------------------------------
"
	printf 'Please select the disk to install Arch Linux on:\n'
	options=($(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2"|"$3}'))
	select_option $? 1 "${options[@]}"
	disk=${options[$?]%|*}
	printf "You selected: %s \n" "${disk%|*}"
	set_option DISK "${disk%|*}"

	drivessd
}

# @description Gather username and password to be used for installation.
userinfo() {
	printf "\n"
	read -rep "Please enter your username: " username
	set_option USERNAME "${username,,}" # convert to lower case as in issue #109
	set_password "PASSWORD"
	read -rep "Please enter your hostname: " nameofmachine
	set_option NAME_OF_MACHINE "${nameofmachine}"
}

# @description Choose AUR helper.
aurhelper() {
	# Let the user choose AUR helper from predefined list
	echo "
Please enter your desired AUR helper:"
	options=("yay" "yay-bin" "paru" "paru-bin" "trizen" "pikaur" "pakku" "aurman" "aura" "none")
	select_option $? 5 "${options[@]}"
	aur_helper=${options[$?]}
	set_option AUR_HELPER "${aur_helper}"
}

# @description Choose Desktop Environment
desktopenv() {
	# Let the user choose Desktop Enviroment from predefined list
	echo "
Please select your desired Desktop Enviroment:"
	options=($(for f in pkg-files/*.txt; do echo "$f" | sed -r "s/.+\/(.+)\..+/\1/;/pkgs/d"; done))
	select_option $? 8 "${options[@]}"
	desktop_env=${options[$?]}
	set_option DESKTOP_ENV "${desktop_env}"
}

# @description Choose whether to do full or minimal installation.
installtype() {
	printf "\nPlease select type of installation:\n
 * Full Install: Installs full featured desktop enviroment, with added apps and themes needed for everyday use.
 * Minimal Install: Installs only few selected apps to get you started.\n"
	options=(FULL MINIMAL)
	select_option $? 1 "${options[@]}"
	install_type=${options[$?]}
	set_option INSTALL_TYPE "${install_type}"
}

### Starting functions
background_checks
clear
logo
userinfo
clear
logo
desktopenv
# Set fixed options in case of server installation
set_option INSTALL_TYPE MINIMAL
set_option AUR_HELPER none
if [[ ${desktop_env} != server ]]; then
	clear
	logo
	aurhelper
	clear
	logo
	installtype
fi
clear
logo
diskpart
clear
logo
filesystem
clear
logo
timezone
clear
logo
keymap
clear
