FROM nvidia/cuda:13.1.1-runtime-ubuntu24.04

ARG VERSION=0.0.1

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:0 \
    XDG_RUNTIME_DIR=/run/user/0 \
    WLR_BACKENDS=headless \
    WLR_RENDERER=vulkan \
    WLR_NO_HARDWARE_CURSORS=1 \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=all

# Installation des paquets de base et dépôts
RUN apt-get update && apt-get install -y \
    software-properties-common \
    wget \
    curl \
    gnupg2 \
    supervisor \
    dbus-x11 \
    && rm -rf /var/lib/apt/lists/*

# sway + Xwayland
RUN apt-get update && apt-get install -y \
    sway \
    xwayland \
    grim \
    slurp \
    && rm -rf /var/lib/apt/lists/*
    
# PipeWire + WirePlumber (remplace PulseAudio)
RUN apt-get update && apt-get install -y \
    pipewire \
    pipewire-audio-client-libraries \
    pipewire-pulse \
    wireplumber \
    && rm -rf /var/lib/apt/lists/*

# Activer proposed pour récupérer les libs NVIDIA 590
RUN echo "deb http://archive.ubuntu.com/ubuntu noble-proposed multiverse" > /etc/apt/sources.list.d/proposed.list

# Installer les libs NVIDIA nécessaires (NVENC/NVDEC inclus dans libnvidia-compute-590)
RUN apt-get update && apt-get install -y \
    nvidia-utils-590 \
    libnvidia-compute-590 \
    && rm -rf /var/lib/apt/lists/*

# Désactiver proposed
RUN rm /etc/apt/sources.list.d/proposed.list
# Sunshine
RUN wget -O sunshine.deb https://github.com/LizardByte/Sunshine/releases/download/v2025.923.33222/sunshine-ubuntu-24.04-amd64.deb && \
    apt-get update && apt-get install -y ./sunshine.deb && \
    rm sunshine.deb && rm -rf /var/lib/apt/lists/*

# Runtime dirs
RUN mkdir -p /run/user/0 && chmod 700 /run/user/0

# Config sway
COPY sway-config /etc/sway/config

# Config sunshine
COPY sunshine.conf /root/.config/sunshine/sunshine.conf

# Supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 47984-47990/tcp 47984-47990/udp 48010/tcp

WORKDIR /root

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
