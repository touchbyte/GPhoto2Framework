#!/bin/sh
# "make installcheck" testcase:
# Compares camera list printed by by print-camera-list and parsed by
#test-ddb with the camera list from gp_abilities_list_load().
# Fails if differences are found.

set -ex

debug=:
#debug=false

PACKAGE_TARNAME="${PACKAGE_TARNAME-"libgphoto2"}"
prefix="${prefix-"/opt/iphonesimulator-12.0/x86_64"}"
exec_prefix="${exec_prefix-"${prefix}"}"
libdir="${libdir-"${exec_prefix}/lib"}"
libexecdir="${libexecdir-"${exec_prefix}/libexec"}"
camlibdir="${camlibdir-"${libdir}/libgphoto2/2.5.19.1"}"
utilsdir="${utilsdir-"${libdir}/${PACKAGE_TARNAME}"}"
CAMLIBS="${DESTDIR}${camlibdir}"
export CAMLIBS
LD_LIBRARY_PATH="${DESTDIR}/${libdir}${LD_LIBRARY_PATH+:${LD_LIBRARY_PATH}}"
export LD_LIBRARY_PATH

if "$debug"; then
    echo "====================="
    pwd
    echo "camlibdir=$camlibdir"
    echo "libdir=$libdir"
    echo "utilsdir=$utilsdir"
    echo "DESTDIR=$DESTDIR"
    echo "CAMLIBS=$CAMLIBS"
    echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
    echo "#####################"
fi

${DESTDIR}${utilsdir}/print-camera-list gp2ddb > gp2ddb.txt

./test-ddb --compare < gp2ddb.txt
