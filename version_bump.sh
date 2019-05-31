#!/bin/sh

PKGLIST=${PKGLIST:-$PWD/deepin-pkg-list}
OVERLAYDIR=${OVERLAYDIR:-/var/lib/layman/deepin}

function verinfo() {

	# catalog="dde-base/dde-dock"
	catalog="$1"
	pkgname=${catalog##*/}

	curVer=$(ls ${catalog}/*.ebuild | xargs -l basename | sed -E 's/.*-([0-9]+[\.0-9+]*).*\.ebuild/\1/' | sort -r -V | head -n1)

	# github homepage
	HOME=$(grep HOMEPAGE ${catalog}/${pkgname}-${curVer}*.ebuild  | sed -E 's/.*"(.*)".*/\1/' | head -n1)

	repoVer=$(curl --silent ${HOME}/tags | grep -A 1 -E  "a\ href.*/tag/"  | grep -v "/tag/" | sed s/[[:space:]]//g | head -n1)

}

# compare current version and remote latest version
# verlte: reture true when par $1 <= $2
function verlte() {
	printf '%s\n%s' "$1" "$2" | sort -C -V
}

# verlt: return true when par $1 < $2
function verlt() { 
	! verlte "$2" "$1" 
}

function verBump() {
	cp ${catalog}/${pkgname}-${curVer}*.ebuild ${catalog}/${pkgname}-${repoVer}.ebuild

	ebuild ${catalog}/${pkgname}-${repoVer}.ebuild manifest || return

	ebuild ${catalog}/${pkgname}-${repoVer}.ebuild install || return

	ebuild ${catalog}/${pkgname}-${repoVer}.ebuild clean

	git add ${catalog}

	git commit -m "Version bump: ${pkgname}-${repoVer}"
}

# Special for dev-qt/qtxcb-private-headers
function qtheaders() {

	catalog="dev-qt/qtxcb-private-headers"
	pkgname=${catalog##*/}

	curVer=$(ls ${catalog}/*.ebuild | xargs -l basename | sed -E 's/.*-([0-9]+[\.0-9+]*).*\.ebuild/\1/' | sort -r -V | head -n1)

	repoVer=$(ls /usr/portage/dev-qt/qtcore/qtcore*.ebuild | xargs -l basename | sed -E 's/.*-([0-9]+[\.0-9+]*).*\.ebuild/\1/' | sort -r -V | head -n1)
	
	verlt ${curVer} ${repoVer} && verBump

}

cd ${OVERLAYDIR}
for pkg in `cat $PKGLIST`
do
	verinfo $pkg
	verlt ${curVer} ${repoVer} && verBump
done

qtheaders

# TODO
# 1 send mail when error 
