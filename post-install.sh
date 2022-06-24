#!/bin/sh

set -e

# Upgrade Debian to Sid adding contrib and non-free repositories, install
# Qualcomm Atheros QCA6174 802.11ac Wireless Network Adapter and Windows NTFS
# file system non-free firmwares, setup ifupdown network interfaces with WPA
# authentication and IPv6 temporary addresses (privacy extension) support,
# nftables firewall, install XOrg, Openbox, Firefox and SciTE text editor.

# NOTE: Sid exclusively gets security updates through its package
# maintainers. The Debian Security Team only maintains security updates
# for the current "stable" release.
# See <https://wiki.debian.org/DebianUnstable>.

WPA_SSID="ATM 2G"
WPA_PSK=""

# Show help.

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
	echo "${0##*/} - Upgrade to sid, install wireless and file system non-free"
	echo "firmware, setup XOrg, Openbox, Firefox and SciTE text editor."
	echo
	echo "Usage: ${0##*/} [OPTIONS]"
	echo
	echo "Options:"
	echo "  -h, --help                            Show this help message and exit"
	echo
	exit
fi

# Get user confirmation.

echo "WARNING! This will make changes on your computer."
read -p "Do you want to continue? [Y/n] " RESP

if [ "${RESP#[Nn]}" != "$RESP" ]; then
	echo "Abort."
	exit
fi

# Update Debian if NOT update since 1 hour.

#test $(stat --format '%Y' /var/cache/apt/) -ge $(date --date '1 hour ago' '+%s') &&
find /var/cache/apt/ -maxdepth 0 -mmin +60 | grep --quiet ^ &&
	sudo apt update &&
	sudo apt upgrade --yes &&
	sudo apt autoremove --yes

# Upgrade to sid.

sudo cp --no-clobber /etc/apt/sources.list /etc/apt/sources.list.bak

! grep --quiet sid /etc/apt/sources.list && sudo tee /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian/ sid main non-free contrib
deb-src http://deb.debian.org/debian/ sid main non-free contrib
EOF

#cat /etc/apt/sources.list 

! grep --quiet sid /etc/debian_version &&
	sudo apt clean &&
	sudo apt update &&
	sudo apt full-upgrade --yes &&
	sudo apt autoremove --yes

#cat /etc/debian_version

# Install wireless network drivers.

! test -d /lib/firmware/ath10k/ && sudo apt install --yes firmware-atheros

# Make sure wireless interface is created.

# ANECDOTE: some times the firmware is installed and loaded but the interface
# is NOT created.

! test -d /proc/sys/net/ipv6/conf/wlp* &&
	sudo modprobe -r ath10k_pci &&
	sudo modprobe ath10k_pci

# Setup ifupdown network interfaces with WPA2 authentication and IPv6 temporary
# addresses (privacy extension) support.

# ANECDOTE: default installation does NOT set inet6 options to any ifupdown
# network interface.

sudo cp --no-clobber /etc/network/interfaces /etc/network/interfaces.bak

! grep --quiet inet6 /etc/network/interfaces &&
	ETH0=$(find /sys/class/net/ -name 'en*' -printf '%f' -quit) &&
	test -z "$ETH0" && echo "ETH0 not found." && exit

! grep --quiet inet6 /etc/network/interfaces &&
	WLAN0=$(find /sys/class/net/ -name 'wl*' -printf '%f' -quit) &&
	test -z "$WLAN0" && echo "WLAN0 not found." && exit

! grep --quiet wpa-ssid /etc/network/interfaces &&
	test -z "$WPA_SSID" && read -p "WiFi SSID: " WPA_SSID &&
	test -z "$WPA_SSID" && echo "WPA_SSID is empty." && exit

! grep --quiet wpa-psk /etc/network/interfaces &&
	test -z "$WPA_PSK" && read -p "WiFi Password: " WPA_PSK &&
	test -z "$WPA_PSK" && echo "WPA_PSK is empty."

! grep --quiet inet6 /etc/network/interfaces && sudo tee /etc/network/interfaces <<EOF
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback
iface lo inet6 loopback

# The primary network interface
allow-hotplug $ETH0
iface $ETH0 inet dhcp
iface $ETH0 inet6 auto
	privext 2

# The wireless network interface
allow-hotplug $WLAN0
iface $WLAN0 inet dhcp
	wpa-ssid "$WPA_SSID"
	wpa-psk "$WPA_PSK"
iface $WLAN0 inet6 auto
	privext 2
EOF

# Enable IPv6 privacy extension at the kernel level.

#! test -f /etc/sysctl.d/40-ipv6.conf &&
#	ls --width 1 /proc/sys/net/ipv6/conf/ |
#	sed 's/^/net.ipv6.conf./;s/$/.use_tempaddr=2/' |
#	sudo tee /etc/sysctl.d/40-ipv6.conf

#cat /etc/sysctl.d/40-ipv6.conf

#! grep --quiet 2 /proc/sys/net/ipv6/conf/all/use_tempaddr &&
#	sudo /sbin/sysctl --load /etc/sysctl.d/40-ipv6.conf

#cat /proc/sys/net/ipv6/conf/all/use_tempaddr

# Setup nftables firewall.

# NOTE: Debian Buster uses the nftables framework by default.
# See <https://wiki.debian.org/nftables>.

sudo cp --no-clobber /etc/nftables.conf /etc/nftables.conf.bak

# Debian provides a nftables.conf file with a skeleton firewall with
# no rules [does NOT drop anything]. The old /etc/nftables.conf file is
# now an example for a workstation.
# See <https://salsa.debian.org/pkg-netfilter-team/pkg-nftables/-/commit/06550296490642a136626975269c484db38231bb>.

! grep --quiet drop /etc/nftables.conf &&
	sudo cp /usr/share/doc/nftables/examples/workstation.nft /etc/nftables.conf

# Since nftables 0.5, you can also specify the default policy for base
# chains as in iptables.
# See <https://wiki.nftables.org/wiki-nftables/index.php/Configuring_chains#Base_chain_policy>

sudo sed --in-place 's/0;$/0; policy drop;/' /etc/nftables.conf

# Don't count anything as no one will be analyzing it anyway.

sudo sed --in-place 's/\tcounter drop/\t#counter drop/' /etc/nftables.conf

# Start and enable the firewall.

! systemctl --quiet is-active nftables.service &&
	sudo systemctl start nftables.service

! systemctl --quiet is-enabled nftables.service &&
	sudo systemctl enable nftables.service

# Install Windows file system drivers.

! test -f /usr/bin/ntfs-3g && sudo apt install --yes ntfs-3g

# Add Windows partition to fstab.
# See <https://manpages.debian.org/unstable/ntfs-3g/ntfs-3g.8.en.html>.

sudo cp --no-clobber /etc/fstab /etc/fstab.bak

! grep -q windows /etc/fstab && sudo tee --append /etc/fstab <<EOF
# Windows partition
LABEL=Windows	/media/windows	ntfs	defaults,noauto	0	0
EOF

! test -d /media/windows &&
	sudo mkdir /media/windows &&
	sudo systemctl daemon-reload

#sudo mount /media/windows
#ls -lha /media/windows/
#sudo umount /media/windows

# Install XOrg and some basic applications.

! test -f /usr/bin/Xorg && sudo apt install --yes xorg
! test -f /usr/bin/xinit && sudo apt install --yes xinit
! test -f /usr/bin/openbox && sudo apt install --yes openbox
! test -f /usr/bin/firefox && sudo apt install --yes firefox
! test -f /usr/bin/scite && sudo apt install --yes scite
#! test -f /usr/bin/vim && sudo apt install --yes vim
#! test -f /usr/bin/git && sudo apt install --yes git

# Enable tap-to-click and natural scrolling.

! test -f /etc/X11/xorg.conf.d/40-libinput.conf && sudo tee /etc/X11/xorg.conf.d/40-libinput.conf <<EOF
Section "InputClass"
	Identifier "libinput touchpad catchall"
	MatchIsTouchpad "on"
	MatchDevicePath "/dev/input/event*"
	Driver "libinput"
	Option "Tapping" "on"
	Option "TappingDrag" "on"
	Option "TappingButtonMap" "lrm"
	Option "DisableWhileTyping" "on"
	Option "NaturalScrolling" "on"
EndSection
EOF

# Set up user environment.

! test -f ~/.inputrc && cat > ~/.inputrc <<\EOF
$include /etc/inputrc
set bell-style none
EOF

! test -d ~/.config/openbox/ && mkdir --parents ~/.config/openbox/

! test -f ~/.config/openbox/autostart.sh && cat > ~/.config/openbox/autostart.sh <<\EOF
#!/bin/sh
setxkbmap -layout br -model pc105 &
xrdb -merge ~/.Xresources &
xsetroot -solid '#333333' &
xterm &
EOF

! test -x ~/.config/openbox/autostart.sh && chmod 700 ~/.config/openbox/autostart.sh

cp --no-clobber /etc/X11/openbox/rc.xml ~/.config/openbox/

#sed -n '/W-e/s/<keybind/<!-- <keybind/p' ~/.config/openbox/rc.xml
#sed -i '/W-e/s/<keybind/<!-- <keybind/' ~/.config/openbox/rc.xml
#sed -n '/W-e/,/\/keybind/s/keybind>/keybind> -->/p' ~/.config/openbox/rc.xml
#sed -i '/W-e/,/\/keybind/s/keybind>/keybind> -->/' ~/.config/openbox/rc.xml

! grep --quiet "W-t" ~/.config/openbox/rc.xml && sed -i '/\/keyboard/i \
  <!-- My keybindings --> \
  <keybind key="C-A-t W-t"> \
    <action name="Execute"> \
      <command>xterm</command> \
    </action> \
  </keybind>' ~/.config/openbox/rc.xml

! test -d ~/.local/bin/ && mkdir --parents ~/.local/bin/

! test -f ~/.local/bin/autoupdate.sh && cat > ~/.local/bin/autoupdate.sh <<\EOF
#!/bin/sh
set -e
sudo apt update
sudo apt upgrade --yes
sudo apt autoremove --yes
test -f /var/run/reboot-required && cat /var/run/reboot-required
EOF

! test -x ~/.local/bin/autoupdate.sh && chmod 755 ~/.local/bin/autoupdate.sh

! test -f ~/.SciTEUser.properties && cat > ~/.SciTEUser.properties <<\EOF
statusbar.visible=1
fold.margin.width=0
tabsize=4
indent.size=4
code.page=65001
all.files=All Files (*)|*|
top.filters=$(all.files)$(source.all.filter)
font.base=$(font.monospace)
font.small=$(font.monospace)
font.comment=$(font.monospace)
font.text=$(font.monospace)
font.text.comment=$(font.monospace)
font.embedded.base=$(font.monospace)
font.embedded.comment=$(font.monospace)
font.monospace=font:Mono,size:10
font.monospace.small=$(font.monospace)
font.vbs=$(font.monospace)
EOF

#! test -f ~/.vimrc && cat > ~/.vimrc <<\EOF
#set backspace=indent,eol,start
#set encoding=utf-8
#set nobackup
#set nocompatible
#set nowrap
#set number
#"set numberwidth=4
#"set ruler
#set showtabline=2
#set tabstop=4
#"set title
#if has("syntax")
#	syntax on
#	colorscheme ron
#	highlight Comment ctermfg=DarkCyan
#	highlight LineNr ctermbg=Black ctermfg=Grey
#	highlight TabLine ctermbg=Black ctermfg=DarkGrey
#	highlight TabLineFill cterm=underline ctermfg=DarkGrey
#	highlight TabLineSel ctermfg=Grey
#endif
#EOF

#! test -f ~/.gitconfig && cat > ~/.gitconfig <<\EOF
#[init]
#        defaultBranch = main
#EOF

! test -f ~/.Xresources && cat > ~/.Xresources <<\EOF
XTerm.termName: xterm-256color
XTerm.vt100.allowBoldFonts: false
XTerm.vt100.background: black
XTerm.vt100.foreground: grey
XTerm.vt100.geometry: 80x25
EOF

! test -f ~/.xsessionrc && cat > ~/.xsessionrc <<\EOF
#!/bin/sh
[ -r /etc/profile ] && . /etc/profile
[ -r ~/.profile ] && . ~/.profile
EOF

! test -x ~/.xsessionrc && chmod 700 ~/.xsessionrc

#sudo reboot 

echo "Done."
