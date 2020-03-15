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

# Ensure that all specified stagefiles exist (and thus that all associated stages are complete)
Require_stagefiles ()
{
	if [ $# -eq 0 ]; then
		Echo_warning "Bad `Require_stagefile` usage, no params were supplied"
		return 0
	fi

	local FILE
	local MISSING=""
	local MISSING_MULTIPLE=false
	for FILE in ${@}; do
		if [ ! -f ".build/${FILE}" ]; then
			if [ -n "${MISSING}" ]; then
				MISSING_MULTIPLE=true
			fi
			MISSING="${MISSING:+$MISSING }${FILE}"
		fi
	done
	if [ -z "${MISSING}" ]; then
		return 0
	fi

	if ! $MISSING_MULTIPLE; then
		Echo_error "the following stage is required to be done first: %s" "${MISSING}"
	else
		Echo_error "the following stages are required to be completed first: %s" "${MISSING}"
	fi

	exit 1
}
