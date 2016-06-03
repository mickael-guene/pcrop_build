#!/bin/sh -x

#get script location
SCRIPTDIR=`dirname $0`
SCRIPTDIR=`(cd $SCRIPTDIR ; pwd)`
#get working directory
TOP=`pwd`

#temporary directory
WDIR=`mktemp -d` && trap "rm -Rf $WDIR" EXIT
#WDIR=`mktemp -d`

#untar toolset and runtime
cd ${WDIR}
tar xf ${TOP}/out/toolset-*
tar xf ${TOP}/out/runtime-*

#generate test.c
cat << EOF > test.c
#include <stdio.h>

int main(int argc, char **argv)
{
    printf("Hello from arm pcrop\n");

    return 0;
}
EOF

#build it
./bin/arm-none-eabi-gcc -mexecute-only --specs=rdimon.specs -Wl,--script=ld_scripts/umeq.ld test.c -o test

#run it
./bin/umeq-arm ./test

