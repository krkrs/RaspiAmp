# RaspiAmp
RaspiAmp is a script to configure your Raspberry Pi 4B to act as an guitar amplifier.
# Hardware
- [HifiBerry DAC+ ADC Pro](https://www.hifiberry.com/shop/boards/dacplus-adc/)
- Raspberry Pi 4B with 2GB RAM or more
- some kind of UPS HAT (optional)
# What the script does?
- installs
    - [BlueZ ALSA](https://github.com/arkq/bluez-alsa)
    - [Jack Audio Kit](https://github.com/jackaudio)
    - VNC
- compiles
    - real time kernel (lower latency)
    - [guitarix](https://github.com/brummer10/guitarix/) with NAM and convolver
- configures
    - HifiBerry HAT
    - Bluetooth (audio quality fix)
    - system for real time performance
# Performance
Jack is able to run with 2ms latency. Bluetooth latency depends on BT device it self. Minimal possible period value is 512. With good speaker/headphones it is enough to play.

# How to use?
First flash your Pi with Raspberry Pi OS Desktop version. Log in using SSH or GUI and and...
``` sh
sh <(curl -L https://raw.githubusercontent.com/krkrs/RaspiAmp/refs/heads/main/install.sh) 
```
... and wait. It will take some time. After reboot run script again and wait some more.
# Future functionality
- Neural Amp Modeler