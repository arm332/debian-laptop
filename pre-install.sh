#!/bin/sh

set -e

# Download Debian's network installation image and make a removable
# installation disk.

# NOTE: use the network installation image that can be downloaded quickly, 
# recorded onto a removable disk and used to install the standard system 
# utilities so that everything can be upgraded to unstable release right after 
# the installation.
# See <https://www.debian.org/distrib/>.

# NOTE: do NOT use the unofficial installation image with non-free firmware 
# because current version 11.3.0 does NOT contain non-free firmware for
# Qualcomm Atheros QCA6174 802.11ac Wireless Network Adapter anyway.

# Show help.

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
	echo "${0##*/} - Download Debian's network installation image ISO file"
	echo "and make an USB installation disk."
	echo
	echo "Usage: ${0##*/} [OPTIONS] DEVICE"
	echo
	echo "Options:"
	echo "  -h, --help                            Show this help message and exit"
	echo
	echo "Device:"
	echo "  The USB device path (i.e., /dev/sdb, /dev/sdc, /dev/sdd etc.)."
	echo
	exit
fi

# Check the removable disk.

DEVICE=${1##*/}

if [ "$DEVICE" = "" ]; then
	echo "${0##*/}: device missing."
	exit
fi

if [ ! -d "/sys/block/$DEVICE" ]; then
	echo "${0##*/}: device not found."
	exit
fi

if ! grep --quiet 1 "/sys/block/$DEVICE/removable"; then
	echo "${0##*/}: device not removable."
	exit
fi

# Make sure ~/Downloads/ directory exists.

mkdir --parents $HOME/Downloads/

# Download the installation image directory index page and extract current
# Debian's version from the file name debian-CURRENT-amd64-netinst.iso.

echo "Getting current version number..."

wget --output-document=$HOME/Downloads/debian-CURRENT-amd64-netinst.html --quiet --show-progress https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/
 
VERSION=$(sed -n 's/.*debian-\([^-]*\)-amd64-netinst.*/\1/p' $HOME/Downloads/debian-CURRENT-amd64-netinst.html)

echo "Version: $VERSION."

# Download current installation image.

echo "Downloading installation image... "

wget --directory-prefix=$HOME/Downloads/ --quiet --show-progress --timestamp https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-$VERSION-amd64-netinst.iso

# Download current installation image checksum file.

echo "Downloading checksum file... "

wget --directory-prefix=$HOME/Downloads/ --quiet --show-progress --timestamp https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA512SUMS

# Check that the installation image file has not been corrupted during download.

# NOTE: use a subshell so the current working directory is NOT changed.

# TODO: use or remove CHECKSUM variable.

echo "Verifying installation image..."

CHECKSUM=$(cd $HOME/Downloads/ && sha512sum --check --ignore-missing SHA512SUMS)

# If GnuPG is installed, verify the checksum file against the signature file.

if [ -x /usr/bin/gpg ]; then

	# Download the checksum signature file.

	echo "Downloading checksum signature file... "

	wget --directory-prefix=$HOME/Downloads/ --quiet --show-progress --timestamp https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA512SUMS.sign

	# Import the checksum signature key from Debian GPG keyring.
	# See <https://www.debian.org/CD/verify> and
	# <https://superuser.com/questions/1485213/>.

	echo "Importing signature key... "
	
	gpg --keyserver keyring.debian.org --receive-keys DF9B9C49EAA9298432589D76DA87E80D6294BE9B

	# Check at least one private key exists to sign the signature key or
	# create a temporary one.

	#~ gpg --list-secret-keys | grep --quiet ^ || gpg --batch --generate-key << EOF
	#~ %echo Generating a basic OpenPGP key
	#~ Key-Type: default
	#~ Subkey-Type: default
	#~ Name-Real: Joe Tester
	#~ Name-Comment: no comments
	#~ Name-Email: joe@foo.bar
	#~ Expire-Date: 0
	#~ %no-ask-passphrase
	#~ %no-protection
	#~ %commit
	#~ %echo done
	#~ EOF

	# Sing the key to mark a key as valid and avoid the scarry "WARNING:
	# This key is not certified with a trusted signature!".
	# See <https://superuser.com/questions/1435147/>.

	# TODO: do NOT prompt and get the key fingerprint to delete the key
	# without prompting later.

	#~ gpg --lsign-key DF9B9C49EAA9298432589D76DA87E80D6294BE9B

	# Check that the signature file have not been tampered.

	gpg --verify $HOME/Downloads/SHA512SUMS.sign $HOME/Downloads/SHA512SUMS

	# Delete the imported key.

	echo "Deleting signature key... "
	
	gpg --batch --delete-keys DF9B9C49EAA9298432589D76DA87E80D6294BE9B

	# Check the key was removed.

	#gpg --list-keys

	# Delete temporary public and private keys.

	#gpg --batch --delete-secret-keys BCAC8E74FCBA315F8361AC9FF371DABFF61F352B
	#gpg --batch --delete-keys BCAC8E74FCBA315F8361AC9FF371DABFF61F352B
	#gpg --list-secret-keys
fi

# Confirm.

echo "WARNING! This will destroy all data on /dev/$DEVICE."
read -p "Do you want to continue? [Y/n] " RESP
#echo

if [ "${RESP#[Nn]}" != "$RESP" ]; then
	echo "Abort."
	exit
fi

# Unmount.

for PART in /sys/block/$DEVICE/$DEVICE*; do
	if grep --quiet /dev/${PART##*/} /proc/mounts; then
		echo "Unmounting /dev/${PART##*/}... "
		sudo umount /dev/${PART##*/}
	fi
done

# Wipe.

# NOTE: don't! Let the installation image wipe any partition.

#echo "Wipping /dev/$DEVICE..."
#echo "write" | sudo sfdisk --quiet --wipe always /dev/$DEVICE

# Create a new partition.

# NOTE: don't! Let the installation image create any partition.
# See <https://www.shellhacks.com/format-usb-drive-in-linux-command-line/>
# https://www.pendrivelinux.com/restoring-your-usb-key-partition/

#echo "start=2048 type=0c" | sudo sfdisk --quiet /dev/$DEVICE

# Format the new partition.

# NOTE: don't! Let the installation image create any formated partition.
# See https://askubuntu.com/questions/22381/how-to-format-a-usb-flash-drive
# https://askubuntu.com/questions/724081/how-to-format-a-fat32-usb-as-ext4
# https://superuser.com/questions/332252/how-to-create-and-format-a-partition-using-a-bash-script/1132834#1132834

#sudo mkfs.vfat -F32 -n "UNTITLED" /dev/$DEVICE

# Write the installation image onto the removable disk.
# See <https://www.debian.org/releases/stable/amd64/ch04s03.en.html>
# and <https://wiki.archlinux.org/title/USB_flash_installation_medium#Using_basic_command_line_utilities>.

echo "Copying installation image to disk. This may take some time... "

#sudo dd bs=4M if=debian-$VERSION-amd64-netinst.iso of=/dev/sdb conv=fsync oflag=direct status=progress
#sudo tee < $HOME/Downloads/debian-$VERSION-amd64-netinst.iso > /dev/sdb
sudo cp $HOME/Downloads/debian-$VERSION-amd64-netinst.iso /dev/$DEVICE

# Sync the copy.

sudo sync

# Clean up.

#rm $HOME/Downloads/SHA512SUMS.sign
#rm $HOME/Downloads/SHA512SUMS
#rm $HOME/Downloads/debian-$VERSION-amd64-netinst.iso
#rm $HOME/Downloads/debian-CURRENT-amd64-netinst.html

# End.

echo "Done."
