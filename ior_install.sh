#!/bin/sh

# Description: This is an install script for the installing IOR
# which is a parallel IO benchmark that can be used to test the performance
# of parallel storage systems.  The script below will install IOR 
# on the Rocky Linux Operating System.  The IOR project can be found at
# https://github.com/hpc/ior

HOMEBASE=/home/daperk/software
MPICH_VERSION=4.0.2

setupEnvironment() {
    # Install Development Tools
    dnf groupinstall -y "Development Tools"
    # Install Development tools, packages, & Kernel Headers
    #
    dnf install -y gcc gcc-c++ perl kernel-headers make

    # Install Kernel Headers
    dnf install -y "kernel-devel-uname-r == $(uname -r)"

    # Install openmpi development packages
    dnf install -y openmpi-devel.x86_64

}

cleanUp() {
    `rm -rf ior`
    `rm -f mpich-${MPICH_VERSION}.tar.gz`
    `rm -rf mpich-${MPICH_VERSION}`
}

downloadIor(){
    rm -rf ior

    sleep 2
    # Retrieve the ior project from Github
    git clone https://github.com/hpc/ior.git
}

installIor(){

    PATH_FOUND=`echo $PATH | grep -E 'mpicc|mpich|openmpi'`
    len=${#PATH_FOUND}

    # add mpicc, mpi libraries, mpich to PATH
    if [[ len -eq 0 ]]; then
        export PATH="$PATH:/usr/lib/openmpi/bin/mpicc:/usr/lib64/openmpi/lib/:/usr/lib/openmpi/bin"
        export PATH="$PATH:$HOMEBASE/mpich_${MPICH_VERSION}/bin"
        echo 'Added mpicc, openmpi, mpich to PATH'
    fi

    # load mpi module
    module load mpi

    # Navigate to the folder created from the git clone command
    cd ior

    # execute the ior bootstrap
    ./bootstrap

    # run the build configuration
    ./configure --prefix=$HOMEBASE/ior    

    # run make and make install
    make -j2
    make install

    echo "ior executable has been installed in the following folder: ${HOMEBASE}/ior/bin"
    echo "Copy and paste to add to PATH: export PATH=\"\$PATH:$HOMEBASE/ior/bin\""
    echo 'Completed ior install'

}

downloadMpich(){
    `wget https://www.mpich.org/static/downloads/${MPICH_VERSION}/mpich-${MPICH_VERSION}.tar.gz`
}

installMpich(){
    downloadMpich
    
    `tar xzf mpich-${MPICH_VERSION}.tar.gz`
    MPICH_FOLDER=`echo mpich-${MPICH_VERSION}`
    cd "${MPICH_FOLDER}"
    ./configure --prefix=$HOMEBASE/mpich-${MPICH_VERSION}
    make -j2
    make install
}

cleanUp
setupEnvironment
installMpich
downloadIor
installIor
cleanUp