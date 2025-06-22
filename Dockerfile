FROM ubuntu:22.04

# Environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:0
ENV NOVNC_PORT=6080
ENV VNC_PORT=5900
ENV RESOLUTION=1280x720
ENV VNC_PASSWORD=""
ENV ROOT_PASSWORD=""
ENV VIBE_PASSWORD="coding"

# Install packages for VNC and desktop environment

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # Core VNC and display packages
        xvfb \
        x11vnc \
        novnc \
        websockify \
        # Desktop environment
        fluxbox \
        pcmanfm \
        xterm \
        # Programming languages and tools
        python3 \
        python3-pip \
        # Utilities
        wget \
        curl \
        supervisor \
        dbus-x11 \
        menu \
        git \
        jq \
        nano \
        vim \
        dos2unix \
        # Security and user management
        sudo \
        openssh-server \
        # Cleanup in same layer
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/* \
        && rm -rf /tmp/* \
        && rm -rf /var/tmp/*

RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -

# Configure SSH server (passwords will be set at runtime)
RUN mkdir -p /var/run/sshd && \
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    ssh-keygen -A

# Create non-root user for better security
RUN useradd -m -s /bin/bash -u 1000 vibe && \
    usermod -aG sudo vibe && \
    mkdir -p /home/vibe/.fluxbox

# (optional) set the vibe user’s actual login password from your ENV
RUN echo "vibe:${VIBE_PASSWORD}" | chpasswd

RUN echo '# Unlimited sudo permissions for vibe user (NOPASSWD)' > /etc/sudoers.d/vibe && \
    echo 'vibe ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/vibe && \
    chmod 440 /etc/sudoers.d/vibe

# Install Node.js (LTS version)
USER vibe
RUN  sudo apt-get install -y nodejs && sudo rm -rf /var/lib/apt/lists/*
RUN npx -y playwright install chrome
USER root

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:${NOVNC_PORT}/vnc.html || exit 1

# Copy configuration files
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
COPY --chown=vibe:vibe servers.json /home/vibe/servers.json
COPY --chown=vibe:vibe .mcp.json /home/vibe/.mcp.json
COPY --chown=vibe:vibe fluxbox-startup /home/vibe/.fluxbox/startup
COPY --chown=vibe:vibe Xresources /home/vibe/.Xresources

RUN chmod +x /entrypoint.sh && \
    chmod +x /home/vibe/.fluxbox/startup

# Expose nginx port
EXPOSE 8000 6080

# Set entrypoint and default command
ENTRYPOINT ["/entrypoint.sh"]

CMD ["sudo", "supervisord", "-c", "/etc/supervisor/supervisord.conf"]
