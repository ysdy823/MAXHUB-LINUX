FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
# Disable mono/gecko prompts — MAXHUB doesn't need .NET or IE
ENV WINEDLLOVERRIDES="mscoree=d;mshtml=d"

# Install Wine 11.x+ from WineHQ (slim: no mono/gecko, minimal build deps)
RUN dpkg --add-architecture i386 && \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends wget gnupg2 ca-certificates && \
    mkdir -p /etc/apt/keyrings && \
    wget -qO /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
    wget -qNP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources && \
    apt-get update -qq && \
    # Install Wine with recommends (needed for i386 libs), then remove mono/gecko
    apt-get install -y --install-recommends winehq-devel && \
    apt-get remove -y --purge wine-mono 2>/dev/null || true && \
    # Clean up build-only packages
    apt-get purge -y --auto-remove wget gnupg2 software-properties-common && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
           /usr/share/wine/mono /usr/share/wine/gecko \
           /usr/share/doc /usr/share/man

# Create non-root user for Wine
RUN useradd -m -s /bin/bash maxhub
USER maxhub
WORKDIR /home/maxhub

# Pre-initialize Wine prefix (speeds up first launch)
RUN wineboot --init 2>/dev/null || true && \
    rm -rf .cache/wine

# MAXHUB.exe will be mounted at runtime via -v
ENTRYPOINT ["wine"]
CMD ["/app/MAXHUB.exe"]
