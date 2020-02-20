#!/bin/sh

## live-build(7) - System Build Scripts
## Copyright (C) 2016-2020 The Debian Live team
## Copyright (C) 2006-2015 Daniel Baumann <mail@daniel-baumann.ch>
##
## This program comes with ABSOLUTELY NO WARRANTY; for details see COPYING.
## This is free software, and you are welcome to redistribute it
## under certain conditions; see COPYING for details.


Get_configuration ()
{
	local CONFIGURATION_FILE="${1}"
	local FIELD_NAME="${2}"
	local FIELD_BODY

	if [ -e "${CONFIGURATION_FILE}" ]
	then
		FIELD_BODY="$(grep ^${FIELD_NAME}: ${CONFIGURATION_FILE} | awk '{ $1=""; print $0 }' | sed -e 's|^ ||')"
	fi

	echo ${FIELD_BODY}
}

Set_configuration ()
{
	local CONFIGURATION_FILE="${1}"
	local FIELD_NAME="${2}"
	local FIELD_BODY="${3}"

	if grep -qs "^${FIELD_NAME}:" "${CONFIGURATION_FILE}"
	then
		# Update configuration
		sed -i -e "s|^${FIELD_NAME}:.*$|${FIELD_NAME}: ${FIELD_BODY}|" "${CONFIGURATION_FILE}"
	else
		# Append configuration
		echo "${FIELD_NAME}: ${FIELD_BODY}" >> "${CONFIGURATION_FILE}"
	fi
}
