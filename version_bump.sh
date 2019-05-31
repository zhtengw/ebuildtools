#!/bin/sh

PKGLIST=${PKGLIST:-$PWD/deepin-pkg-list}
OVERLAYDIR=${OVERLAYDIR:-/var/lib/layman/deepin}

verinfo() {

	# catalog="dde-base/dde-dock"
	catalog="$1"
	pkgname=${catalog##*/}

	curVer=$(ls ${catalog}/*.ebuild | xargs -l basename | sed -E 's/.*-([0-9]+[\.0-9+]*).*\.ebuild/\1/' | sort -r -V | head -n1)
	repoVer=$(curl --silent ${HOME}/tags | grep -A 1 -E  "a\ href.*/tag/"  | grep -v "/tag/" | sed s/[[:space:]]//g | head -n1)

	# github homepage
	HOME=$(grep HOMEPAGE ${catalog}/${pkgname}-${curVer}*.ebuild  | sed -E 's/.*"(.*)".*/\1/' | head -n1)
}

# compare current version and remote latest version
# verlte: reture true when par $1 <= $2
verlte() {
	printf '%s\n%s' "$1" "$2" | sort -C -V
}

# verlt: return true when par $1 < $2
verlt() { 
	! verlte "$2" "$1" 
}

verBump() {
	cp ${catalog}/${pkgname}-${curVer}*.ebuild ${catalog}/${pkgname}-${repoVer}.ebuild

	ebuild ${catalog}/${pkgname}-${repoVer}.ebuild manifest || return

	ebuild ${catalog}/${pkgname}-${repoVer}.ebuild install || return

	git add ${catalog}

	git commit -m "Version bump: ${pkgname}-${repoVer}"
}


cd ${OVERLAYDIR}
for pkg in `cat $PKGLIST`
do
	verinfo $pkg
	verlt ${curVer} ${repoVer} && verBump
done

# TODO
# 1 get homepage from ebuild
# 2 make sure homepage urls are github page
# 3 packages list
# 4 send mail when error 
