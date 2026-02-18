FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Install Wine 11.x+ from WineHQ
RUN dpkg --add-architecture i386 && \
    apt-get update -qq && \
    apt-get install -y -qq wget gnupg2 software-properties-common ca-certificates && \
    mkdir -p /etc/apt/keyrings && \
    wget -qO /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
    wget -qNP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources && \
    apt-get update -qq && \
    apt-get install -y --install-recommends winehq-devel && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user for Wine
RUN useradd -m -s /bin/bash maxhub
USER maxhub
WORKDIR /home/maxhub

# Pre-initialize Wine prefix (speeds up first launch)
RUN DISPLAY= wineboot --init 2>/dev/null || true

# MAXHUB.exe will be mounted at runtime via -v
ENTRYPOINT ["wine"]
CMD ["/app/MAXHUB.exe"]
