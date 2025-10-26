#!/bin/bash
nproc=$(( $(nproc) + 2 ))

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
        qt6-base-dev qt6-svg-dev libportaudio2 qt6-tools-dev \
        imagemagick \
        libasound2-dev
}

function install_qjackctl {
    cd ~/
    git clone https://github.com/rncbc/qjackctl
    cd qjackctl
    cmake -B build -DCONFIG_JACK_VERSION=ON
    cmake --build build --parallel $nproc
    sudo cmake --install build
}

function configure_system {
    sudo tuned-adm profile throughput-performance
    sudo systemctl disable NetworkManager-wait-online.service
    sudo raspi-config nonint do_vnc 0
    # solid background 
    convert -size 100x100 xc:red red.png
    sudo pcmanfm --wallpaper-mode=stretch --set-wallpaper=red.png
    # remove unnecessary packages
    sudo apt purge cups modemmanager --auto-remove -y
    # fix bluetooth audio quality
    sudo sed -i 's/btc_mode=1/btc_mode=4/g' /usr/lib/firmware/brcm/brcmfmac43455-sdio.txt
    # vnc fps
    sudo sed -i 's/--detached/--detached --max-fps 5/g' /usr/sbin/wayvnc-run.sh
    # memory lock limit
    sudo sh -c "echo @audio - memlock 256000 >> /etc/security/limits.conf"
    # rt priority for audio group
    sudo sh -c "echo @audio - rtprio 75 >> /etc/security/limits.conf"
    # in case you ever run audio server as root
    sudo usermod -a -G audio root
    sudo mkdir -p /root/.config
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
    wget https://github.com/brummer10/guitarix/archive/refs/tags/V0.47.0.tar.gz
    tar -xvzf V0.47.0.tar.gz
    cp -r guitarix-0.47.0/trunk ./
    ./waf configure --prefix=/usr --includeresampler --includeconvolver --optimization
    ./waf build
    sudo ./waf install
}

function install_jack2 {
    cd ~/
    git clone https://github.com/jackaudio/jack2 --depth 1
    cd jack2
    ./waf configure --alsa --libdir=/usr/lib/aarch64-linux-gnu/
    sudo ./waf install
}

function compile_RT_kernel {
    cd ~/
    git clone --depth=1 --branch "rpi-6.18.y" https://github.com/raspberrypi/linux
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
    make CFLAGS='-O3 -march=native' -j"$nproc" Image.gz modules dtbs
    sudo make -j"$nproc" modules_install
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
install_jack2
install_qjackctl
compile_RT_kernel
sudo tuned-adm profile realtime

sudo reboot

