#!/bin/bash

PKGLIST=${PKGLIST:-$(cd $(dirname $0); pwd -P)/deepin-pkg-list}
OVERLAYDIR=${OVERLAYDIR:-/var/lib/layman/deepin}

gitMSG=""

function verinfo() {
	# catalog="dde-base/dde-dock"
	catalog="$1"
	pkgname=${catalog##*/}

	curVerEbuild=$(ls ${catalog}/*.ebuild | xargs -l basename | sort -r -V | head -n1)
	curVer=$(echo ${curVerEbuild} | sed -E 's/.*-([0-9]+[\.0-9+]*).*\.ebuild/\1/') 

	countVer=$(ls ${catalog}/*.ebuild | wc -l)

	oldVerEbuild=$(ls ${catalog}/*.ebuild | xargs -l basename | sort -V | head -n1)
	oldVer=$(echo ${oldVerEbuild} | sed -E 's/.*-([0-9]+[\.0-9+]*).*\.ebuild/\1/') 
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
[[ -n ${gitMSG} ]] && git commit -m "Remove old packages: ${gitMSG}"
