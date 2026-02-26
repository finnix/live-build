#!/bin/bash
#
# Register the live images on openQA for functionality tests

OPENQACLI="openqa-cli"

# 0 = Official released version
# 1 = Weekly build
DO_WEEKLY_VERSION=1
# This switch is active only for official released versions
# 0 = trixie (stable)
# 1 = bookworm (oldstable)
DO_BOOKWORM=0

# No user-configurable settings after this line

if [ ${DO_WEEKLY_VERSION} -eq 0 ]
then
	if [ ${DO_BOOKWORM} -eq 1 ]
	then
		SUITE=oldstable
		SUITECODENAME=bookworm
		SUITENUMBER=12.13.0
		OPENQA_GROUPID=19
		BASIS_URL=https://get.debian.org/mirror/cdimage/archive/${SUITENUMBER}-live/amd64/iso-hybrid
	else
		BASIS_URL=https://get.debian.org/images/release/current-live/amd64/iso-hybrid
		SUITE=stable
		SUITECODENAME=trixie
		SUITENUMBER=13.3.0
		OPENQA_GROUPID=18
	fi
	BUILD_SUFFIX="o"
	ISO_INFIX="official"
else
	BASIS_URL=https://get.debian.org/images/weekly-live-builds/amd64/iso-hybrid
	SUITE=testing
	SUITECODENAME=forky
	OPENQA_GROUPID=23
	BUILD_SUFFIX="w"
	ISO_INFIX="weekly"
fi

if [ ${DO_BOOKWORM} -eq 1 ];
then
	# No Debian Junior for bookworm
	SEQUENCE_TOP=8
else
	SEQUENCE_TOP=9
fi

rm SHA256SUMS
sq download --quiet --batch --signature-url ${BASIS_URL}/SHA256SUMS.sign --url ${BASIS_URL}/SHA256SUMS --output SHA256SUMS

for i in $(seq 1 ${SEQUENCE_TOP}); do
	FLAVOR=""
	case $i in
		1)
			DESKTOP=gnome
			;;
		2)
			DESKTOP=xfce
			;;
		3)
			DESKTOP=kde
			;;
		4)
			DESKTOP=lxqt
			;;
		5)
			DESKTOP=mate
			;;
		6)
			DESKTOP=cinnamon
			;;
		7)
			DESKTOP=lxde
			;;
		8)
			DESKTOP=standard
			;;
		9)
			DESKTOP=debian-junior
			FLAVOR=junior
			;;
	esac

	# FLAVOR=DESKTOP unless it already has been set
	FLAVOR="${FLAVOR:-${DESKTOP}}"

	# Prepare settings
	if [ ${DO_WEEKLY_VERSION} -eq 0 ]
	then
		ISONAME=debian-live-${SUITENUMBER}-amd64-${DESKTOP}.iso
	else
		ISONAME=debian-live-${SUITE}-amd64-${DESKTOP}.iso
	fi
	
	TIMESTAMP=$(date +%Y%m%dT%H%M%SZ --utc --date="$(curl --silent --head --location ${BASIS_URL}/${ISONAME} | sed -e '/^Last-Modified:/{s/Last-Modified: //;p};d')")
	BUILD=$(echo ${TIMESTAMP} | awk '{ c=split($0, a, "_"); print substr(a[c],1, 8); }')${BUILD_SUFFIX}
		
	# Extract the checksum (no need to download the file)
	CHECKSUM=$(grep " ${ISONAME}$" SHA256SUMS | cut -f 1 -d " ")

	# Send to openQA
	${OPENQACLI} api -X POST isos ISO=${DESKTOP}_${SUITE}_${ISO_INFIX}_${TIMESTAMP}.iso DISTRI=debian-live VERSION=${SUITECODENAME} FLAVOR=${FLAVOR} ARCH=x86_64 BUILD=${BUILD} TIMESTAMP=${TIMESTAMP} --odn ISO_URL=${BASIS_URL}/${ISONAME} CHECKSUM=${CHECKSUM}
done

# Apply tags
rm comments.json
if [ ${DO_WEEKLY_VERSION} -eq 0 ]
then
	TAGTEXT="tag:${BUILD}:important:${SUITENUMBER} The official builds from ${BASIS_URL}"
	COMMENTID=""
else
	${OPENQACLI} api -X GET groups/${OPENQA_GROUPID}/comments --odn > comments.json
	# Adjust the tag to point to the latest build
	COMMENTID=$(jq '.[] | {text, id}' comments.json | awk "\$2 ~ /:important:latest/ { getline; print \$2 }")
	TAGTEXT="tag:${BUILD}:important:latest The official weekly builds from ${BASIS_URL}"
fi
if [ -n "${COMMENTID}" ]
then
	${OPENQACLI} api -X PUT groups/${OPENQA_GROUPID}/comments/${COMMENTID} text="${TAGTEXT}" --odn
else
	${OPENQACLI} api -X POST groups/${OPENQA_GROUPID}/comments text="${TAGTEXT}" --odn
fi

