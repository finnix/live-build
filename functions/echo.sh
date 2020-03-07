#!/bin/sh

## live-build(7) - System Build Scripts
## Copyright (C) 2016-2020 The Debian Live team
## Copyright (C) 2006-2015 Daniel Baumann <mail@daniel-baumann.ch>
##
## This program comes with ABSOLUTELY NO WARRANTY; for details see COPYING.
## This is free software, and you are welcome to redistribute it
## under certain conditions; see COPYING for details.

exec 3>&1

Echo ()
{
	STRING="${1}"
	shift

	printf "${STRING}\n" "${@}" >&3
}

Echo_debug ()
{
	if [ "${_DEBUG}" = "true" ]; then
		STRING="${1}"
		shift

		printf "D: ${STRING}\n" "${@}" >&3
	fi
}

Echo_error ()
{
	STRING="${1}"
	shift

	local PREFIX="${RED}E${NO_COLOR}"
	if [ "${_COLOR}" = "false" ]; then
		PREFIX="E"
	fi

	printf "${PREFIX}: ${STRING}\n" "${@}" >&2
}

Echo_message ()
{
	if [ "${_QUIET}" != "true" ]
	then
		STRING="${1}"
		shift

		local PREFIX="${BOLD}P${NO_COLOR}"
		if [ "${_COLOR}" = "false" ]; then
			PREFIX="P"
		fi

		printf "${PREFIX}: ${STRING}\n" "${@}" >&3
	fi
}

Echo_verbose ()
{
	if [ "${_VERBOSE}" = "true" ]; then
		STRING="${1}"
		shift

		printf "I: ${STRING}\n" "${@}" >&3
	fi
}

Echo_warning ()
{
	STRING="${1}"
	shift

	local PREFIX="${YELLOW}W${NO_COLOR}"
	if [ "${_COLOR}" = "false" ]; then
		PREFIX="W"
	fi

	printf "${PREFIX}: ${STRING}\n" "${@}" >&2
}

Echo_file ()
{
	while read -r LINE
	do
		echo "${1}: ${LINE}" >&3
	done < "${1}"
}

Echo_breakage ()
{
	case "${LB_PARENT_DISTRIBUTION_BINARY}" in
		sid)
			Echo_message "If the following stage fails, the most likely cause of the problem is with your mirror configuration, a caching proxy or the sid distribution."
			;;
		*)
			Echo_message "If the following stage fails, the most likely cause of the problem is with your mirror configuration or a caching proxy."
			;;
	esac

	Echo_message "${@}"
}
