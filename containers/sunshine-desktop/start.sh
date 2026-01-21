#!/bin/bash
set -e

export XDG_RUNTIME_DIR=/run/user/0
export DISPLAY=:0
export WAYLAND_DISPLAY=wayland-0
export WLR_BACKENDS=headless
export WLR_LIBINPUT_NO_DEVICES=1

# Création du runtime dir
mkdir -p /run/user/0
chmod 700 /run/user/0

# Démarrer PipeWire + WirePlumber
pipewire &
sleep 0.5
pipewire-pulse &
sleep 0.5
wireplumber &
sleep 0.5

# Lancer sway en mode headless
sway --unsupported-gpu --config /etc/sway/config &

# Attendre que Wayland soit prêt
sleep 2

# Lancer Sunshine
sunshine
