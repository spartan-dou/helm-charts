FROM nvidia/cuda:12.6.0-runtime-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:99 \
    PULSE_SERVER=unix:/run/pulse/native

# Installation des paquets de base et dépôts
RUN apt-get update && apt-get install -y \
    software-properties-common \
    wget \
    curl \
    gnupg2 \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Installation de XFCE et composants graphiques
RUN apt-get update && apt-get install -y \
    xfce4 \
    xfce4-terminal \
    xfce4-goodies \
    xserver-xorg-core \
    xserver-xorg-video-nvidia \
    xvfb \
    x11-xserver-utils \
    dbus-x11 \
    && rm -rf /var/lib/apt/lists/*

# Installation de Pipewire (remplace PulseAudio, plus moderne)
RUN apt-get update && apt-get install -y \
    pipewire \
    pipewire-pulse \
    pipewire-audio-client-libraries \
    wireplumber \
    pavucontrol \
    && rm -rf /var/lib/apt/lists/*

# Installation des drivers NVIDIA et dépendances
RUN apt-get update && apt-get install -y \
    libnvidia-encode-590 \
    libnvidia-decode-590 \
    mesa-va-drivers \
    libva2 \
    libva-drm2 \
    vainfo \
    && rm -rf /var/lib/apt/lists/*

# Installation de Sunshine
# Note: Vérifier la dernière version sur https://github.com/LizardByte/Sunshine/releases
RUN wget -O sunshine.deb https://github.com/LizardByte/Sunshine/releases/download/v2025.923.33222/sunshine-ubuntu-24.04-amd64.deb && \
    apt-get update && \
    apt-get install -y ./sunshine.deb && \
    rm sunshine.deb && \
    rm -rf /var/lib/apt/lists/*

# Installation d'applications utiles (optionnel)
RUN apt-get update && apt-get install -y \
    firefox \
    nano \
    htop \
    && rm -rf /var/lib/apt/lists/*

# Configuration de Pipewire
RUN mkdir -p /run/pulse /run/pipewire && \
    chmod 700 /run/pipewire

# Création des répertoires nécessaires
RUN mkdir -p /config /run/user/0 && \
    chmod 700 /run/user/0

# Configuration de Supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Ports Sunshine
EXPOSE 47984-47990/tcp 47984-47990/udp 48010/tcp

# Variables d'environnement
ENV XDG_RUNTIME_DIR=/run/user/0 \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=all

WORKDIR /root

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]