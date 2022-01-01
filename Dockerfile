# syntax=docker/dockerfile:1

#
# Stage 1:  Compile latest version of BAGEL
#

# base image
FROM ubuntu:latest AS build_bagel

# set environment variables
ENV TZ=Europe/Berlin \
    DEBIAN_FRONTEND=noninteractive \
    TERM=linux

# install dependencies for compiling BAGEL 
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && apt-get update && apt-get install --yes \
      autoconf \
      build-essential \
      git \
      libtool \
      python3 \
      wget

# install Intel libraries
RUN wget https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB && \
    apt-key add GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB && \
    rm GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB && \
    sh -c 'echo deb https://apt.repos.intel.com/mpi all main > /etc/apt/sources.list.d/intel-mpi.list' && \
    sh -c 'echo deb https://apt.repos.intel.com/mkl all main > /etc/apt/sources.list.d/intel-mkl.list' && \
    apt-get update && \
    echo -e 'yes\n' | apt-get install --yes \
      intel-mpi-2019.9-912 \
      intel-mkl-2020.0-088

# download and compile boost library
RUN wget https://sourceforge.net/projects/boost/files/boost/1.66.0/boost_1_66_0.tar.gz/download \
   && mv download boost_1_66_0.tar.gz \
   && tar -xvf boost_1_66_0.tar.gz

WORKDIR boost_1_66_0
RUN ./bootstrap.sh && ./b2 install

WORKDIR ../

ENV BOOST_ROOT=/boost_1_66_0/boost \
    LD_LIBRARY_PATH=/boost_1_66_0/stage/lib:$LD_LIBRARY_PATH

# download latest version of BAGEL
RUN git clone https://github.com/qsimulate-open/bagel.git  bagel_src && \
    mkdir -p bagel_bin/obj

COPY compile_bagel.sh bagel_bin/obj/

WORKDIR bagel_bin/obj
RUN ./compile_bagel.sh

# copy all libraries on which BAGEL depends into folder dependencies/
ENV COMPILERVARS_ARCHITECTURE=intel64
ENV COMPILERVARS_PLATFORM=linux
ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

RUN mkdir -p dependencies && \
    . /opt/intel/bin/compilervars.sh && \
    . /opt/intel/mkl/bin/mklvars.sh && \
    ldd /bagel_bin/obj/bin/BAGEL | awk '/=>/ { print $3 }' | xargs -I %  \
    cp %                                                                                        dependencies    && \
    cp /opt/intel/compilers_and_libraries/linux/mpi/intel64/libfabric/lib/prov/libsockets-fi.so dependencies   && \
    cp /opt/intel/compilers_and_libraries/linux/mkl/lib/intel64/libmkl_avx2.so                  dependencies 
    
#
# Stage 2: Now we create a minimal image which contains only the base image,
#          the BAGEL exectuable and its dependencies
#

FROM ubuntu:latest AS release

WORKDIR /

# libraries
COPY --from=build_bagel  /bagel_bin/obj/dependencies/*   /usr/local/lib/bagel/
# BAGEL executable
COPY --from=build_bagel  /bagel_bin/obj/bin/BAGEL        /usr/local/bin/
# basis sets
COPY --from=build_bagel  /bagel_bin/obj/share/*          /usr/local/share/bagel/
RUN mkdir -p /bagel_bin/obj && \
    ln -s /usr/local/share/bagel  /bagel_bin/obj/share
# add search path for libraries
RUN sh -c 'echo "# libraries for BAGEL\n/usr/local/lib/bagel\n" > /etc/ld.so.conf.d/bagel.conf' && \
    ldconfig
ENV LD_LIBRARY_PATH=/usr/local/lib/bagel

# tests
COPY tests/* /tests/

