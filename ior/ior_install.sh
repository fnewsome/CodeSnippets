#!/bin/bash

# Description: This is an install script for the installing IOR
# which is a parallel IO benchmark that can be used to test the performance
# of parallel storage systems.  The script below will install IOR 
# on the Rocky Linux Operating System.  The IOR project can be found at
# https://github.com/hpc/ior

# directory to install software (mpich, ior)
HOMEBASE=/usr/local/share/software
HOMEPATH=/home/daperk
MPICH_VERSION=4.0.2
NUM_THREADS=10

error_exit()
{
    echo -e "\e[1;31mError: $1"
    exit 1
}

pathappend() {
  for ARG in "$@"
  do
    if [ -d "$ARG" ] && [[ ":$PATH:" != *":$ARG:"* ]]; then
        PATH="${PATH:+"$PATH:"}$ARG"
    fi
  done
}

pathadd() {
    if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
        PATH="${PATH:+"$PATH:"}$1"
    fi
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

    sudo yum install openmpi.x86_64 -y

    # create empty file to indicate updates have been installed
    touch '.env'

}

cleanUp() {
    echo 'Performing cleanup of files/directories..'
    `sudo rm -rf ior` || error_exit "Could not delete the directory: 'ior'"
    `sudo rm -f mpich-${MPICH_VERSION}.tar.gz` || error_exit "Could not delete the file: mpich-${MPICH_VERSION}.tar.gz"
    `sudo rm -rf mpich-${MPICH_VERSION}` || error_exit "Could not delete the directory: mpich-${MPICH_VERSION}"
}

downloadIor(){
    echo 'Download ior source code..'
    # Retrieve the ior project from Github
    git clone https://github.com/hpc/ior.git > /dev/null 2>&1 || error_exit "Could not download 'ior' from https://github.com/hpc/ior.git"
}

installIor(){
    downloadIor

    echo -e "\e[1;32mBegin installing ior..\e[1;37m"

    # get the name of the user who called 'sudo'
    USERNAME=`logname 2>/dev/null || echo $SUDO_USER`

    echo -e "Current user:\e[1;33m$USERNAME\e[1;37m"

    MODULE_FILE="/etc/profile.d/modules.sh"
    if [[ -f "$MODULE_FILE" ]]; then
        source /etc/profile.d/modules.sh

        # load mpi module
        module load mpi
        echo -e "\e[1;33mLoaded mpi module successfully\e[1;37m"
    else
        error_exit "Could not load mpi module successfully."
    fi
    

    # Navigate to the folder created from the git clone command
    cd ior  || error_exit "ior folder does not exist."

    echo -e "\e[1;32mPreparing to run ior boostrap..\e[1;37m"
    
    # execute the ior bootstrap
    ./bootstrap > /dev/null 2>&1 || error_exit "ior bootstrap failed to run."

    echo -e "\e[1;32mCompleted ior bootstrap..\e[1;37m"
    echo -e "\e[1;32mPreparing to run ior build configuration..\e[1;37m"
    
    # run the build configuration
    ./configure --prefix=$HOMEPATH/software/ior > /dev/null 2>&1 || error_exit "Could not configure ior successfully for build."   

    echo -e "\e[1;32mCompleted ior build configuration..\e[1;37m"
    echo -e "\e[1;32mPreparing to build ior..\e[1;37m"
    
    # refresh the bash shell to incorporate PATH changes
    `. ~/.bash_profile`

    # run make and make install
    make -j${NUM_THREADS} > /dev/null 2>&1 || error_exit "Failed to build ior due to an error"
    
    echo -e "\e[1;32mCompleted ior build..\e[1;37m"

    make install > /dev/null 2>&1 || error_exit "Failed to install ior due to an error"

    echo "export PATH=$HOMEPATH/software/ior/bin:\$PATH" >> "/home/$USERNAME/.bash_profile"

    source "/home/$USERNAME/.bash_profile" || error_exit "Could not reload bash profile."

    echo -e "\e[1;32mCompleted ior installation.\e[1;37m"

    cd ../

}

downloadMpich(){

    MPICH_FILE=mpich-${MPICH_VERSION}.tar.gz
    if [[ -f "${MPICH_FILE}" ]]; then
        echo -e '\e[1;33mMPICH file already downloaded\e[1;37m'
        return
    fi

    wget https://www.mpich.org/static/downloads/${MPICH_VERSION}/mpich-${MPICH_VERSION}.tar.gz > /dev/null 2>&1
    tar xzf mpich-${MPICH_VERSION}.tar.gz > /dev/null 2>&1
}

installMpich(){

    downloadMpich

    if [[ -f ".mpich" ]]; then
        return
    fi    
    
    touch ".mpich"
    MPICH_FOLDER=`echo mpich-${MPICH_VERSION}`
    cd "${MPICH_FOLDER}"
    ./configure --prefix=$HOMEPATH/MPI/mpich-$MPICH_VERSION > /dev/null
    sudo make -j$NUM_THREADS > /dev/null || error_exit "Failed to build mpich-$MPICH_VERSION"
    
    echo "export PATH=$HOMEPATH/MPI/mpich-$MPICH_VERSION/bin:\$PATH" >> "/home/$USERNAME/.bash_profile"
    echo "export LD_LIBRARY_PATH=$HOMEPATH/MPI/mpich-$MPICH_VERSION/lib:$LD_LIBRARY_PATH"
    `. ~/.bash_profile` || error_exit "Could not reload bash profile."
    
    sudo make install > /dev/null || error_exit "Failed to install mpich-$MPICH_VERSION"   
    
    cd ../
    
}

setupEnvironment
installMpich
installIor
cleanUp
