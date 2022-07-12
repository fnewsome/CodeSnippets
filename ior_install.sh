#!/bin/bash

# Description: This is an install script for the installing IOR
# which is a parallel IO benchmark that can be used to test the performance
# of parallel storage systems.  The script below will install IOR 
# on the Rocky Linux Operating System.  The IOR project can be found at
# https://github.com/hpc/ior

# directory to install software (mpich, ior)
HOMEBASE=/usr/local/share/software
MPICH_VERSION=4.0.2
NUM_THREADS=3

error_exit()
{
    echo "Error: $1"
    exit 1
}

setupEnvironment() {
    # skip updates if environment empty file exists
    if [[ -f ".env" ]]; then
        return
    fi
    # Install Development Tools
    sudo dnf groupinstall -y "Development Tools"
    # Install Development tools, packages, & Kernel Headers
    #
    sudo dnf install -y gcc gcc-c++ perl kernel-headers make

    # Install Kernel Headers
    sudo dnf install -y "kernel-devel-uname-r == $(uname -r)"

    # Install openmpi development packages
    sudo dnf install -y openmpi-devel.x86_64

    # create empty file to indicate updates have been installed
    touch '.env'

}

cleanUp() {
    `sudo rm -rf ior` || error_exit "Could not delete the directory: 'ior'"
    `sudo rm -f mpich-${MPICH_VERSION}.tar.gz` || error_exit "Could not delete the file: mpich-${MPICH_VERSION}.tar.gz"
    `sudo rm -rf mpich-${MPICH_VERSION}` || error_exit "Could not delete the directory: mpich-${MPICH_VERSION}"
}

downloadIor(){
    # Retrieve the ior project from Github
    git clone https://github.com/hpc/ior.git || error_exit "Could not download 'ior' from https://github.com/hpc/ior.git"
}

installIor(){
    # get the name of the user who called 'sudo'
    USERNAME=`logname 2>/dev/null || echo $SUDO_USER`

    PATH_FOUND=`cat /home/$USERNAME/.bash_profile | grep -E 'mpicc|mpich|openmpi|ior'`
    len=${#PATH_FOUND}

    # add mpicc, mpi libraries, mpich to PATH
    if [[ len -eq 0 ]]; then
        `echo PATH=$PATH:/usr/lib/openmpi/bin/mpicc:/usr/lib64/openmpi/lib/:/usr/lib/openmpi/bin:$HOMEBASE/mpich_${MPICH_VERSION}/bin:$HOMEBASE/ior/bin >> "/home/$USERNAME/.bash_profile"`
        echo 'Added mpicc, openmpi, mpich to PATH'
        `source /home/$USERNAME/.bash_profile` || error_exit "Could not reload bash profile."
        echo 'Reloaded bash profile'
    fi

    MODULE_FILE="/etc/profile.d/modules.sh"
    if [[ -f "$MODULE_FILE" ]]; then
        source /etc/profile.d/modules.sh

        # load mpi module
        module load mpi
    else
        error_exit "Could not load mpi module successfully."
    fi
    

    # Navigate to the folder created from the git clone command
    cd ior  || error_exit "ior folder does not exist."

    # execute the ior bootstrap
    ./bootstrap  || error_exit "ior bootstrap failed to run."

    # run the build configuration
    ./configure --prefix=$HOMEBASE/ior || error_exit "Could not configure ior successfully for build."   

    # run make and make install
    make -j${NUM_THREADS}
    make install

    
    source "/home/$USERNAME/.bash_profile" || error_exit "Could not reload bash profile."
    echo "ior executable has been installed in the following folder: ${HOMEBASE}/ior/bin"
    echo 'ior install complete'

}

downloadMpich(){
    `wget https://www.mpich.org/static/downloads/${MPICH_VERSION}/mpich-${MPICH_VERSION}.tar.gz`
}

installMpich(){
    downloadMpich
    `tar xzf mpich-${MPICH_VERSION}.tar.gz`
    MPICH_FOLDER=`echo mpich-${MPICH_VERSION}`
    cd "${MPICH_FOLDER}"
    ./configure --prefix=$HOMEBASE/mpich-$MPICH_VERSION
    make -j$NUM_THREADS
    make install
}

cleanUp
setupEnvironment
installMpich
downloadIor
installIor
cleanUp