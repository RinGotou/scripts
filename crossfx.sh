# CrossFX - simple GNU Cross-toolchain maker for code-debugging purpose.
# Usage: crossfx.sh [option]
# Available options:
#   (no argument): execute full cross-toolchain building job.
#   clean-build: Remove current installed binaries.
#   minimal-only: Build binutils and bare-bone GCC only.

# Refs:
# 1. https://blog.jgosmann.de/posts/2021/02/07/a-guide-to-crosscompiling-applications/#dependencies-for-building-gcc
# 2. https://www6.software.ibm.com/developerworks/education/l-cross/l-cross-ltr.pdf

set -e # stop immediately when error occurred.

ulimit -n 1024 # for macOS environment(?)

# Config area. for most cases, you only need to modify these things unless error appears.
export SRC=$PWD/src
export PREFIX=$PWD/install
export ARCH=x86_64
export LINUX_ARCH=x86
export TARGET=x86_64-linux-gnu
export JOBS=4
export ORIGIN_PATH=$PATH
# TODO: Extra config like CFLAGS\CXXFLAGS.
# Config area end.

# Main building operations.
function BuildBinutils {
  echo BuildBinUtils >> build-stage
  mkdir -p stuff/binutils
  pushd stuff/binutils
    $SRC/binutils-gdb/configure               \
      --prefix=$PREFIX                        \
      --with-sysroot=$PREFIX/$TARGET/sys-root \
      --target=$TARGET                        \
      --with-arch=$ARCH                       \
      --disable-nls                           \
      --disable-multilib
  
  make -j$JOBS
  make install
  popd
}

function BuildLinuxHeaders {
  echo BuildLinuxHeaders >> build-stage
  pushd $SRC/linux
  make ARCH=$LINUX_ARCH INSTALL_HDR_PATH=$PREFIX/$TARGET/sys-root/usr headers_install
  popd
}

function BuildMinimalGCC {
  echo BuildMinimalGCC >> build-stage
  mkdir -p stuff/minimal-gcc
  pushd stuff/minimal-gcc
  $SRC/gcc/configure                        \
    --disable-bootstrap                     \
    --prefix=$PREFIX                        \
    --target=$TARGET                        \
    --disable-threads                       \
    --disable-shared                        \
    --without-headers                       \
    --enable-languages=c,c++                \
    --disable-libgomp --disable-libmudflap  \
    --disable-libmpx --disable-libssp       \
    --disable-libvtv                        \
    --disable-libquadmath                   \
    --disable-libquadmath-support           \
    --disable-libstdcxx-verbose             \
    --disable-libstdcxx                     \
    --disable-libatomic                     \
    --disable-multilib 

  make -j$JOBS
  make install
  popd
}

function BuildGlibc {
  echo BuildGlibc >> build-stage
  mkdir -p stuff/glibc
  pushd stuff/glibc
  export PATH=$PREFIX/bin:$PATH
  
  # Dirty way to avoid using system gcc/g++
  ln -s $PREFIX/bin/$TARGET-gcc $PREFIX/bin/gcc
  ln -s $PREFIX/bin/$TARGET-g++ $PREFIX/bin/g++

  libc_cv_forced_unwind=yes                             \
  $SRC/glibc/configure                                  \
    --prefix=/usr                                       \
    --build=$MACHTYPE                                   \
    --host=$TARGET                                      \
    --target=$TARGET                                    \
    --with-arch=$ARCH                                   \
    --with-headers=$PREFIX/$TARGET/sys-root/usr/include \
    --without-cvs --disable-profile --without-gd        \
    --without-selinux                                   \
    --disable-multilib 

  make install-bootstrap-headers=yes      \
    install_root=$PREFIX/$TARGET/sys-root \
    install-headers

  make -j$JOBS csu/subdir_lib
  mkdir $PREFIX/$TARGET/sys-root/usr/lib
  install csu/crt1.o csu/crti.o csu/crtn.o $PREFIX/$TARGET/sys-root/usr/lib

  $PREFIX/bin/$TARGET-gcc                       \
    -nostdlib                                   \
    -nostartfiles                               \
    -shared                                     \
    -x c /dev/null                              \
    -o $PREFIX/$TARGET/sys-root/usr/lib/libc.so
  
  touch $PREFIX/$TARGET/sys-root/usr/include/gnu/stubs.h

  pushd ../minimal-gcc
  make -j$JOBS all-target-libgcc
  make install-target-libgcc
  popd

  make -j$JOBS
  make install_root=$PREFIX/$TARGET/sys-root install
  popd
  
  export PATH=$ORIGIN_PATH
  rm $PREFIX/bin/gcc
  rm $PREFIX/bin/g++
}

function BuildFullFatGCC {
  echo BuildFullFatGCC >> build-stage
  mkdir -p stuff/gcc
  pushd stuff/gcc
  $SRC/gcc/configure                        \
    --disable-bootstrap                     \
    --prefix=$PREFIX                        \
    --with-sysroot=$PREFIX/$TARGET/sys-root \
    --target=$TARGET                        \
    --disable-multilib 

  make -j$JOBS
  make install
  popd
}

if [ "$1" == "clean-build" ]; then
  echo 'delete old stuff...'
  rm -rf stuff
fi

rm build-stage || true

if [ "$1" == "start-from-glibc" ]; then
  # For script maintainance. You should never use this option.
  BuildGlibc
  BuildFullFatGCC
elif [ "$1" == "minimal-only" ]; then
  rm -rf install
  BuildBinutils
  BuildLinuxHeaders
  BuildMinimalGCC
else
  rm -rf install
  BuildBinutils
  BuildLinuxHeaders
  BuildMinimalGCC
  BuildGlibc
  BuildFullFatGCC
fi


echo End Time: $(date)
