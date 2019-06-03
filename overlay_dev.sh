#!/bin/bash

PKGLIST=${PKGLIST:-$(cd $(dirname $0); pwd -P)/deepin-pkg-list}
OVERLAYDIR=${OVERLAYDIR:-/var/lib/layman/deepin}

gitMSG=""

function verinfo() {

	# catalog="dde-base/dde-dock"
	catalog="$1"
	pkgname=${catalog##*/}

	# curVer=$(ls ${catalog}/*.ebuild | xargs -l basename | sed -E 's/.*-([0-9]+[\.0-9+]*).*\.ebuild/\1/' | sort -r -V | head -n1)
	curVerEbuild=$(ls ${catalog}/*.ebuild | xargs -l basename | sort -r -V | head -n1)
	curVer=$(echo "${curVerEbuild}" | sed -E 's/.*-([0-9]+[\.0-9+]*).*\.ebuild/\1/') 

	countVer=$(ls ${catalog}/*.ebuild | wc -l)

	oldVerEbuild=$(ls ${catalog}/*.ebuild | xargs -l basename | sort -V | head -n1)
	oldVer=$(echo "${oldVerEbuild}" | sed -E 's/.*-([0-9]+[\.0-9+]*).*\.ebuild/\1/') 

	# github homepage
	HOME=$(grep "HOMEPAGE" ${catalog}/${curVerEbuild}  | sed -E 's/.*"(.*)".*/\1/' | head -n1)

}

# compare versions
# verlte: reture true when par $1 <= $2
function verlte() {
	printf '%s\n%s' "$1" "$2" | sort -C -V
}

# verlt: return true when par $1 < $2
function verlt() { 
	! verlte "$2" "$1" 
}

function verBump() {

	if [[ -z ${repoVer} ]]; then
		echo "ERROR: upstream version not set." >> /dev/stderr
		return 2
	fi

	cp ${catalog}/${curVerEbuild} ${catalog}/${pkgname}-${repoVer}.ebuild

	ebuild ${catalog}/${pkgname}-${repoVer}.ebuild manifest || return 2

	ebuild ${catalog}/${pkgname}-${repoVer}.ebuild install || return 3

	ebuild ${catalog}/${pkgname}-${repoVer}.ebuild clean

	git add ${catalog}

	#git commit -m "Version bump: ${pkgname}-${repoVer}"
	gitMSG="${gitMSG}${pkgname}-${repoVer}, "
}

# Special for dev-qt/qtxcb-private-headers
function qtheaders() {

	catalog="dev-qt/qtxcb-private-headers"
	pkgname=${catalog##*/}

	# curVer=$(ls ${catalog}/*.ebuild | xargs -l basename | sed -E 's/.*-([0-9]+[\.0-9+]*).*\.ebuild/\1/' | sort -r -V | head -n1)
	curVerEbuilds=$(ls ${catalog}/*.ebuild | xargs -l basename | sort -r -V)
	curVers=$(echo "${curVerEbuilds}" | sed -E 's/.*-([0-9]+[\.0-9+]*).*\.ebuild/\1/') 

	repoVers=$(ls /usr/portage/dev-qt/qtcore/qtcore*.ebuild | xargs -l basename | sed -E 's/.*-([0-9]+[\.0-9+]*).*\.ebuild/\1/') 

	case "$1" in
		update)
			for version in `echo "${repoVers}"`
			do
				echo "${curVers}" | grep -q "${version}" 
				if [[ "$?" != 0 ]]; then
					cp ${catalog}/$(echo ${curVerEbuilds} | head -n1) ${catalog}/${pkgname}-${version}.ebuild

					ebuild ${catalog}/${pkgname}-${version}.ebuild manifest

					git add ${catalog}
					gitMSG="${gitMSG}${pkgname}-${version}, "
				fi
			done

			;;
		clean)
			for version in `echo "${curVers}"`
			do
				echo "${repoVers}" | grep -q "${version}" 
				if [[ "$?" != 0 ]]; then
					rm ${catalog}/${pkgname}-${version}*.ebuild

					ebuild $(ls ${catalog}/*.ebuild | head -n1) manifest

					git add ${catalog}
					gitMSG="${gitMSG}${pkgname}-${version}, "
				fi
			done

			;;
	esac
}

function updateEbuild() {
	cd ${OVERLAYDIR}
	# ignore packages command out by #
	for pkg in `cat $PKGLIST | grep -v '#'`
	do
		verinfo $pkg
		repoVer=$(curl --silent ${HOME}/tags | grep -A 1 -E  "a\ href.*/tag/"  | grep -v "/tag/" | sed s/[[:space:]]//g | head -n1)
		verlt ${curVer} ${repoVer} && verBump
		# forward ebuild log to STDERR when build error
		[[ $? == 3 ]] && cat /var/tmp/portage/${catalog}-${repoVer}/temp/build.log >> /dev/stderr 
	done

	[[ ${OVERLAYDIR} == "/var/lib/layman/deepin" ]] && qtheaders update

	[[ -n ${gitMSG} ]] && git commit -m "Version bump: ${gitMSG}"
}

function cleanUpOld() {
	cd ${OVERLAYDIR}
	for pkg in `cat $PKGLIST | grep -v '#'`
	do
		verinfo ${pkg}
		if [[ ${countVer} > 2 ]] && [[ ${oldVer} != ${curVer} ]]; then 
			rm ${catalog}/${oldVerEbuild}
			ebuild ${catalog}/${curVerEbuild} manifest
			git add ${catalog}
			gitMSG="${gitMSG}${pkgname}-${oldVer}, "
		fi
	done

	[[ ${OVERLAYDIR} == "/var/lib/layman/deepin" ]] && qtheaders clean

	[[ -n ${gitMSG} ]] && git commit -m "Remove old packages: ${gitMSG}"
}

case "$1" in
	update)
		updateEbuild
		;;
	clean)
		cleanUpOld
		;;
	*)
		echo "ERROR: Invalid operation." >> /dev/stderr
		echo "" >> /dev/stderr
		echo "Usage: overlay_dev.sh <command>" >> /dev/stderr
		echo "where <command> is one of: update, clean" >> /dev/stderr
		;;
esac

# TODO
# 1 send mail when error 
