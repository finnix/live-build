#!/bin/sh

## live-build(7) - System Build Scripts
## Copyright (C) 2006-2015 Daniel Baumann <mail@daniel-baumann.ch>
##
## This program comes with ABSOLUTELY NO WARRANTY; for details see COPYING.
## This is free software, and you are welcome to redistribute it
## under certain conditions; see COPYING for details.

# Updates FIRMWARE_PACKAGES with list of packages determined from specified
# archive areas of specified distro, based upon reading archive content file.
#
# Shared by chroot_firmware and installer_debian-installer
#
# Assumption: firmware packages install files into /lib/firmware
Firmware_List_From_Contents () {
	local MIRROR_CHROOT="${1}"
	local DISTRO_CHROOT="${2}"
	local ARCHIVE_AREAS="${3}"

	for _ARCHIVE_AREA in ${ARCHIVE_AREAS}
	do
		local CONTENTS_FILE="cache/contents.chroot/contents.${DISTRO_CHROOT}.${LB_ARCHITECTURES}.gz"
		local CONTENTS_URL="${MIRROR_CHROOT}/dists/${DISTRO_CHROOT}/${_ARCHIVE_AREA}/Contents-${LB_ARCHITECTURES}.gz"

		# Ensure fresh
		rm -f "${CONTENTS_FILE}"

		wget ${WGET_OPTIONS} "${CONTENTS_URL}" -O "${CONTENTS_FILE}"

		local PACKAGES
		PACKAGES="$(gunzip -c "${CONTENTS_FILE}" | awk '/^lib\/firmware/ { print $2 }' | sort -u )"
		FIRMWARE_PACKAGES="${FIRMWARE_PACKAGES} ${PACKAGES}"

		# Don't waste disk space preserving since always getting fresh
		rm -f "${CONTENTS_FILE}"
	done
}
