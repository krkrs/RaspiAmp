#!/bin/bash

function install_dependencies {
    sudo apt update && sudo apt full-upgrade -y
    sudo apt install -y rt-tests btop bluez-alsa-utils zita-ajbridge mold zram-tools tuned \
        git cmake libncurses5-dev flex build-essential bison libssl-dev bc make linux-headers-rpi-v8 \
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
        fonts-roboto \
        qt6-base-dev qt6-svg-dev libportaudio2
}

function install_qjackctl {
    cd ~/
    cmake -B build
    cmake --build build --parallel 4
    git clone https://github.com/rncbc/qjackctl
    cd qjackctl
    sudo cmake --install build
}

function configure_system {
    sudo tuned-adm profile throughput-performance
    sudo systemctl disable NetworkManager-wait-online.service
    sudo raspi-config nonint do_vnc 0
    # remove unnecessary packages
    sudo apt purge cups modemmanager --auto-remove -y
    # fix bluetooth audio quality
    sudo sed -i 's/btc_mode=1/btc_mode=4/g' /usr/lib/firmware/brcm/brcmfmac43455-sdio.txt
    # vnc fps
    sudo sed -i 's/--detached/--detached --max-fps 1/g' /usr/sbin/wayvnc-run.sh
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
}

function install_jackd2 {
    cd ~/
    git clone --recursive https://github.com/jackaudio/jack2.git
    cd jack2
    ./waf configure
    ./waf
    ./waf install
}

function compile_RT_kernel-path {
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

function compile_RT_kernel {
    cd ~/
    git clone --depth=1 --branch "rpi-6.14.y" https://github.com/raspberrypi/linux
    cd linux
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
    make prepare
    make CFLAGS='-O3 -march=native' -j6 Image.gz modules dtbs
    sudo make -j6 modules_install
    sudo cp /boot/firmware/$KERNEL.img /boot/firmware/$KERNEL-backup.img
    sudo cp arch/arm64/boot/Image.gz /boot/firmware/$KERNEL.img
    sudo cp arch/arm64/boot/dts/broadcom/*.dtb /boot/firmware/
    sudo cp arch/arm64/boot/dts/overlays/*.dtb* /boot/firmware/overlays/
    sudo cp arch/arm64/boot/dts/overlays/README /boot/firmware/overlays/
}

install_dependencies
configure_system
configure_dac_adc
install_guitarix
install_jackd2
install_qjackctl
compile_RT_kernel
sudo tuned-adm profile realtime

sudo reboot

