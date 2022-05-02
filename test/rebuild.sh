#!/bin/bash

# Rebuild an ISO image for a given timestamp
#
# Copyright 2021-2022 Holger Levsen <holger@layer-acht.org>
# Copyright 2021-2022 Roland Clobus <rclobus@rclobus.nl>
# released under the GPLv2

# Command line arguments:
# 1) Image type
# 2) Debian version
# 3) [optional] Timestamp (format: YYYYMMDD'T'HHMMSS'Z')

# Environment variables:
# http_proxy: The proxy that is used by live-build and wget
# https_proxy: The proxy that is used by git
# SNAPSHOT_TIMESTAMP: The timestamp to rebuild (format: YYYYMMDD'T'HHMMSS'Z')

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
Use latest snapshot: ${BUILD_LATEST}
Snapshot timestamp: ${SNAPSHOT_TIMESTAMP}
Snapshot epoch: ${SOURCE_DATE_EPOCH}
Live-build override: ${LIVE_BUILD_OVERRIDE}
Live-build path: ${LIVE_BUILD}
Build result: ${BUILD_RESULT}
Alternative timestamp: ${PROPOSED_SNAPSHOT_TIMESTAMP}
Checksum: ${SHA256SUM}
EOF
}

parse_commandline_arguments() {
	# Argument 1 = image type
	case $1 in
	"smallest-build")
		export INSTALLER="none"
		export PACKAGES=""
		;;
	"cinnamon")
		export INSTALLER="live"
		export PACKAGES="live-task-cinnamon"
		;;
	"gnome")
		export INSTALLER="live"
		export PACKAGES="live-task-gnome"
		;;
	"kde")
		export INSTALLER="live"
		export PACKAGES="live-task-kde"
		;;
	"lxde")
		export INSTALLER="live"
		export PACKAGES="live-task-lxde"
		;;
	"lxqt")
		export INSTALLER="live"
		export PACKAGES="live-task-lxqt"
		;;
	"mate")
		export INSTALLER="live"
		export PACKAGES="live-task-mate"
		;;
	"standard")
		export INSTALLER="live"
		export PACKAGES="live-task-standard"
		;;
	"xfce")
		export INSTALLER="live"
		export PACKAGES="live-task-xfce"
		;;
	*)
		output_echo "Error: Bad argument 1, image type: $1"
		exit 1
		;;
	esac
	export CONFIGURATION="$1"

	# Argument 2 = Debian version
	# Use 'stable', 'testing' or 'unstable' or code names like 'sid'
	if [ -z "$2" ]; then
		output_echo "Error: Bad argument 2, Debian version: it is empty"
		exit 2
	fi
	export DEBIAN_VERSION="$2"

	# Argument 3 = optional timestamp
	export BUILD_LATEST=1
	if [ ! -z "$3" ]; then
		export SNAPSHOT_TIMESTAMP=$3
		BUILD_LATEST=0
	fi
}

#
# main: follow https://wiki.debian.org/ReproducibleInstalls/LiveImages
#

# Cleanup if something goes wrong
trap cleanup INT TERM EXIT

parse_commandline_arguments "$@"

if $DEBUG; then
	export WGET_OPTIONS=
	export GIT_OPTIONS=
else
	export WGET_OPTIONS=--quiet
	export GIT_OPTIONS=--quiet
fi

# No log required
WGET_OPTIONS="${WGET_OPTIONS} --output-file /dev/null --timestamping"

if [ ! -z "${LIVE_BUILD}" ]; then
	export LIVE_BUILD_OVERRIDE=1
else
	export LIVE_BUILD_OVERRIDE=0
	export LIVE_BUILD=${PWD}/live-build
fi

# Use a fresh git clone
if [ ! -d ${LIVE_BUILD} -a ${LIVE_BUILD_OVERRIDE} -eq 0 ]; then
	git clone https://salsa.debian.org/live-team/live-build.git ${LIVE_BUILD} --single-branch --no-tags
fi

export LB_OUTPUT=lb_output.txt
rm -f ${LB_OUTPUT}

if [ ${BUILD_LATEST} -eq 1 ]; then
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
	export SNAPSHOT_TIMESTAMP=$(cat latest | awk '/"result":/ { split($0, a, "\""); print a[4] }')
	rm latest
fi
# Convert SNAPSHOT_TIMESTAMP to Unix time (insert suitable formatting first)
export SOURCE_DATE_EPOCH=$(date -d $(echo ${SNAPSHOT_TIMESTAMP} | awk '{ printf "%s-%s-%sT%s:%s:%sZ", substr($0,1,4), substr($0,5,2), substr($0,7,2), substr($0,10,2), substr($0,12,2), substr($0,14,2) }') +%s)
export MIRROR=http://snapshot.notset.fr/archive/debian/${SNAPSHOT_TIMESTAMP}
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
	sudo lb clean --purge
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
	--debian-installer-distribution git \
	--cache-packages false \
	2>&1 | tee $LB_OUTPUT

# Insider knowledge of live-build:
#   Add '-o Acquire::Check-Valid-Until=false', to allow for rebuilds of older timestamps
sed -i -e '/^APT_OPTIONS=/s/--yes/--yes -o Acquire::Check-Valid-Until=false/' config/common

if [ ! -z "${PACKAGES}" ]; then
	echo "${PACKAGES}" >config/package-lists/desktop.list.chroot
fi

# Add additional hooks, that work around known issues regarding reproducibility
cp -a ${LIVE_BUILD}/examples/hooks/reproducible/* config/hooks/normal

# Build the image
output_echo "Running lb build."

set +e # We are interested in the result of 'lb build', so do not fail on errors
sudo lb build | tee -a $LB_OUTPUT
export BUILD_RESULT=$?
set -e
if [ ${BUILD_RESULT} -ne 0 ]; then
	# Find the snapshot that matches 1 second before the current snapshot
	wget ${WGET_OPTIONS} http://snapshot.notset.fr/mr/timestamp/debian/$(date --utc -d @$((${SOURCE_DATE_EPOCH} - 1)) +%Y%m%dT%H%M%SZ) --output-document but_latest
	export PROPOSED_SNAPSHOT_TIMESTAMP=$(cat but_latest | awk '/"result":/ { split($0, a, "\""); print a[4] }')
	rm but_latest

	output_echo "Warning: lb build failed with ${BUILD_RESULT}. The latest snapshot might not be complete (yet). Try re-running the script with SNAPSHOT_TIMESTAMP=${PROPOSED_SNAPSHOT_TIMESTAMP}."
	# Occasionally the snapshot is not complete, you could use the previous snapshot instead of giving up
	exit 99
fi

# Calculate the checksum
export SHA256SUM=$(sha256sum live-image-amd64.hybrid.iso | cut -f 1 -d " ")

cleanup success
# Turn off the trap
trap - INT TERM EXIT

# We reached the end, return with PASS
exit 0
