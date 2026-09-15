FROM nvidia/cuda:13.0.2-cudnn-devel-ubuntu24.04

WORKDIR /root

# unminimize and install utilities

RUN \
    apt-get update && \
    yes | unminimize

RUN \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apache2-utils \
    bash-completion \
    build-essential \
    byobu \
    bzip2 \
    cmake \
    curl \
    dnsutils \
    ffmpeg \
    git \
    gnupg2 \
    htop \
    iptables \
    net-tools \
    inetutils-ping \
    jq \
    nano \
    netcat-openbsd \
    rsync \
    sudo \
    supervisor \
    vim \
    tmux \
    zip unzip \
    wget && \
    rm -rf /var/lib/apt/lists/*

# add ssh

RUN \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server openssh-client && \
    mkdir -p /var/run/sshd && \
    rm -rf /var/lib/apt/lists/*

EXPOSE 22

# setup dind (docker)

RUN \
    apt-get update && \
    apt-get install -y ca-certificates curl gnupg && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo \
    "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && \
    rm -rf /var/lib/apt/lists/*

# and now nvidia docker

RUN \
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg && \
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list && \
    apt-get update && \
    export NVIDIA_CONTAINER_TOOLKIT_VERSION=1.18.1-1 && \
    apt-get install -y nvidia-container-toolkit=${NVIDIA_CONTAINER_TOOLKIT_VERSION} nvidia-container-toolkit-base=${NVIDIA_CONTAINER_TOOLKIT_VERSION} libnvidia-container-tools=${NVIDIA_CONTAINER_TOOLKIT_VERSION} libnvidia-container1=${NVIDIA_CONTAINER_TOOLKIT_VERSION} && \
    nvidia-ctk runtime configure --runtime=docker && \
    rm -rf /var/lib/apt/lists/*

COPY --chmod=755 image-scripts/modprobe /usr/local/bin/
COPY image-scripts/supervisor/ /etc/supervisor/conf.d/
COPY image-scripts/logger.sh /opt/bash-utils/logger.sh
COPY --chmod=755 image-scripts/startup.sh .

# this is crucial for dind, as it makes the fs type as ext4
VOLUME /var/lib/docker

# copy setup scripts
COPY setup-scripts /root/setup-scripts

# startup.sh enables cgroup nesting, then execs supervisord (PID 1), which runs dockerd and sshd
ENTRYPOINT ["./startup.sh"]
