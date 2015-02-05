#!/bin/sh

## live-build(7) - System Build Scripts
## Copyright (C) 2006-2014 Daniel Baumann <mail@daniel-baumann.ch>
##
## This program comes with ABSOLUTELY NO WARRANTY; for details see COPYING.
## This is free software, and you are welcome to redistribute it
## under certain conditions; see COPYING for details.


Common_config_files ()
{
	echo "config/all config/common config/bootstrap config/chroot config/binary config/source"
}

Auto_build_config ()
{
	# Automatically build config
	if [ -x auto/config ] && [ ! -e .build/config ]; then
		Echo_message "Automatically populating config tree."
		lb config
	fi
}

Init_config_data ()
{
	Arguments "${@}"

	Read_conffiles $(Common_config_files)
	Set_config_defaults
}

Maybe_auto_redirect ()
{
	local TYPE="${1}"; shift

	case "${TYPE}" in
		clean|config|build)
			;;
		*)
			Echo_error "Unknown auto redirect type"
			exit 1
			;;
	esac

	local AUTO_SCRIPT="auto/${TYPE}"
	if [ -x "${AUTO_SCRIPT}" ]; then
		Echo_message "Executing ${AUTO_SCRIPT} script."
		./"${AUTO_SCRIPT}" "${@}"
		exit ${?}
	fi
}
