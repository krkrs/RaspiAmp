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
    - [Sushi](https://github.com/elk-audio/sushi)
- configures
    - HifiBerry HAT
    - Bluetooth (audio quality fix)
# How to use?
First flash your Pi with Raspberry Pi OS Desktop version. Log in using SSH or GUI and and...
``` sh
sh <(curl -L https://raw.githubusercontent.com/krkrs/RaspiAmp/refs/heads/master/install.sh) 
```
... and wait. It will take some time.
# Future functionality
- Neural Amp Modeler