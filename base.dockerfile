ARG CUDA_VER=12.6.3
ARG UBUNTU_VER=22.04

# Download the base image. *check for all available images at https://hub.docker.com/r/nvidia/cuda/tags
FROM nvidia/cuda:${CUDA_VER}-cudnn-runtime-ubuntu${UBUNTU_VER}

# Install as root
USER root

# Shell
SHELL ["/bin/bash", "--login", "-o", "pipefail", "-c"]

# miniconda path
ENV CONDA_DIR=/opt/miniconda

# conda path
ENV PATH=${CONDA_DIR}/bin:$PATH

ARG DEBIAN_FRONTEND="noninteractive"
ARG USERNAME=developer
ARG USERID=1000
ARG GROUPID=1000

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    htop \
    nano \
    nvidia-modprobe \
    nvtop \
    openssh-client \
    sudo \
    unzip \
    wget \ 
    zip  \
    build-essential \
    file \
    zsh && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install miniconda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
    /bin/bash miniconda.sh -b -p ${CONDA_DIR} && \
    rm -rf miniconda.sh

# Add a user `${USERNAME}` so that you're not developing as the `root` user
RUN groupadd -g ${GROUPID} ${USERNAME} && \
    useradd ${USERNAME} \
    --create-home \
    --uid ${USERID} \
    --gid ${GROUPID} \
    --shell=/bin/zsh && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >>/etc/sudoers.d/nopasswd && \
    chown -R ${USERID}:${GROUPID} ${CONDA_DIR} && \
    echo ". $CONDA_DIR/etc/profile.d/conda.sh" >>/home/${USERNAME}/.profile

USER ${USERNAME}
WORKDIR /home/${USERNAME}

# Initilize shell for conda
RUN conda init zsh && source /home/${USERNAME}/.bashrc 
RUN mkdir -p /home/${USERNAME}/workspace && \
cd /home/${USERNAME}/workspace && \
conda create -n workspace "python>=3.12,<3.13" && \
conda activate workspace && \
pip install -U torch torchvision torchaudio lightning-sdk litserve litdata accelerate xformers diffusion

# Initialize shell for workspace
RUN conda init zsh && source /home/${USERNAME}/.bashrc && cd /home/${USERNAME}/workspace && conda activate workspace