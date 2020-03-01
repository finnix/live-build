#!/bin/sh

## live-build(7) - System Build Scripts
## Copyright (C) 2006-2015 Daniel Baumann <mail@daniel-baumann.ch>
##
## This program comes with ABSOLUTELY NO WARRANTY; for details see COPYING.
## This is free software, and you are welcome to redistribute it
## under certain conditions; see COPYING for details.


Echo ()
{
	STRING="${1}"
	shift

	printf "${STRING}\n" "${@}" >&1
}

Echo_debug ()
{
	if [ "${_DEBUG}" = "true" ]
	then
		STRING="${1}"
		shift

		printf "D: ${STRING}\n" "${@}" >&1
	fi
}

Echo_error ()
{
	STRING="${1}"
	shift

	if [ "${_COLOR}" = "false" ]
	then
		printf "E:" >&2
	else
		printf "${RED}E${NO_COLOR}:" >&2
	fi

	printf " ${STRING}\n" "${@}" >&2
}

Echo_message ()
{
	if [ "${_QUIET}" != "true" ]
	then
		STRING="${1}"
		shift

		if [ "${_COLOR}" = "false" ]
		then
			printf "P:" >&1
		else
			printf "${WHITE}P${NO_COLOR}:" >&1
		fi

		printf " ${STRING}\n" "${@}" >&1
	fi
}

Echo_verbose ()
{
	if [ "${_VERBOSE}" = "true" ]
	then
		STRING="${1}"
		shift

		printf "I: ${STRING}\n" "${@}" >&1
	fi
}

Echo_warning ()
{
	STRING="${1}"
	shift

	if [ "${_COLOR}" = "false" ]
	then
		printf "W:" >&2
	else
		printf "${YELLOW}W${NO_COLOR}:" >&2
	fi

	printf " ${STRING}\n" "${@}" >&2
}

Echo_file ()
{
	while read LINE
	do
		echo "${1}: ${LINE}" >&1
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
