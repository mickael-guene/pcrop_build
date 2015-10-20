#!/bin/bash -ex

#get script location
SCRIPTDIR=`dirname $0`
SCRIPTDIR=`(cd $SCRIPTDIR ; pwd)`
#get working directory
TOP=`pwd`
isDelivery=`echo $1 | grep delivery` || true

# define version
cd ${TOP}/.repo/manifests
VERSION=`git describe --always --dirty --tags --long --abbrev=8 2>/dev/null`
cd ${TOP}
if [ ! "$isDelivery" ] ; then
    VERSION=`date +%Y%m%d-%H%M%S`-${VERSION}
fi

# delete previous versions
rm -f ${TOP}/out/runtime-*

#######################################################################################################
# not really a build but tar scratch test directory
cd ${TOP}
tar -C scratch/test --atime-preserve --exclude='.git' -czf out/runtime-${VERSION}.tgz .

