#!/bin/sh

# get the name of the user who called 'sudo'
USERNAME=`logname 2>/dev/null || echo $SUDO_USER`

error_exit()
{
    echo "Error: $1"
    exit 1
}


installReqs(){
    
    if [[ -f ".env" ]]; then
        return
    fi

    cd ~/Downloads
    sudo wget -O /etc/yum.repos.d/daos-packages.repo https://packages.daos.io/v2.0.3/EL8/packages/x86_64/daos_packages.repo
    sudo rpm --import https://packages.daos.io/RPM-GPG-KEY
    sudo yum install epel-release daos-server daos-client daos-devel -y
    touch '.env'

}

downloadCephCode(){
    cd $HOME
    if [ -f "ceph" ]; then
        return
    fi
    git clone --recurse https://github.com/zalsader/ceph --branch add-daos-rgw-sal
}

installCephReqs(){

    sudo dnf -y install https://download.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
    sudo dnf --enablerepo=powertools install gperf nasm ninja-build -y
    sudo dnf install xmlsec1-openssl-devel snappy-devel -y
    sudo dnf --enablerepo=powertools install xmlsec1-openssl-devel python3-sphinx -y
    sudo dnf --enablerepo=powertools install Cunit-
    sudo dnf --enablerepo=powertools install lua-devel libbabeltrace-devel librabbitmq-devel librdkafka-devel lttng-ust-devel -y
    sudo dnf --enablerepo=powertools install CUnit-devel -y
    sudo dnf --enablerepo=powertools install python3-Cython -y
    sudo dnf --enablerepo=powertools install snappy-devel -y
    sudo dnf --enablerepo=powertools install ccache -y
}

buildCephCode(){
    installCephReqs
    ./install-deps.sh
    `export CEPH_PATH=/home/$USERNAME/ceph`
    cd "/home/$USERNAME/ceph"

    if [ ! -f "build" ]; then
        cmake3 -GNinja -DPC_DAOS_INCLUDEDIR=/usr/include/daos-DPC_DAOS_LIBDIR=$/usr/lib64/daos -DWITH_PYTHON3=3.6 -DWITH_RADOSGW_DAOS=YES -DWITH_CCACHE=ON -DENABLE_GIT_VERSION=OFF -B build
        cd build
        ninja  -j11 vstart
    fi
    
}

startServerAgent(){
    sudo systemctl daemon-reload
    sudo systemctl start daos_server
    sudo systemctl start daos_agent
}

writeConfigFiles(){
    sudo echo 'vm.nr_hugepages = 512' >> /etc/sysctl.conf
    sudo sed -i 's/User=daos_server/User=root/' /usr/lib/systemd/system/daos_server.service
    sudo sed -i 's/Group=daos_server/Group=root/' /usr/lib/systemd/system/daos_server.service
}

copyConfigFiles(){
    echo 'Copying config daos .yml config files'
    if [ -f /etc/daos/daos_agent.yml ]; then
        sudo cp /etc/daos/daos_agent.yml /etc/daos/daos_agent.yml.bak
    fi 
    
    if [ -f /etc/daos/daos_server.yml ]; then
        sudo cp /etc/daos/daos_server.yml /etc/daos/daos_server.yml.bak
    fi 
    
    if [ -f /etc/daos/doas_control.yml ]; then
        sudo cp /etc/daos/daos_control.yml /etc/daos/daos_control.yml.bak
    fi

    sudo cp config/daos_agent.yml /etc/daos/daos_agent.yml
    sudo cp config/daos_control.yml /etc/daos/daos_control.yml
    sudo cp config/daos_server.yml /etc/daos/daos_server.yml
    
}

generateCertificates(){
    cd /tmp
    cp /usr/lib64/daos/certgen/gen_certificates.sh .
    sudo ./gen_certificates.sh
    sudo mkdir /etc/daos/certs
    sudo cp /tmp/daosCA/certs/* /etc/daos/certs/.
    sudo cp /tmp/daosCA/certs/agent.crt /etc/daos/certs/clients/agent.crt
    sudo rm -rf /tmp/daosCA
}

cephConfiguration(){
    sudo sed -i 's/\t\tnum osd = 3/\t\tnum osd = 0/' ceph.conf
}

#installReqs
#downloadCephCode
#buildCephCode
#writeConfigFiles
#copyConfigFiles
startServerAgent