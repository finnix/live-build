#!/bin/sh

## live-build(7) - System Build Scripts
## Copyright (C) 2016-2020 The Debian Live team
## Copyright (C) 2006-2015 Daniel Baumann <mail@daniel-baumann.ch>
##
## This program comes with ABSOLUTELY NO WARRANTY; for details see COPYING.
## This is free software, and you are welcome to redistribute it
## under certain conditions; see COPYING for details.


Check_stagefile ()
{
	FILE=".build/${1}"
	NAME="$(basename ${FILE})"

	# Checking stage file
	if [ -f "${FILE}" ]
	then
		if [ "${_FORCE}" != "true" ]
		then
			# Skip execution
			Echo_warning "Skipping %s, already done" "${NAME}"
			exit 0
		else
			# Force execution
			Echo_message "Forcing %s" "${NAME}"
			rm -f "${FILE}"
		fi
	fi
}

Create_stagefile ()
{
	FILE=".build/${1}"
	DIRECTORY="$(dirname ${FILE})"

	# Creating stage directory
	mkdir -p "${DIRECTORY}"

	# Creating stage file
	touch "${FILE}"
}

Remove_stagefile ()
{
	rm -f ".build/${1}"
}

Require_stagefile ()
{
	local NAME
	local FILES
	local NUMBER
	NAME="$(basename ${0})"
	FILES="${@}" #must be on separate line to 'local' declaration to avoid error
	NUMBER="$(echo ${@} | wc -w)"

	local FILE
	local CONTINUE=false
	for FILE in ${FILES}
	do
		FILE=".build/${FILE}"
		# Find at least one of the required stages
		if [ -f ${FILE} ]
		then
			CONTINUE=true
			NAME="${NAME} $(basename ${FILE})"
		fi
	done

	if ! $CONTINUE
	then
		if [ "${NUMBER}" -eq 1 ]
		then
			Echo_error "%s: %s missing" "${NAME}" "${FILE}"
		else
			Echo_error "%s: one of %s is missing" "${NAME}" "${FILES}"
		fi

		exit 1
	fi
}
