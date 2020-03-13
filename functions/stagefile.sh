#!/bin/sh

## live-build(7) - System Build Scripts
## Copyright (C) 2016-2020 The Debian Live team
## Copyright (C) 2006-2015 Daniel Baumann <mail@daniel-baumann.ch>
##
## This program comes with ABSOLUTELY NO WARRANTY; for details see COPYING.
## This is free software, and you are welcome to redistribute it
## under certain conditions; see COPYING for details.


# Get the default filename for a script's stagefile (the name of the script
# file itself). A suffix can be appended via providing as a param.
Stagefile_name ()
{
	local SUFFIX="${1}"
	local FILENAME
	FILENAME="$(basename $0)"
	echo ${FILENAME}${SUFFIX:+.$SUFFIX}
}

Check_stagefile ()
{
	local FILE
	local NAME
	FILE=".build/${1:-$(Stagefile_name)}"
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
	local FILE
	local DIRECTORY
	FILE=".build/${1:-$(Stagefile_name)}"
	DIRECTORY="$(dirname ${FILE})"

	# Creating stage directory
	mkdir -p "${DIRECTORY}"

	# Creating stage file
	touch "${FILE}"
}

Remove_stagefile ()
{
	local FILE
	FILE=".build/${1:-$(Stagefile_name)}"
	rm -f "${FILE}"
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
