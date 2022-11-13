#!/bin/bash
# Helper script for building SPEC2006 on modern operating system.
# Usage: ./spec2006-buildtool-injection.sh /path/to/the/tools/src

set -xe
pushd $1

wget -O src.guess 'https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD'

find ./ -name config.guess | while read line; do
  cp ./src.guess $line
done
rm src.guess

glob_c_loc=$(find ./ -name glob.c | grep make)
sed 's/__alloca/alloca/g' $glob_c_loc > glob.c.tmp
mv glob.c.tmp $glob_c_loc

tar_getline_h=$(find ./ -name getline.h | grep 'tar')
md5sum_getline_h=$(find ./ -name getline.h | grep 'md5sum')
cp $md5sum_getline_h $md5sum_getline_h.original
cp $tar_getline_h $md5sum_getline_h

mv buildtools buildtools_old
echo 'export PERLFLAGS="-A libs=-lm -A libs=-ldl"' > buildtools
echo 'export PATH=$PWD/symlinks:$PATH' >> buildtools
cat buildtools_old >> buildtools
chmod +x buildtools

mkdir symlinks
ln -s /bin/bash $(pwd)/symlinks/sh

sysv_xs_loc=$(find ./ -name 'SysV.xs')
cp $sysv_xs_loc $sysv_xs_loc.original
mod_dest_linenum=$(grep -n 'page.h' $sysv_xs_loc | cut -d ':' -f 1)
sed "${mod_dest_linenum}s/.*/#define PAGE_SIZE 4096/" $sysv_xs_loc.original > $sysv_xs_loc

popd # $1
