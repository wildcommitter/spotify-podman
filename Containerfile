FROM debian:trixie

# Runtime dependencies for Spotify + Wayland + native PipeWire audio
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg ca-certificates \
    libnss3 libasound2t64 libxss1 libgbm1 libgtk-3-0t64 \
    libegl1 libgl1 libgles2 \
    mesa-vulkan-drivers libgl1-mesa-dri \
    libwayland-client0 libwayland-cursor0 libwayland-egl1 libxkbcommon0 \
    libpipewire-0.3-0 libspa-0.2-modules pipewire-bin \
    libasound2-plugins libpulse0 \
    fonts-dejavu-core fontconfig \
    dbus dbus-user-session \
    && rm -rf /var/lib/apt/lists/*

# Route ALSA calls through PulseAudio (handled by PipeWire on the host)
RUN echo 'pcm.!default { type pulse }' > /etc/asound.conf \
    && echo 'ctl.!default { type pulse }' >> /etc/asound.conf

# Add Spotify's signing key and repository, then install the client
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.gpg \
       | gpg --dearmor -o /etc/apt/keyrings/spotify.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/spotify.gpg] https://repository.spotify.com stable non-free" \
       > /etc/apt/sources.list.d/spotify.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends spotify-client \
    && rm -rf /var/lib/apt/lists/*

# Wayland launcher wrapper — handles the Ozone flags and forwards any extra args
RUN printf '#!/bin/sh\n\
exec /usr/bin/spotify \
--enable-features=UseOzonePlatform,WaylandWindowDecorations \
--ozone-platform=wayland \
--no-sandbox \
"$@"\n' > /usr/local/bin/spotify-wayland \
    && chmod +x /usr/local/bin/spotify-wayland

RUN useradd -m -u 1000 spotify
USER spotify
WORKDIR /home/spotify
RUN mkdir -p /home/spotify/.cache /home/spotify/.config

ENTRYPOINT ["/usr/local/bin/spotify-wayland"]
