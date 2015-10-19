#!/bin/sh -ex

#get script location
SCRIPTDIR=`dirname $0`
SCRIPTDIR=`(cd $SCRIPTDIR ; pwd)`
#get working directory
TOP=`pwd`

#select python version
if [ `which python26` ]; then
    PYTHON=`which python26`
else
    PYTHON=`which python`
fi

# define version
cd ${TOP}/.repo/manifests
TAG_NAME=`git describe --tags --always 2>/dev/null`
cd ${TOP}
# push packages
for f in ${TOP}/out/* ; do
    ${PYTHON} ${TOP}/scratch/build/aci/upload_release.py -u mickael-guene -r pcrop_manifest -t $TAG_NAME $f
done

