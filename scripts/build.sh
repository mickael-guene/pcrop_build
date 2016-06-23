#!/bin/bash -ex

#get script location
SCRIPTDIR=`dirname $0`
SCRIPTDIR=`(cd $SCRIPTDIR ; pwd)`
#get working directory
TOP=`pwd`
isDelivery=`echo $1 | grep delivery` || true

# define bug url
BUGURL="https://github.com/mickael-guene/pcrop_manifest/issues"

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
mkdir -p ${TOP}/build/newlib-nano
mkdir -p ${TOP}/build/gcc2
mkdir ${TOP}/install
mkdir ${TOP}/install/sysroot
mkdir ${TOP}/out

#compilation options
if [ ! "$DEBUG" ] ; then
    CFLAGS_TOOLSET='-O2'
    CFLAGS_TARGET='-Os -ffunction-sections'
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
                                                            --with-bugurl="${BUGURL}" \
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
#newlib-nano
cd ${TOP}/build/newlib-nano
PATH=${TOP}/install/bin:${PATH} CFLAGS="$CFLAGS_TARGET" ${TOP}/scratch/newlib/configure \
                                                            --prefix=${TOP}/build/newlib-nano/target-libs \
                                                            --target=${TARGET} \
                                                            --disable-newlib-supplied-syscalls \
                                                            --disable-nls \
                                                            --enable-newlib-reent-small           \
                                                            --disable-newlib-fvwrite-in-streamio  \
                                                            --disable-newlib-fseek-optimization   \
                                                            --disable-newlib-wide-orient          \
                                                            --enable-newlib-nano-malloc           \
                                                            --disable-newlib-unbuf-stream-opt     \
                                                            --enable-lite-exit                    \
                                                            --enable-newlib-global-atexit         \
                                                            --enable-newlib-nano-formatted-io

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
                                                            --disable-libstdcxx-pch \
                                                            --disable-threads \
                                                            --with-arch=armv6s-m \
                                                            --with-mode=thumb \
                                                            --without-cloog \
                                                            --without-ppl \
                                                            --disable-nls \
                                                            --with-pkgversion="${VERSION_MSG}" \
                                                            --with-bugurl="${BUGURL}"

make all -j${JOBNB}
make install
#remove tmp link
rm -f ${TOP}/install/${TARGET}/usr

#######################################################################################################
#copy newlib-nano libraries
cp ${TOP}/build/newlib-nano/target-libs/${TARGET}/lib/libc.a ${TOP}/install/${TARGET}/lib/libc_nano.a
cp ${TOP}/build/newlib-nano/target-libs/${TARGET}/lib/libg.a ${TOP}/install/${TARGET}/lib/libg_nano.a
cp ${TOP}/build/newlib-nano/target-libs/${TARGET}/lib/librdimon.a ${TOP}/install/${TARGET}/lib/librdimon_nano.a
cp ${TOP}/build/newlib-nano/target-libs/${TARGET}/lib/armv7-m/libc.a ${TOP}/install/${TARGET}/lib/armv7-m/libc_nano.a
cp ${TOP}/build/newlib-nano/target-libs/${TARGET}/lib/armv7-m/libg.a ${TOP}/install/${TARGET}/lib/armv7-m/libg_nano.a
cp ${TOP}/build/newlib-nano/target-libs/${TARGET}/lib/armv7-m/librdimon.a ${TOP}/install/${TARGET}/lib/armv7-m/librdimon_nano.a

#FIXME : rebuild these ones with reduce size ???
cp ${TOP}/install/${TARGET}/lib/libstdc++.a ${TOP}/install/${TARGET}/lib/libstdc++_nano.a
cp ${TOP}/install/${TARGET}/lib/libsupc++.a ${TOP}/install/${TARGET}/lib/libsupc++_nano.a
cp ${TOP}/install/${TARGET}/lib/armv7-m/libstdc++.a ${TOP}/install/${TARGET}/lib/armv7-m/libstdc++_nano.a
cp ${TOP}/install/${TARGET}/lib/armv7-m/libsupc++.a ${TOP}/install/${TARGET}/lib/armv7-m/libsupc++_nano.a

#######################################################################################################
#generate tarball
cd ${TOP}
if [ "$STRIP" ] ; then
    WDIR=`mktemp -d` && trap "rm -Rf $WDIR" EXIT
    tar -C install --atime-preserve -cf - . | tar --atime-preserve -xf - -C $WDIR
    find $WDIR -type f -perm /111 -exec strip -p {} \; > /dev/null 2>&1
    #find $WDIR -exec install/bin/${TARGET}-strip -p {} \; > /dev/null 2>&1
    tar -C $WDIR --atime-preserve -czf out/toolset-${VERSION}-${ARCH}.tgz .
else
    tar -C install --atime-preserve -czf out/toolset-${VERSION}-${ARCH}.tgz .
fi

