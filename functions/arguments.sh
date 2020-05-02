#!/bin/sh

## live-build(7) - System Build Scripts
## Copyright (C) 2016-2020 The Debian Live team
## Copyright (C) 2006-2015 Daniel Baumann <mail@daniel-baumann.ch>
##
## This program comes with ABSOLUTELY NO WARRANTY; for details see COPYING.
## This is free software, and you are welcome to redistribute it
## under certain conditions; see COPYING for details.


Arguments ()
{
	local ARGUMENTS
	local ERR=0
	ARGUMENTS="$(getopt --longoptions breakpoints,color,debug,force,help,no-color,quiet,usage,verbose,version --name=${PROGRAM} --options huv --shell sh -- "${@}")" || ERR=$?

	if [ $ERR -eq 1 ]; then
		Echo_error "invalid arguments"
		exit 1
	elif [ $ERR -ne 0 ]; then
		Echo_error "getopt failure"
		exit 1
	fi

	eval set -- "${ARGUMENTS}"

	while true
	do
		case "${1}" in
			--breakpoints|--color|--debug|--force|-h|--help|--no-color|--quiet|-u|--usage|--verbose|-v|--version)
				Handle_common_option "${1}"
				shift
				;;

			--)
				shift
				break
				;;

			*)
				Echo_error "internal error %s" "${0}"
				exit 1
				;;
		esac
	done
}

Handle_common_option ()
{
	case "${1}" in
		--breakpoints)
			_BREAKPOINTS="true"
			;;

		--color)
			_COLOR="true"
			_COLOR_OUT="true"
			_COLOR_ERR="true"
			;;

		--no-color)
			_COLOR="false"
			_COLOR_OUT="false"
			_COLOR_ERR="false"
			;;

		--debug)
			_DEBUG="true"
			;;

		--force)
			_FORCE="true"
			;;

		-h|--help)
			Man
			;;

		--quiet)
			_QUIET="true"
			;;

		-u|--usage)
			Usage --exit
			;;

		--verbose)
			_VERBOSE="true"
			;;

		-v|--version)
			echo "${VERSION}"
			exit 0
			;;

		*)
			Echo_error "Internal error: Unknown common option '%s'" "${1}"
			exit 1
			;;
	esac
}
