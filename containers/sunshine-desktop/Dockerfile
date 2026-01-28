FROM lizardbyte/sunshine:v2026.127.213403-ubuntu-24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install Xorg, XFCE, audio, and basic tools
RUN apt-get update && \
    apt-get install -y \
        xfce4 \
        xfce4-goodies \
        xorg \
        dbus-x11 \
        pulseaudio \
        alsa-utils \
        mesa-utils \
        sudo \
        wget \
        curl \
        nano \
        supervisor && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create sunshine user
RUN useradd -m -s /bin/bash sunshine && \
    usermod -aG sudo sunshine && \
    echo "sunshine ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# PulseAudio config
RUN mkdir -p /home/sunshine/.config/pulse && \
    chown -R sunshine:sunshine /home/sunshine/.config

# Supervisor config for Xorg + XFCE + Sunshine
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose Sunshine ports
EXPOSE 47984/tcp
EXPOSE 47990/tcp
EXPOSE 47989/udp
EXPOSE 48010/tcp

USER sunshine
WORKDIR /home/sunshine

CMD ["/usr/bin/supervisord", "-n"]
