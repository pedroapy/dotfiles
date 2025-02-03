#!/bin/bash

# install current firmwares
yay -S --noconfirm linux-firmware ast-firmware wd719x-firmware aic94xx-firmware intel-ucode linux-firmware-qlogic upd72020x-fw

echo 'options i915 enable_guc=3' | sudo tee /etc/modprobe.d/i915.conf

