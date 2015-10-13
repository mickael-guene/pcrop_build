#!/bin/bash -ex

#get script location
SCRIPTDIR=`dirname $0`
SCRIPTDIR=`(cd $SCRIPTDIR ; pwd)`
#get working directory
TOP=`pwd`

# define version
cd ${TOP}/.repo/manifests
VERSION=`git describe --always --dirty --tags --long --abbrev=8 2>/dev/null`
cd ${TOP}
if [ ! "$isDelivery" ] ; then
    VERSION=`date +%Y%m%d-%H%M%S`-${VERSION}
fi
VERSION_MSG="$VERSION build on "`uname -n`" by "`whoami`

# define target name
TARGET="arm-none-eabi"

# default value for JOBNB
if [ ! "$JOBNB" ] ; then
    JOBNB=1
fi

#create build and install dir
rm -Rf ${TOP}/build
rm -Rf ${TOP}/install
rm -Rf ${TOP}/out

mkdir -p ${TOP}/build/gmp
mkdir -p ${TOP}/build/mpfr
mkdir -p ${TOP}/build/mpc
mkdir -p ${TOP}/build/binutils
mkdir -p ${TOP}/build/gcc1
mkdir -p ${TOP}/build/newlib
mkdir -p ${TOP}/build/gcc2
mkdir ${TOP}/install
mkdir ${TOP}/install/sysroot
mkdir ${TOP}/out

#compilation options
if [ ! "$DEBUG" ] ; then
    CFLAGS_TOOLSET='-O2'
    CFLAGS_TARGET='-Os -ffunction-sections -fdata-sections'
else
    CFLAGS_TOOLSET='-O0 -g'
    CFLAGS_TARGET='-O0 -g'
fi

#######################################################################################################
##binutils
cd ${TOP}/build/binutils
CFLAGS=$CFLAGS_TOOLSET ${TOP}/scratch/binutils/configure    --target=${TARGET} \
                                                            --prefix=${TOP}/install \
                                                            --enable-poison-system-directories \
                                                            --disable-nls \
                                                            --with-sysroot=${TOP}/install/sysroot \
                                                            --with-pkgversion="${VERSION_MSG}" \
                                                            --without-bugurl \
                                                            --disable-werror
make all -j${JOBNB}
make install

#######################################################################################################
#gmp
cd ${TOP}/build/gmp
CFLAGS=$CFLAGS_TOOLSET ${TOP}/scratch/gmp/configure         --prefix=${TOP}/install_host \
                                                            --enable-cxx \
                                                            --disable-shared
make all -j${JOBNB}
make install

#######################################################################################################
#mpfr
cd ${TOP}/build/mpfr
CFLAGS=$CFLAGS_TOOLSET ${TOP}/scratch/mpfr/configure        --prefix=${TOP}/install_host \
                                                            --with-gmp=${TOP}/install_host \
                                                            --disable-shared
make all -j${JOBNB}
make install

#######################################################################################################
#mpc
cd ${TOP}/build/mpc
CFLAGS=$CFLAGS_TOOLSET ${TOP}/scratch/mpc/configure         --prefix=${TOP}/install_host \
                                                            --with-gmp=${TOP}/install_host \
                                                            --with-mpfr=${TOP}/install_host \
                                                            --disable-shared
make all -j${JOBNB}
make install

#######################################################################################################
#gcc1
cd ${TOP}/build/gcc1
CFLAGS=$CFLAGS_TOOLSET CFLAGS_FOR_TARGET=$CFLAGS_TARGET CXXFLAGS_FOR_TARGET=$CFLAGS_TARGET ${TOP}/scratch/gcc/configure \
                                                            --prefix=${TOP}/install \
                                                            --target=${TARGET} \
                                                            --with-gmp=${TOP}/install_host \
                                                            --with-mpfr=${TOP}/install_host \
                                                            --with-mpc=${TOP}/install_host \
                                                            --without-headers \
                                                            --with-newlib \
                                                            --disable-shared \
                                                            --disable-threads \
                                                            --disable-libssp \
                                                            --disable-libgomp \
                                                            --disable-libmudflap \
                                                            --enable-languages=c \
                                                            --disable-libquadmath \
                                                            --disable-multilib \
                                                            --with-arch=armv6s-m \
                                                            --with-mode=thumb \
                                                            --without-cloog \
                                                            --without-ppl \
                                                            --disable-nls

make all -j${JOBNB}
make install

#######################################################################################################
#newlib
cd ${TOP}/build/newlib
PATH=${TOP}/install/bin:${PATH} CFLAGS="$CFLAGS_TARGET" ${TOP}/scratch/newlib/configure \
                                                            --prefix=${TOP}/install \
                                                            --target=${TARGET} \
                                                            --enable-newlib-io-long-long \
                                                            --enable-newlib-register-fini \
                                                            --disable-newlib-supplied-syscalls \
                                                            --disable-nls

PATH=${TOP}/install/bin:${PATH} make all -j${JOBNB}
PATH=${TOP}/install/bin:${PATH} make install

#######################################################################################################
#gcc2
cd ${TOP}/build/gcc2
#building internal gcc lib require to find include files in sysroot/target/usr/include
#so create a temporary link toward sysroot/target/include
rm -f ${TOP}/install/${TARGET}/usr
ln -s . ${TOP}/install/${TARGET}/usr
CFLAGS=$CFLAGS_TOOLSET CFLAGS_FOR_TARGET=$CFLAGS_TARGET CXXFLAGS_FOR_TARGET=$CFLAGS_TARGET ${TOP}/scratch/gcc/configure \
                                                            --prefix=${TOP}/install \
                                                            --target=${TARGET} \
                                                            --with-gmp=${TOP}/install_host \
                                                            --with-mpfr=${TOP}/install_host \
                                                            --with-mpc=${TOP}/install_host \
                                                            --with-newlib \
                                                            --with-headers=yes \
                                                            --with-sysroot=${TOP}/install/${TARGET} \
                                                            --disable-libgomp \
                                                            --disable-libmudflap \
                                                            --enable-languages=c,c++ \
                                                            --disable-libquadmath \
                                                            --disable-multilib \
                                                            --disable-libstdcxx-pch \
                                                            --disable-threads \
                                                            --with-arch=armv6s-m \
                                                            --with-mode=thumb \
                                                            --without-cloog \
                                                            --without-ppl \
                                                            --disable-nls \
                                                            --with-pkgversion="${VERSION_MSG}" \
                                                            --without-bugurl

make all -j${JOBNB}
make install
#remove tmp link
rm -f ${TOP}/install/${TARGET}/usr

#######################################################################################################
#generate tarball
cd ${TOP}
if [ "$STRIP" ] ; then
    WDIR=`mktemp -d` && trap "rm -Rf $WDIR" EXIT
    tar -C install --atime-preserve -cf - . | tar --atime-preserve -xf - -C $WDIR
    find $WDIR -type f -exec strip -p {} \; > /dev/null 2>&1
    find $WDIR -exec install/bin/${TARGET}-strip -p {} \; > /dev/null 2>&1
    tar -C $WDIR --atime-preserve -czf out/toolset-${VERSION}-armv6s-m.tgz .
else
    tar -C install --atime-preserve -czf out/toolset-${VERSION}-armv6s-m.tgz .
fi

