#!/bin/bash

function install_dependencies {
    sudo apt update && sudo apt full-upgrade -y
    read -p "During installation you will be asked whether to enable real time priority for jackd process. Press enter and enable RT priority."
    sudo apt install -y qjackctl bluez-alsa-utils zita-ajbridge mold zram-tools tuned \
        git libncurses5-dev flex build-essential bison libssl-dev bc make linux-headers-rpi-v8 \
        gperf \
        intltool \
        libavahi-gobject-dev \
        libbluetooth-dev \
        libboost-dev \
        libboost-iostreams-dev \
        libboost-system-dev \
        libboost-thread-dev \
        libeigen3-dev \
        libgtk-3-dev \
        libgtkmm-3.0-dev \
        libjack-jackd2-dev \
        liblilv-dev \
        liblrdf0-dev \
        libsndfile1-dev \
        libfftw3-dev \
        lv2-dev \
        python3 \
        sassc \
        fonts-roboto 
}

function configure_system {
    sudo tuned-adm profile throughput-performance
    sudo systemctl disable NetworkManager-wait-online.service
    sudo raspi-config nonint do_vnc 0
    # remove unnecessary packages
    sudo apt purge cups modemmanager --auto-remove -y
    # fix bluetooth audio quality
    sudo sed -i 's/btc_mode=1/btc_mode=4/g' /usr/lib/firmware/brcm/brcmfmac43455-sdio.txt
}

function configure_dac_adc {
    sudo sed -i 's/dtparam=audio=on/# dtparam=audio=on/g' /boot/firmware/config.txt
    sudo sed -i 's/dtoverlay=vc4-kms-v3d/dtoverlay=vc4-kms-v3d,noaudio/g' /boot/firmware/config.txt
    sudo sed -i '1 i\force_eeprom_read=0' /boot/firmware/config.txt
    sudo sed -i '1 i\dtoverlay=hifiberry-dacplusadcpro' /boot/firmware/config.txt
}

function install_guitarix {
    cd ~/
    git clone https://github.com/brummer10/guitarix.git
    cd guitarix
    git submodule update --init --recursive
    cd trunk
    ./waf configure --prefix=/usr --includeresampler --includeconvolver --optimization
    ./waf build
    sudo ./waf install
    wget https://github.com/pelennor2170/NAM_models/archive/refs/heads/main.zip
    unzip main.zip
}

function compile_RT_kernel {
    cd ~/
    git clone --depth=1 --branch "rpi-6.6.y" https://github.com/raspberrypi/linux
    cd linux
    VERSION=$(head Makefile -n 4 | grep VERSION | cut -c11-)
    PATCHLEVEL=$(head Makefile -n 4 | grep PATCHLEVEL | cut -c14-)
    SUBLEVEL=$(head Makefile -n 4 | grep SUBLEVEL | cut -c12-)
    KERNEL_URL="https://www.kernel.org/pub/linux/kernel/projects/rt/$VERSION.$PATCHLEVEL/"
    wget "$KERNEL_URL"
    TMP_STR=$(cat index.html | grep patch | head -1 | cut -c10-)
    KERNEL_URL+=$(echo ${TMP_STR%%\"*})
    wget "$KERNEL_URL"
    gunzip patch*
    cat patch* | patch -p1
    KERNEL=kernel8
    make bcm2711_defconfig
    ## configure kernel for RT
    sed -i 's/CONFIG_LOCALVERSION="-v8"/CONFIG_LOCALVERSION="-v8-rt"/g' .config
    sed -i 's/# CONFIG_PREEMPT is not set/CONFIG_LOCALVERSION="-v8-rt"/g' .config
    sed -i 's/CONFIG_PREEMPT_BUILD=y/ /g' .config
    sed -i 's/CONFIG_PREEMPT=y/# CONFIG_PREEMPT is not set/g' .config
    sed -i 's/# CONFIG_PREEMPT_RT is not set/CONFIG_PREEMPT_RT=y/g' .config
    sed -i 's/# CONFIG_PREEMPT_DYNAMIC is not set/ /g' .config
    yes "" | make localmodconfig
    CFLAGS="$CFLAGS -fuse-ld=mold"
    CXXFLAGS="$CXXFLAGS -fuse-ld=mold"
    make -j$(nproc) Image.gz modules dtbs
    sudo make -j$(nproc) modules_install
    sudo cp /boot/firmware/$KERNEL.img /boot/firmware/$KERNEL-backup.img
    sudo cp arch/arm64/boot/Image.gz /boot/firmware/$KERNEL.img
    sudo cp arch/arm64/boot/dts/broadcom/*.dtb /boot/firmware/
    sudo cp arch/arm64/boot/dts/overlays/*.dtb* /boot/firmware/overlays/
    sudo cp arch/arm64/boot/dts/overlays/README /boot/firmware/overlays/
}


if [ ! -d ~/guitarix ]; then
    install_dependencies
    configure_system
    configure_dac_adc
    install_guitarix
    #### systemd service
    #echo "[Unit] \
    #Description=RaspiAmp kernel compilation \
    #After=network.target \
    # \
    #[Service] \
    #ExecStart=/usr/bin/bash $0 \
    # \
    #[Install] \
    #WantedBy=multi-user.target" > /etc/systemd/system/kernel-compile.service
    #sudo systemctl daemon-reload
    #sudo systemctl enable kernel-compile.service
    sudo reboot
fi
compile_RT_kernel
# sudo rm /etc/systemd/system/kernel-compile.service
sudo tuned-adm profile realtime

#### systemd service
#echo "[Unit] \
#Description=Zita-J2A Service \
#After=network.target \
# \
#[Service] \
#ExecStart=/usr/bin/zita-j2a -j bluealsa -d bluealsa -p 512 -n 2 -c 2 -L \
#Restart=always \
#RestartSec=30s \
# \
#[Install] \
#WantedBy=multi-user.target" > /etc/systemd/system/bt-connect.service
#sudo systemctl daemon-reload
#sudo systemctl start bt-connect.service
#sudo systemctl enable bt-connect.service

sudo reboot

