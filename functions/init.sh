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

Init_config_data ()
{
	Arguments "${@}"

	Read_conffiles $(Common_config_files)
	Set_defaults
}
