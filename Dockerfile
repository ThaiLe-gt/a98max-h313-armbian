# Build environment for u-boot, TF-A and the out-of-tree Seekwave modules.
FROM debian:bookworm-slim
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential bison flex bc git ca-certificates libssl-dev libgnutls28-dev python3 python3-dev \
    python3-setuptools python3-pyelftools swig device-tree-compiler xz-utils cpio file libelf-dev kmod rsync \
    gcc-aarch64-linux-gnu u-boot-tools curl \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /work
