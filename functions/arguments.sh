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
	# This function is used for handling arguments both at the frontend (`lb`)
	# level and at the command level, since both accept almost the same basic
	# argument set, with little difference in response to them.
	#
	# We enlist the help of getopt here which takes care of some of the
	# intricacies of parsing for us. Note that getopt does not itself
	# understand the concept of "command" arguments, and the behaviour of it
	# shuffling non-options (those arguments that are not options or option
	# values) to the end of the argument list would present a difficulty, if it
	# were not for the fact that you can control this behaviour with use of the
	# `POSIXLY_CORRECT` environment variable; setting this variable causes
	# getopt to stop parsing arguments once it encounters the first non-option,
	# treating all remaining arguments as being non-options. Note also that
	# getopt always outputs a `--` separator argument between option (including
	# option value) arguments and non-option arguments.
	#
	# At the frontend we need getopt to only parse options up to the point of
	# a command. A command as far as getopt is concerned is simply a
	# "non-option" argument. Using the above mentioned `POSIXLY_CORRECT`
	# environment variable when parsing for the frontend, we can thus have
	# getopt process options up to the first non-option, if given, which should
	# be our command. We can then pass back any remaining arguments including
	# the command argument, for a second command-stage handling. If no command
	# is given, this is trivial to handle. If an invalid option is used before
	# a command, this is caught by getopt.
	#
	# When a command is run, it is passed all remaining arguments, with most
	# scripts then passing them to this function, with argument parsing then
	# occurring in command-context, which just so happens to use almost the same
	# set of arguments for most scripts (the config command is a notable
	# exception).
	#
	# It is true that many of the common options have no effect in the frontend
	# currently, but some do, such as colour control, and others could do in
	# future or during development.
	#
	# Note, do not worry about options unavailable in frontend mode being
	# handled in the case statement, they will never reach there if used for the
	# frontend (i.e. before a command), they will result in an invalid option
	# error!

	local LONGOPTS="breakpoints,color,debug,help,no-color,quiet,usage,verbose,version"
	local SHORTOPTS="huv"

	local IS_FRONTEND="false"
	if [ "${1}" = "frontend" ]; then
		shift
		IS_FRONTEND="true"
	else
		LONGOPTS="${LONGOPTS},force"
	fi

	local GETOPT_ARGS="--name=${PROGRAM} --shell sh --longoptions $LONGOPTS --options $SHORTOPTS"

	local ARGUMENTS
	local ERR=0
	if [ "${IS_FRONTEND}" = "true" ]; then
		ARGUMENTS="$(export POSIXLY_CORRECT=1; getopt $GETOPT_ARGS -- "${@}")" || ERR=$?
	else
		ARGUMENTS="$(getopt $GETOPT_ARGS -- "${@}")" || ERR=$?
	fi

	if [ $ERR -eq 1 ]; then
		Echo_error "Invalid argument(s)"
		exit 1
	elif [ $ERR -ne 0 ]; then
		Echo_error "getopt failure"
		exit 1
	fi

	# Replace arguments with result of getopt processing (e.g. with non-options shuffled to end)
	# Note that this only affects this function's parameter set, not the calling function's or
	# calling script's argument set.
	eval set -- "${ARGUMENTS}"

	local ARG
	for ARG in "$@"; do
		case "${ARG}" in
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

			--debug)
				_DEBUG="true"
				shift
				;;

			--force)
				_FORCE="true"
				shift
				;;

			-h|--help)
				if [ $(which man) ]; then
					if [ "${IS_FRONTEND}" = "true" ]; then
						man ${PROGRAM}
					else
						man ${PROGRAM} $(basename ${0})
					fi
					exit 0
				elif [ "${IS_FRONTEND}" = "true" ]; then
					Usage
				fi
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
				if [ "${IS_FRONTEND}" = "true" ]; then
					# We have handled all frontend options up to what we assume to be a command
					break
				fi
				Echo_error "Internal error, unhandled option: %s" "${ARG}"
				exit 1
				;;
		esac
	done

	# Return remaining args
	# Much more simple than trying to deal with command substitution.
	REMAINING_ARGS="$@"
}
