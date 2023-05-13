#!/bin/bash

# Rebuild an ISO image for a given timestamp
#
# Copyright 2021-2022 Holger Levsen <holger@layer-acht.org>
# Copyright 2021-2023 Roland Clobus <rclobus@rclobus.nl>
# released under the GPLv2

# Command line arguments:
# 1) Image type
# 2) Debian version
# 3) [optional] argument for the timestamp:
#    - 'archive' (default): fetches the timestamp from the Debian archive
#    - 'snapshot': fetches the latest timestamp from the snapshot server
#    - A timestamp (format: YYYYMMDD'T'HHMMSS'Z'): a specific timestamp on the snapshot server
# 4) [optional] argument for the origin of the d-i:
#    - 'git' (default): rebuild the installer from git
#    - 'archive': take the installer from the Debian archive

# Environment variables:
# http_proxy: The proxy that is used by live-build and wget
# https_proxy: The proxy that is used by git
# SNAPSHOT_TIMESTAMP: The timestamp to rebuild (format: YYYYMMDD'T'HHMMSS'Z')

# This script can be run as root, but root rights are only required for a few commands.
# You are advised to configure the user with 'visudo' instead.
# Required entries in the sudoers file:
#   Defaults env_keep += "SOURCE_DATE_EPOCH"
#   Defaults env_keep += "LIVE_BUILD"
#   thisuser ALL=(root) NOPASSWD: /usr/bin/lb build
#   thisuser ALL=(root) NOPASSWD: /usr/bin/lb clean --purge

# Coding convention: enforced by 'shfmt'

DEBUG=false

set -e
set -o pipefail # see eg http://petereisentraut.blogspot.com/2010/11/pipefail.html

output_echo() {
	set +x
	echo "###########################################################################################"
	echo
	echo -e "$(date -u) - $1"
	echo
	if $DEBUG; then
		set -x
	fi
}

cleanup() {
	output_echo "Generating summary.txt $1"
	cat <<EOF >summary.txt
Configuration: ${CONFIGURATION}
Debian version: ${DEBIAN_VERSION}
Use latest snapshot: ${BUILD_LATEST_DESC}
Installer origin: ${INSTALLER_ORIGIN}
Snapshot timestamp: ${SNAPSHOT_TIMESTAMP}
Snapshot epoch: ${SOURCE_DATE_EPOCH}
Live-build override: ${LIVE_BUILD_OVERRIDE}
Live-build path: ${LIVE_BUILD}
Build result: ${BUILD_RESULT}
Alternative timestamp: ${PROPOSED_SNAPSHOT_TIMESTAMP}
Checksum: ${SHA256SUM}
EOF
	touch summary.txt -d@${SOURCE_DATE_EPOCH}
}

parse_commandline_arguments() {
	# Argument 1 = image type
	case $1 in
	"smallest-build")
		INSTALLER="none"
		PACKAGES=""
		;;
	"cinnamon")
		INSTALLER="live"
		PACKAGES="live-task-cinnamon"
		;;
	"gnome")
		INSTALLER="live"
		PACKAGES="live-task-gnome"
		;;
	"kde")
		INSTALLER="live"
		PACKAGES="live-task-kde"
		;;
	"lxde")
		INSTALLER="live"
		PACKAGES="live-task-lxde"
		;;
	"lxqt")
		INSTALLER="live"
		PACKAGES="lxqt live-task-lxqt" # Install lxqt before lve-task-lxqt to avoid #1023472
		;;
	"mate")
		INSTALLER="live"
		PACKAGES="live-task-mate"
		;;
	"standard")
		INSTALLER="live"
		PACKAGES="live-task-standard"
		;;
	"xfce")
		INSTALLER="live"
		PACKAGES="live-task-xfce"
		;;
	*)
		output_echo "Error: Bad argument 1, image type: $1"
		exit 1
		;;
	esac
	CONFIGURATION="$1"

	# Argument 2 = Debian version
	# Use 'stable', 'testing' or 'unstable' or code names like 'sid'
	if [ -z "$2" ]; then
		output_echo "Error: Bad argument 2, Debian version: it is empty"
		exit 2
	fi
	DEBIAN_VERSION="$2"
	case "$DEBIAN_VERSION" in
	"bullseye")
		FIRMWARE_ARCHIVE_AREA="non-free contrib"
		;;
	*)
		FIRMWARE_ARCHIVE_AREA="non-free-firmware"
		;;
	esac

	# Argument 3 = optional timestamp
	BUILD_LATEST="archive"
	BUILD_LATEST_DESC="yes, from the main Debian archive"
	if [ ! -z "$3" ]; then
		case $3 in
		"archive")
			BUILD_LATEST="archive"
			BUILD_LATEST_DESC="yes, from the main Debian archive"
			;;
		"snapshot")
			BUILD_LATEST="snapshot"
			BUILD_LATEST_DESC="yes, from the snapshot server"
			;;
		*)
			SNAPSHOT_TIMESTAMP=$3
			BUILD_LATEST="no"
			BUILD_LATEST_DESC="no"
			;;
		esac
	fi

	INSTALLER_ORIGIN="git"
	if [ ! -z "$4" ]; then
		case $4 in
		"git")
			INSTALLER_ORIGIN="git"
			;;
		"archive")
			INSTALLER_ORIGIN="${DEBIAN_VERSION}"
			;;
		*)
			output_echo "Error: Bad argument 4, unknown value '$4' provided"
			exit 4
			;;
		esac
	fi
}

get_snapshot_from_archive() {
	wget ${WGET_OPTIONS} http://deb.debian.org/debian/dists/${DEBIAN_VERSION}/InRelease --output-document latest
	#
	# Extract the timestamp from the InRelease file
	#
	# Input:
	# ...
	# Date: Sat, 23 Jul 2022 14:33:45 UTC
	# ...
	# Output:
	# 20220723T143345Z
	#
	SNAPSHOT_TIMESTAMP=$(cat latest | awk '/^Date:/ { print substr($0, 7) }' | xargs -I this_date date --utc --date "this_date" +%Y%m%dT%H%M%SZ)
	rm latest
}

#
# main: follow https://wiki.debian.org/ReproducibleInstalls/LiveImages
#

# Cleanup if something goes wrong
trap cleanup INT TERM EXIT

parse_commandline_arguments "$@"

if $DEBUG; then
	WGET_OPTIONS=
	GIT_OPTIONS=
else
	WGET_OPTIONS=--quiet
	GIT_OPTIONS=--quiet
fi

# No log required
WGET_OPTIONS="${WGET_OPTIONS} --output-file /dev/null --timestamping"

if [ ! -z "${LIVE_BUILD}" ]; then
	LIVE_BUILD_OVERRIDE=1
else
	LIVE_BUILD_OVERRIDE=0
	export LIVE_BUILD=${PWD}/live-build
fi

# Prepend sudo for the commands that require it (when not running as root)
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
	SUDO=sudo
fi

# Use a fresh git clone
if [ ! -d ${LIVE_BUILD} -a ${LIVE_BUILD_OVERRIDE} -eq 0 ]; then
	git clone https://salsa.debian.org/live-team/live-build.git ${LIVE_BUILD} --single-branch --no-tags
fi

LB_OUTPUT=lb_output.txt
rm -f ${LB_OUTPUT}

case ${BUILD_LATEST} in
"archive")
	# Use the timestamp of the current Debian archive
	get_snapshot_from_archive
	MIRROR=http://deb.debian.org/debian/
	;;
"snapshot")
	# Use the timestamp of the latest mirror snapshot
	wget ${WGET_OPTIONS} http://snapshot.notset.fr/mr/timestamp/debian/latest --output-document latest
	#
	# Extract the timestamp from the JSON file
	#
	# Input:
	# {
	#   "_api": "0.3",
	#   "_comment": "notset",
	#   "result": "20210828T083909Z"
	# }
	# Output:
	# 20210828T083909Z
	#
	SNAPSHOT_TIMESTAMP=$(cat latest | awk '/"result":/ { split($0, a, "\""); print a[4] }')
	rm latest
	MIRROR=http://snapshot.notset.fr/archive/debian/${SNAPSHOT_TIMESTAMP}
	;;
"no")
	# The value of SNAPSHOT_TIMESTAMP was provided on the command line
	MIRROR=http://snapshot.notset.fr/archive/debian/${SNAPSHOT_TIMESTAMP}
	;;
*)
	echo "E: A new option to BUILD_LATEST has been added"
	exit 1
	;;
esac
# Convert SNAPSHOT_TIMESTAMP to Unix time (insert suitable formatting first)
export SOURCE_DATE_EPOCH=$(date -d $(echo ${SNAPSHOT_TIMESTAMP} | awk '{ printf "%s-%s-%sT%s:%s:%sZ", substr($0,1,4), substr($0,5,2), substr($0,7,2), substr($0,10,2), substr($0,12,2), substr($0,14,2) }') +%s)
output_echo "Info: using the snapshot from ${SOURCE_DATE_EPOCH} (${SNAPSHOT_TIMESTAMP})"

# Use the code from the actual timestamp
# Report the versions that were actually used
if [ ${LIVE_BUILD_OVERRIDE} -eq 0 ]; then
	pushd ${LIVE_BUILD} >/dev/null
	git pull ${GIT_OPTIONS}
	git checkout $(git rev-list -n 1 --min-age=${SOURCE_DATE_EPOCH} HEAD) ${GIT_OPTIONS}
	git clean -Xdf ${GIT_OPTIONS}
	output_echo "Info: using live-build from git version $(git log -n 1 --pretty=format:%H_%aI)"
	popd >/dev/null
else
	output_echo "Info: using local live-build: $(lb --version)"
fi

# If the configuration folder already exists, re-create from scratch
if [ -d config ]; then
	${SUDO} lb clean --purge
	rm -fr config
	rm -fr .build
fi

# Configuration for the live image:
# - For /etc/apt/sources.list: Use the mirror from ${MIRROR}, no security, no updates
# - The debian-installer is built from its git repository
# - Don't cache the downloaded content
# - To reduce some network traffic a proxy is implicitly used
output_echo "Running lb config."
lb config \
	--mirror-bootstrap ${MIRROR} \
	--mirror-binary ${MIRROR} \
	--security false \
	--updates false \
	--distribution ${DEBIAN_VERSION} \
	--debian-installer ${INSTALLER} \
	--debian-installer-distribution ${INSTALLER_ORIGIN} \
	--cache-packages false \
	--archive-areas "main ${FIRMWARE_ARCHIVE_AREA}" \
	2>&1 | tee $LB_OUTPUT

# Insider knowledge of live-build:
#   Add '-o Acquire::Check-Valid-Until=false', to allow for rebuilds of older timestamps
sed -i -e '/^APT_OPTIONS=/s/--yes/--yes -o Acquire::Check-Valid-Until=false/' config/common

if [ ! -z "${PACKAGES}" ]; then
	echo "${PACKAGES}" >config/package-lists/desktop.list.chroot
fi

# Add additional hooks, that work around known issues regarding reproducibility
cp -a ${LIVE_BUILD}/examples/hooks/reproducible/* config/hooks/normal

# For stable and soon-to-be-stable use the same boot splash screen as the Debian installer
case "$DEBIAN_VERSION" in
"bullseye")
	mkdir -p config/bootloaders/syslinux_common
	wget --quiet https://salsa.debian.org/installer-team/debian-installer/-/raw/master/build/boot/artwork/11-homeworld/homeworld.svg -O config/bootloaders/syslinux_common/splash.svg
	mkdir -p config/bootloaders/grub-pc
	ln -s ../../isolinux/splash.png config/bootloaders/grub-pc/splash.png
	;;
"bookworm")
	mkdir -p config/bootloaders/syslinux_common
	wget --quiet https://salsa.debian.org/installer-team/debian-installer/-/raw/master/build/boot/artwork/12-emerald/emerald.svg -O config/bootloaders/syslinux_common/splash.svg
	mkdir -p config/bootloaders/grub-pc
	ln -s ../../isolinux/splash.png config/bootloaders/grub-pc/splash.png
	;;
*)
	# Use the default 'under construction' image
	;;
esac

# Build the image
output_echo "Running lb build."

set +e # We are interested in the result of 'lb build', so do not fail on errors
${SUDO} lb build | tee -a $LB_OUTPUT
BUILD_RESULT=$?
set -e
if [ ${BUILD_RESULT} -ne 0 ]; then
	# Find the snapshot that matches 1 second before the current snapshot
	wget ${WGET_OPTIONS} http://snapshot.notset.fr/mr/timestamp/debian/$(date --utc -d @$((${SOURCE_DATE_EPOCH} - 1)) +%Y%m%dT%H%M%SZ) --output-document but_latest
	PROPOSED_SNAPSHOT_TIMESTAMP=$(cat but_latest | awk '/"result":/ { split($0, a, "\""); print a[4] }')
	rm but_latest

	output_echo "Warning: lb build failed with ${BUILD_RESULT}. The latest snapshot might not be complete (yet). Try re-running the script with SNAPSHOT_TIMESTAMP=${PROPOSED_SNAPSHOT_TIMESTAMP}."
	# Occasionally the snapshot is not complete, you could use the previous snapshot instead of giving up
	exit 99
fi

# Calculate the checksum
SHA256SUM=$(sha256sum live-image-amd64.hybrid.iso | cut -f 1 -d " ")

if [ ${BUILD_LATEST} == "archive" ]; then
	SNAPSHOT_TIMESTAMP_OLD=${SNAPSHOT_TIMESTAMP}
	get_snapshot_from_archive
	if [ ${SNAPSHOT_TIMESTAMP} != ${SNAPSHOT_TIMESTAMP_OLD} ]; then
		output_echo "Warning: meanwhile the archive was updated. Try re-running the script."
		PROPOSED_SNAPSHOT_TIMESTAMP="${BUILD_LATEST}"
		exit 99
	fi
fi

cleanup success
# Turn off the trap
trap - INT TERM EXIT

# We reached the end, return with PASS
exit 0
