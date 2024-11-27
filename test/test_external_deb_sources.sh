#!/bin/bash

if ! command -v equivs-build > /dev/null; then
	echo "Install equivs"
	exit 1
fi
if ! command -v reprepro > /dev/null; then
	echo "Install reprepro"
	exit 1
fi

if ! command -v shunit2 > /dev/null; then
	echo "Install shunit2"
	exit 1
fi

if ! command -v faketime > /dev/null; then
	echo "Install faketime"
	exit 1
fi

function create_packages () {
	# Create package generator files
	cat << EOF > package
Source: live-testpackage-$1-main
Section: misc
Priority: optional
Standards-Version: 4.7.0

Package: live-testpackage-$1-main
Version: 1.0
Maintainer: Debian Live <debian-live@lists.debian.org>
Depends: live-testpackage-$1-dependency
Architecture: all
File: /etc/live-testpackage/testpackage-$1-main-file 644
 live-testpackage-$1-main has been installed
Description: Test package for testing the inclusion in live images
 Tests dependency chain
 Package live-testpackage-$1-dependency should be automatically installed and removed too
EOF
	faketime -f "$(date --utc -d@${SOURCE_DATE_EPOCH} +'%Y-%m-%d %H:%M:%SZ')" equivs-build package

	cat << EOF > package
Source: live-testpackage-$1-dependency
Section: misc
Priority: optional
Standards-Version: 4.7.0

Package: live-testpackage-$1-dependency
Version: 1.0
Maintainer: Debian Live <debian-live@lists.debian.org>
Architecture: all
File: /etc/live-testpackage/testpackage-$1-dependency-file 644
 The dependency for live-testpackage-$1-main has been installed
Description: Test package for testing the inclusion in live images
 Tests dependency chain
 This package should be automatically installed and removed too
EOF
	faketime -f "$(date --utc -d@${SOURCE_DATE_EPOCH} +'%Y-%m-%d %H:%M:%SZ')" equivs-build package
	rm package
}

function create_repository () {
	# See https://wiki.debian.org/DebianRepository/SetupWithReprepro
	# Collect in a repository
	rm -fr testrepository-$1
	mkdir -p testrepository-$1/conf
	touch testrepository-$1/conf/options
	cat << EOF > testrepository-$1/conf/distributions
Origin: Test_repository_for_testing_external_sources
Label: Test_repository_for_testing_external_sources
Codename: nondebian
Architectures: amd64 source
Components: mymain
Description: Test repository for testing external sources
EOF
	create_packages $1
	reprepro -b testrepository-$1 includedeb nondebian live-testpackage-$1-main_1.0_all.deb
	reprepro -b testrepository-$1 includedeb nondebian live-testpackage-$1-dependency_1.0_all.deb
}

function mountSquashfs() {
	assertTrue "ISO image has been generated" "[ -e live-image-amd64.hybrid.iso ]"
	mkdir iso squashfs
	mount live-image-amd64.hybrid.iso iso -oro
	mount iso/live/filesystem.squashfs squashfs -oro
}

function unmountSquashfs() {
	umount squashfs
	umount iso
	rmdir iso squashfs
}

function oneTimeSetUp() {
	# Speed up, because there is no compression of the ISO file
	export MKSQUASHFS_OPTIONS=-no-compression
}

function setUp() {
	# Create a test configuration
	lb clean --purge
	rm -fr config
	# Slight speedup: --zsync, --firmware-chroot, --cache
	lb config --distribution unstable --zsync false --firmware-chroot false --cache false
}

function build_image() {
	# Speed up
	export MKSQUASHFS_OPTIONS=-no-compression
	# Perform the build
	lb build
	if [ -e live-image-amd64.hybrid.iso ]
	then
		sha256sum --tag live-image-amd64.hybrid.iso
	fi
}

function test_snapshot_with_mirror_bootstrap() {
	# Rebuild the configuration, as many mirror settings depend on eachother
	lb clean --purge
	rm -fr config
	# Slight speedup: --zsync, --firmware-chroot, --cache
	lb config --distribution unstable --zsync false --firmware-chroot false --cache false --mirror-bootstrap http://snapshot.debian.org/archive/debian/20240701T000000Z/ --mirror-binary http://deb.debian.org/debian/
	# Insider knowledge of live-build:
	#   Add '-o Acquire::Check-Valid-Until=false', to allow for rebuilds of older timestamps 
	sed -i -e '/^APT_OPTIONS=/s/--yes/--yes -o Acquire::Check-Valid-Until=false/' config/common
	build_image
	mountSquashfs
	assertTrue "Sources.list mentions deb.d.o" "grep -q 'http://deb.debian.org/debian' squashfs/etc/apt/sources.list"
	assertTrue "Sources list meta info should be present" "[ -e squashfs/var/lib/apt/lists/deb\.debian\.org_debian_dists_unstable_main_binary-amd64_Packages ]"
	assertTrue "The kernel from the snapshot is used" "grep -q '^linux-image-6\.9\.7-amd64' chroot.packages.install"
	assertTrue "The kernel from the snapshot will be booted" "[ -e squashfs/boot/vmlinuz-6.9.7-amd64 ]"
	unmountSquashfs
}

function test_direct_inclusion_of_deb_unspecified_chroot_or_binary() {
	create_packages config-packages
	cp live-testpackage-config-packages-main_1.0_all.deb config/packages
	cp live-testpackage-config-packages-dependency_1.0_all.deb config/packages
	build_image
	assertTrue "Packaged file for main package should be present" "grep -q '^-rw-r--r--.* testpackage-config-packages-main-file$' chroot.files"
	assertTrue "Packaged file for dependency package should be present" "grep -q '^-rw-r--r--.* testpackage-config-packages-dependency-file$' chroot.files"
	assertTrue "Main package is installed (install)" "grep -q '^live-testpackage-config-packages-main' chroot.packages.install"
	assertTrue "Dependency package is installed (install)" "grep -q '^live-testpackage-config-packages-dependency' chroot.packages.install"
	assertTrue "Main package is installed (live)" "grep -q '^live-testpackage-config-packages-main' chroot.packages.live"
	assertTrue "Dependency package is installed (live)" "grep -q '^live-testpackage-config-packages-dependency' chroot.packages.live"
}

function test_direct_inclusion_of_deb_binary() {
	create_packages config-packages-binary
	cp live-testpackage-config-packages-binary-main_1.0_all.deb config/packages.binary
	cp live-testpackage-config-packages-binary-dependency_1.0_all.deb config/packages.binary
	# config/packages.binary is only used when an installer is requested
	lb config --debian-installer live
	build_image
	assertFalse "Packaged file for main package should not be present" "grep -q '^-rw-r--r--.* testpackage-config-packages-binary-main-file$' chroot.files"
	assertFalse "Packaged file for dependency package should not be present" "grep -q '^-rw-r--r--.* testpackage-config-packages-binary-dependency-file$' chroot.files"
	assertFalse "Main package is not installed (install)" "grep -q '^live-testpackage-config-packages-binary-main' chroot.packages.install"
	assertFalse "Dependency package is not installed (install)" "grep -q '^live-testpackage-config-packages-binary-dependency' chroot.packages.install"
	assertFalse "Main package is not installed (live)" "grep -q '^live-testpackage-config-packages-binary-main' chroot.packages.live"
	assertFalse "Dependency package is not installed (live)" "grep -q '^live-testpackage-config-packages-binary-dependency' chroot.packages.live"
	mountSquashfs
	assertTrue "Main package should be in the pool" "[ -e iso/pool/main/l/live-testpackage-config-packages-binary-main/live-testpackage-config-packages-binary-main_1.0_all.deb ]"
	assertTrue "Dependency package should be in the pool" "[ -e iso/pool/main/l/live-testpackage-config-packages-binary-dependency/live-testpackage-config-packages-binary-dependency_1.0_all.deb ]"
	assertTrue "Package pool is listed in /etc/apt/sources.list" "grep -q 'file:/run/live/medium' squashfs/etc/apt/sources.list"
	assertTrue "Sources list meta info should be present" "[ -e squashfs/var/lib/apt/lists/_run_live_medium_dists_unstable_Release ]"
	assertTrue "Sources list meta info should be present" "[ -e squashfs/var/lib/apt/lists/_run_live_medium_dists_unstable_main_binary-amd64_Packages ]"
	unmountSquashfs
}

function test_direct_inclusion_of_deb_chroot() {
	create_packages config-packages-chroot
	cp live-testpackage-config-packages-chroot-main_1.0_all.deb config/packages.chroot
	cp live-testpackage-config-packages-chroot-dependency_1.0_all.deb config/packages.chroot
	build_image
	assertTrue "Packaged file for main package should be present" "grep -q '^-rw-r--r--.* testpackage-config-packages-chroot-main-file$' chroot.files"
	assertTrue "Packaged file for dependency package should be present" "grep -q '^-rw-r--r--.* testpackage-config-packages-chroot-dependency-file$' chroot.files"
	assertTrue "Main package is installed (install)" "grep -q '^live-testpackage-config-packages-chroot-main' chroot.packages.install"
	assertTrue "Dependency package is installed (install)" "grep -q '^live-testpackage-config-packages-chroot-dependency' chroot.packages.install"
	assertTrue "Main package is installed (live)" "grep -q '^live-testpackage-config-packages-chroot-main' chroot.packages.live"
	assertTrue "Dependency package is installed (live)" "grep -q '^live-testpackage-config-packages-chroot-dependency' chroot.packages.live"
}

function test_remote_repository_unspecified_choot_or_binary() {
	cat << EOF > config/archives/remote-config-archives-list.list
deb [signed-by=/etc/apt/trusted.gpg.d/ubuntu-archive-keyring.gpg.key.gpg] http://archive.ubuntu.com/ubuntu noble main
EOF
	# We need something that is not in Debian.
	# Let's use the live image building tool from Ubuntu ;-)
	echo "casper" > config/package-lists/remote-config-archives-list.list

	# Manually fetch the key for Ubuntu
	wget --quiet https://salsa.debian.org/debian/ubuntu-keyring/-/raw/master/keyrings/ubuntu-archive-keyring.gpg?ref_type=heads -O config/archives/ubuntu-archive-keyring.gpg.key

	build_image
	assertTrue "Package is installed (install)" "grep -q '^casper' chroot.packages.install"
	assertTrue "Package is installed (live)" "grep -q '^casper' chroot.packages.live"

	mountSquashfs
	assertTrue "Sources list should be present" "[ -e squashfs/etc/apt/sources.list.d/remote-config-archives-list.list ]"
	assertTrue "Sources list meta info should be present" "[ -e squashfs/var/lib/apt/lists/archive.ubuntu.com_ubuntu_dists_noble_main_binary-amd64_Packages ]"
	unmountSquashfs
}

function test_remote_repository_chroot() {
	cat << EOF > config/archives/remote-config-archives-list-chroot.list
deb [signed-by=/etc/apt/trusted.gpg.d/ubuntu-archive-keyring.gpg.key.chroot.gpg] http://archive.ubuntu.com/ubuntu noble main
EOF
	# We need something that is not in Debian.
	# Let's use the live image building tool from Ubuntu ;-)
	echo "casper" > config/package-lists/remote-config-archives-list-chroot.list.chroot

	# Manually fetch the key for Ubuntu
	wget --quiet https://salsa.debian.org/debian/ubuntu-keyring/-/raw/master/keyrings/ubuntu-archive-keyring.gpg?ref_type=heads -O config/archives/ubuntu-archive-keyring.gpg.key.chroot

	build_image
	assertTrue "Package is installed (install)" "grep -q '^casper' chroot.packages.install"
	assertTrue "Package is installed (live)" "grep -q '^casper' chroot.packages.live"

	mountSquashfs
	assertTrue "Sources list should be present" "[ -e squashfs/etc/apt/sources.list.d/remote-config-archives-list-chroot.list ]"
	assertTrue "Sources list meta info should be present" "[ -e squashfs/var/lib/apt/lists/archive.ubuntu.com_ubuntu_dists_noble_main_binary-amd64_Packages ]"
	unmountSquashfs
}

function test_remote_repository_binary() {
	cat << EOF > config/archives/remote-config-archives-list-binary.list.binary
deb [signed-by=/etc/apt/trusted.gpg.d/ubuntu-archive-keyring.gpg.key.binary.gpg] http://archive.ubuntu.com/ubuntu noble main
EOF
	# We need something that is not in Debian.
	# Let's use the live image building tool from Ubuntu ;-)
	echo "casper" > config/package-lists/remote-config-archives-list-binary.list.binary

	# Manually fetch the key for Ubuntu
	wget --quiet https://salsa.debian.org/debian/ubuntu-keyring/-/raw/master/keyrings/ubuntu-archive-keyring.gpg?ref_type=heads -O config/archives/ubuntu-archive-keyring.gpg.key.binary

	build_image
	assertFalse "Package is not installed (install)" "grep -q '^casper' chroot.packages.install"
	assertFalse "Package is not installed (live)" "grep -q '^casper' chroot.packages.live"

	mountSquashfs
	assertTrue "Sources list should be present" "[ -e squashfs/etc/apt/sources.list.d/remote-config-archives-list-binary.list ]"
	assertTrue "Sources list meta info should be present" "[ -e squashfs/var/lib/apt/lists/archive.ubuntu.com_ubuntu_dists_noble_main_binary-amd64_Packages ]"
	assertTrue "Package should be in the pool" "find iso | grep 'iso/pool/main/c/casper/casper_.*_amd64\.deb'"
	unmountSquashfs
}

function test_local_repository_unspecified_chroot_or_binary() {
	create_repository config-archives-list
	cat << EOF > config/archives/my_repro-config-archives-list.list
deb [trusted=yes] file://$(pwd)/testrepository-config-archives-list nondebian mymain
EOF
	echo "live-testpackage-config-archives-list-main" > config/package-lists/my_repro-config-archives-list.list

	build_image
	assertNotNull "Not implemented yet: fails at bootstrap_archives at the moment" ""
	assertTrue "Packaged file for main package should be present" "grep -q '^-rw-r--r--.* testpackage-config-archives-list-main-file$' chroot.files"
	assertTrue "Packaged file for dependency package should be present" "grep -q '^-rw-r--r--.* testpackage-config-archives-list-dependency-file$' chroot.files"
	assertTrue "Main package is installed (install)" "grep -q '^live-testpackage-config-archives-list-main' chroot.packages.install"
	assertTrue "Dependency package is installed (install)" "grep -q '^live-testpackage-config-archives-list-dependency' chroot.packages.install"
	assertTrue "Main package is installed (live)" "grep -q '^live-testpackage-config-archives-list-main' chroot.packages.live"
	assertTrue "Dependency package is installed (live)" "grep -q '^live-testpackage-config-archives-list-dependency' chroot.packages.live"

	mountSquashfs
	# The following files should not be present
	# -> however, they currently are, because there is not detection whether the repo is reachable from within the running live environment
	# -> this will result in an error message when 'apt-get update' is run in the live environment
	#  /etc/apt/sources.list.d/my_repro-config-archives-list.list
	#  /var/lib/apt/lists/_*_testrepository-config-archives-list-*_Release
	#  /var/lib/apt/lists/_*_testrepository-config-archives-list-*_Packages
	assertFalse "Sources list should not be present" "[ -e squashfs/etc/apt/sources.list.d/my_repro-config-archives-list.list ]"
	assertFalse "Sources list meta info should not be present" "find squashfs/var/lib/apt/lists | grep -q 'squashfs/var/lib/apt/lists/_*_testrepository-config-archives-list-'"
	unmountSquashfs
}

function test_local_repository_chroot() {
	create_repository config-archives-list-chroot
	cat << EOF > config/archives/my_repro-config-archives-list-chroot.list.chroot
deb [trusted=yes] file://$(pwd)/testrepository-config-archives-list-chroot nondebian mymain
EOF
	echo "live-testpackage-config-archives-list-chroot-main" > config/package-lists/my_repro-config-archives-list-chroot.list.chroot

	build_image
	assertNotNull "Not implemented yet: fails at bootstrap_archives at the moment" ""
	assertTrue "Packaged file for main package should be present" "grep -q '^-rw-r--r--.* testpackage-config-archives-list-chroot-main-file$' chroot.files"
	assertTrue "Packaged file for dependency package should be present" "grep -q '^-rw-r--r--.* testpackage-config-archives-list-chroot-dependency-file$' chroot.files"
	assertTrue "Main package is installed (install)" "grep -q '^live-testpackage-config-archives-list-chroot-main' chroot.packages.install"
	assertTrue "Dependency package is installed (install)" "grep -q '^live-testpackage-config-archives-list-chroot-dependency' chroot.packages.install"
	assertTrue "Main package is installed (live)" "grep -q '^live-testpackage-config-archives-list-chroot-main' chroot.packages.live"
	assertTrue "Dependency package is installed (live)" "grep -q '^live-testpackage-config-archives-list-chroot-dependency' chroot.packages.live"

	mountSquashfs
	# The following files should not be present
	# -> however, they currently are, because there is not detection whether the repo is reachable from within the running live environment
	# -> this will result in an error message when 'apt-get update' is run in the live environment
	#  /etc/apt/sources.list.d/my_repro-config-archives-list-chroot.list
	#  /var/lib/apt/lists/_*_testrepository-config-archives-list-chroot-*_Release
	#  /var/lib/apt/lists/_*_testrepository-config-archives-list-chroot-*_Packages
	assertFalse "Sources list should not be present" "[ -e squashfs/etc/apt/sources.list.d/my_repro-config-archives-list-chroot.list ]"
	assertFalse "Sources list meta info should not be present" "find squashfs/var/lib/apt/lists | grep -q 'squashfs/var/lib/apt/lists/_*_testrepository-config-archives-list-chroot-'"
	unmountSquashfs
}

function test_local_repository_binary() {
	# Skip the .list.binary scenario for now
	# -> the bind mount is not activated properly
	create_repository config-archives-list-binary
	cat << EOF > config/archives/my_repro-config-archives.list-binary.list.binary
deb [trusted=yes] file://$(pwd)/testrepository-config-archives-list-binary nondebian mymain
EOF
	echo "live-testpackage-config-archives-list-binary-main" > config/package-lists/my_repro-config-archives-list-binary.list.binary

	build_image
	assertNotNull "Not implemented yet: fails at lb chroot_prep remove all mode-archives-chroot with step lb chroot_archives chroot remove at the moment" ""
	assertFalse "Packaged file for main package should not be present" "grep -q '^-rw-r--r--.* testpackage-config-archives-list-binary-main-file$' chroot.files"
	assertFalse "Packaged file for dependency package should not be present" "grep -q '^-rw-r--r--.* testpackage-config-archives-list-binary-dependency-file$' chroot.files"
	assertFalse "Main package is not installed (install)" "grep -q '^live-testpackage-config-archives-list-binary-main' chroot.packages.install"
	assertFalse "Dependency package is not installed (install)" "grep -q '^live-testpackage-config-archives-list-binary-dependency' chroot.packages.install"
	assertFalse "Main package is not installed (live)" "grep -q '^live-testpackage-config-archives-list-binary-main' chroot.packages.live"
	assertFalse "Dependency package is not installed (live)" "grep -q '^live-testpackage-config-archives-list-binary-dependency' chroot.packages.live"
	mountSquashfs
	assertTrue "Main package should be in the pool" "[ -e iso/pool/main/l/live-testpackage-config-archives-list-binary-main/live-testpackage-config-archives-list-binary-main_1.0_all.deb ]"
	assertTrue "Dependency package should be in the pool" "[ -e iso/pool/main/l/live-testpackage-config-archives-list-binary-dependency/live-testpackage-config-archives-list-binary-dependency_1.0_all.deb ]"
	assertTrue "Package pool is listed in /etc/apt/sources.list" "grep -q 'file:/run/live/medium' squashfs/etc/apt/sources.list"
	assertTrue "Sources list meta info should be present" "[ -e squashfs/var/lib/apt/lists/_run_live_medium_dists_unstable_Release ]"
	assertTrue "Sources list meta info should be present" "[ -e squashfs/var/lib/apt/lists/_run_live_medium_dists_unstable_main_binary-amd64_Packages ]"
	unmountSquashfs
}

function test_embedded_repository() {
	# An embedded repository scenario
	# -> it fails in the bootstrap phase, because the files are copied later in the chroot step!

	create_repository config-opt-extra-repo

	mkdir -p config/includes.chroot_before_packages/opt/extrarepo/dists
	mkdir -p config/includes.chroot_before_packages/opt/extrarepo/pool
	cp -a testrepository-config-opt-extra-repo/dists/* config/includes.chroot_before_packages/opt/extrarepo/dists
	cp -a testrepository-config-opt-extra-repo/pool/* config/includes.chroot_before_packages/opt/extrarepo/pool

	# Note it uses '.list', because the repository should be functional after the chroot is sealed
	cat << EOF > config/archives/my_repro-config-opt-extra-repo.list
deb [trusted=yes] file:///opt/extrarepo nondebian mymain
EOF
	echo "live-testpackage-config-opt-extra-repo-main" > config/package-lists/my_repro-config-opt-extra-repo.list

	build_image
	assertNotNull "Not implemented yet: fails at bootstrap_archives at the moment" ""
	# Current issue: the /etc/apt/sources.list.d entry gets removed, but the index files and the packages are installed in the chroot
	assertTrue "Packaged file for main package should be present" "grep -q '^-rw-r--r--.* testpackage-config-opt-extra-repo-main-file$' chroot.files"
	assertTrue "Packaged file for dependency package should be present" "grep -q '^-rw-r--r--.* testpackage-config-opt-extra-repo-dependency-file$' chroot.files"
	assertTrue "Main package is installed (install)" "grep -q '^live-testpackage-config-opt-extra-repo-main' chroot.packages.install"
	assertTrue "Dependency package is installed (install)" "grep -q '^live-testpackage-config-opt-extra-repo-dependency' chroot.packages.install"
	assertTrue "Main package is installed (live)" "grep -q '^live-testpackage-config-opt-extra-repo-main' chroot.packages.live"
	assertTrue "Dependency package is installed (live)" "grep -q '^live-testpackage-config-opt-extra-repo-dependency' chroot.packages.live"
}

function test_derivatives() {
	# Rebuild the configuration, as many mirror settings depend on eachother
	#lb clean --purge
	#rm -fr config
	# Slight speedup: --zsync, --firmware-chroot, --cache
	#lb config --distribution unstable --zsync false --firmware-chroot false --cache false
	# Let's not test --parent-distribution-chroot at the moment:
	# --apt-secure false --parent-mirror-chroot file://localhost$(pwd)/testrepository --parent-distribution-chroot nondebian --parent-archive-areas mymain --mirror-chroot http://deb.debian.org/debian --distribution-chroot debian --archive-areas main --parent-mirror-bootstrap file://localhost$(pwd)/testrepository
	# --apt-secure false --mirror-chroot file://localhost$(pwd)/testrepository-mirror-chroot --distribution-chroot nondebian --archive-areas mymain --parent-mirror-chroot http://deb.debian.org/debian --parent-distribution-chroot unstable --parent-archive-areas main

	#build_image
	#mountSquashfs
	assertNotNull "Not implemented (yet): this can be quite complicated" ""
	#unmountSquashfs
}

SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(date --utc '+%s')}"
ISO8601_TIMESTAMP=$(date --utc -d@${SOURCE_DATE_EPOCH} +%Y-%m-%dT%H:%M:%SZ)
. shunit2 2> logfile_${ISO8601_TIMESTAMP}.stderr | tee logfile_${ISO8601_TIMESTAMP}.stdout
egrep "ASSERT|FAILED|OK|shunit2|test_|SHA256" logfile_${ISO8601_TIMESTAMP}.stdout | tee logfile_${ISO8601_TIMESTAMP}.summary
