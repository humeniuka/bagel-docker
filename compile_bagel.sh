#!/bin/bash

# set paths for Intel libraries
source /opt/intel/bin/compilervars.sh intel64
source /opt/intel/mkl/bin/mklvars.sh  intel64

# out-of-tree build of BAGEL
export BOOST_ROOT=/boost_1_66_0/boost
export LD_LIBRARY_PATH=/boost_1_66_0/lib:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH

# root of source code tree
src_tree=../../bagel_src/

cd $src_tree
libtoolize
aclocal
autoconf
autoheader
automake -a
cd -

$src_tree/configure --enable-mkl \
                    --with-mpi=intel CSSFLAGS="-DNDEBUG -O3 -maxv" \
                    CXXFLAGS=-DCOMPILE_J_ORB \
                    --prefix=$(pwd)


make -j1
make install
