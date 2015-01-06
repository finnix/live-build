#!/bin/sh

## live-build(7) - System Build Scripts
## Copyright (C) 2006-2015 Daniel Baumann <mail@daniel-baumann.ch>
##
## This program comes with ABSOLUTELY NO WARRANTY; for details see COPYING.
## This is free software, and you are welcome to redistribute it
## under certain conditions; see COPYING for details.


Usage ()
{
	printf "%s - %s\n\n" "${PROGRAM}" "${DESCRIPTION}"
	printf "Usage:\n\n"

	if [ -n "${USAGE}" ]
	then
		printf "  %s\n" "${USAGE}"
	fi

	printf "  %s [-h|--help]\n" "${PROGRAM}"
	printf "  %s [-u|--usage]\n" "${PROGRAM}"
	printf "  %s [-v|--version]\n" "${PROGRAM}"

	printf "\nTry \"%s --help\" for more information.\n" "${PROGRAM}"

	exit 1
}
