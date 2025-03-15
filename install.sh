# system upgrade
sudo apt update && sudo apt full-upgrade -y
# dependencies
read -p "During installation you will be asked whether to enable real time priority for jackd process. Press enter and enable RT priority."
sudo apt install qjackctl bluez-alsa-utils \  # audio
    git libncurses5-dev flex build-essential bison libssl-dev bc make linux-headers-rpi-v8 \ # kernel
    libasound2-dev libjack-jackd2-dev liblilv-dev lilv-utils lv2-dev cmake ninja-build \ # sushi
    mold zram-tools -y # improve compilation 
# configure pi os
sudo systemctl disable NetworkManager-wait-online.service
sudo raspi-config nonint do_vnc 0
# remove unnecessary packages
sudo apt purge cups modemmanager --auto-remove -y
# fix bluetooth audio quality
sudo sed -i 's/btc_mode=1/btc_mode=4/g' /usr/lib/firmware/brcm/brcmfmac43455-sdio.txt
# configure HifiBerry DAC+ ADC Pro
sudo sed -i 's/dtparam=audio=on/# dtparam=audio=on/g' /boot/firmware/config.txt
sudo sed -i 's/dtoverlay=vc4-kms-v3d/dtoverlay=vc4-kms-v3d,noaudio/g' /boot/firmware/config.txt
sudo sed -i '1 i\force_eeprom_read=0' /boot/firmware/config.txt
sudo sed -i '1 i\dtoverlay=hifiberry-dacplusadcpro' /boot/firmware/config.txt
# compile minimal RT kernel 
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
sudo make -j4 modules_install
sudo cp /boot/firmware/$KERNEL.img /boot/firmware/$KERNEL-backup.img
sudo cp arch/arm64/boot/Image.gz /boot/firmware/$KERNEL.img
sudo cp arch/arm64/boot/dts/broadcom/*.dtb /boot/firmware/
sudo cp arch/arm64/boot/dts/overlays/*.dtb* /boot/firmware/overlays/
sudo cp arch/arm64/boot/dts/overlays/README /boot/firmware/overlays/
# sushi
cd ~/
git clone --recurse-submodules https://github.com/elk-audio/sushi.git
cd sushi && mkdir build && cd build
export VCPKG_FORCE_SYSTEM_BINARIES=1
../third-party/vcpkg/bootstrap-vcpkg.sh
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=../third-party/vcpkg/scripts/buildsystems/vcpkg.cmake ..
make 
### systemd service
echo "[Unit] \
Description=Zita-J2A Service \
After=network.target \
 \
[Service] \
ExecStart=/usr/bin/zita-j2a -j bluealsa -d bluealsa -p 512 -n 2 -c 2 -L \
Restart=always \
RestartSec=30s \
 \
[Install] \
WantedBy=multi-user.target" > /etc/systemd/system/bt-connect.service
sudo systemctl daemon-reload
sudo systemctl start bt-connect.service
sudo systemctl enable bt-connect.service

sudo reboot