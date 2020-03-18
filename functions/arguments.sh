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
	ARGUMENTS="$(getopt --longoptions breakpoints,color,no-color,conffile:,debug,force,help,quiet,usage,verbose,version --name=${PROGRAM} --options c:huv --shell sh -- "${@}")" || ERR=$?

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
			--breakpoints)
				_BREAKPOINTS="true"
				shift
				;;

			--color)
				_COLOR="true"
				_COLOR_OUT="true"
				_COLOR_ERR="true"
				shift
				;;

			--no-color)
				_COLOR="false"
				_COLOR_OUT="false"
				_COLOR_ERR="false"
				shift
				;;

			-c|--conffile)
				_CONFFILE="${2}"
				shift 2
				;;

			--debug)
				_DEBUG="true"
				shift
				;;

			--force)
				_FORCE="true"
				shift
				;;

			-h|--help)
				Man
				shift
				;;

			--quiet)
				_QUIET="true"
				shift
				;;

			-u|--usage)
				Usage
				shift
				;;

			--verbose)
				_VERBOSE="true"
				shift
				;;

			-v|--version)
				echo "${VERSION}"
				exit 0
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
