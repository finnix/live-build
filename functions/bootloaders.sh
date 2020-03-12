#!/bin/sh

## live-build(7) - System Build Scripts
## Copyright (C) 2016-2020 The Debian Live team
## Copyright (C) 2016 Adrian Gibanel Lopez <adrian15sgd@gmail.com>
##
## This program comes with ABSOLUTELY NO WARRANTY; for details see COPYING.
## This is free software, and you are welcome to redistribute it
## under certain conditions; see COPYING for details.

Is_Requested_Bootloader ()
{
	OLDIFS="$IFS"
	IFS=","
	for BOOTLOADER in ${LB_BOOTLOADERS}; do
		if [ "${BOOTLOADER}" = "${1}" ]; then
			IFS="$OLDIFS"
			return 0
		fi
	done
	IFS="$OLDIFS"
	return 1
}

Is_First_Bootloader ()
{
	if [ "${LB_FIRST_BOOTLOADER}" != "${1}" ]; then
		return 1
	fi
	return 0
}

Is_Extra_Bootloader ()
{
	if Is_First_Bootloader "${1}"; then
		return 1
	fi
	if ! Is_Requested_Bootloader "${1}"; then
		return 1
	fi
	return 0
}

Check_Non_First_Bootloader ()
{
	if Is_First_Bootloader "${1}"; then
		Echo_error "Bootloader: \`${1}\` is not supported as a first bootloader."
		exit 1
	fi
}

Check_Non_Extra_Bootloader ()
{
	if Is_Extra_Bootloader "${1}"; then
		Echo_error "Bootloader: \`${1}\` is not supported as a extra bootloader."
		exit 1
	fi
}

Check_First_Bootloader_Role ()
{
	Check_Non_Extra_Bootloader "${1}"

	if ! Is_First_Bootloader "${1}"; then
		exit 0
	fi
}

Check_Extra_Bootloader_Role ()
{
	Check_Non_First_Bootloader "${1}"

	if ! Is_Extra_Bootloader "${1}"; then
		exit 0
	fi
}

Check_Any_Bootloader_Role ()
{
	if ! Is_Requested_Bootloader "${1}"; then
		exit 0
	fi
}
