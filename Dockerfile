# Adapted from https://github.com/actions/runner/blob/main/images/Dockerfile
FROM ubuntu:questing-20251007 AS build

ARG TARGETOS
ARG TARGETARCH
ARG RUNNER_VERSION=2.329.0
ARG RUNNER_CONTAINER_HOOKS_VERSION=0.7.0
ARG DOCKER_VERSION=28.5.1
ARG BUILDX_VERSION=0.29.1

RUN apt update -y && apt install curl unzip -y

WORKDIR /actions-runner
RUN export RUNNER_ARCH=${TARGETARCH} \
    && if [ "$RUNNER_ARCH" = "amd64" ]; then export RUNNER_ARCH=x64 ; fi \
    && curl -f -L -o runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-${TARGETOS}-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./runner.tar.gz \
    && rm runner.tar.gz

RUN curl -f -L -o runner-container-hooks.zip https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_VERSION}/actions-runner-hooks-k8s-${RUNNER_CONTAINER_HOOKS_VERSION}.zip \
    && unzip ./runner-container-hooks.zip -d ./k8s \
    && rm runner-container-hooks.zip

RUN curl -f -L -o runner-container-hooks.zip https://github.com/actions/runner-container-hooks/releases/download/v0.8.0/actions-runner-hooks-k8s-0.8.0.zip \
    && unzip ./runner-container-hooks.zip -d ./k8s-novolume \
    && rm runner-container-hooks.zip

RUN export RUNNER_ARCH=${TARGETARCH} \
    && if [ "$RUNNER_ARCH" = "amd64" ]; then export DOCKER_ARCH=x86_64 ; fi \
    && if [ "$RUNNER_ARCH" = "arm64" ]; then export DOCKER_ARCH=aarch64 ; fi \
    && curl -fLo docker.tgz https://download.docker.com/${TARGETOS}/static/stable/${DOCKER_ARCH}/docker-${DOCKER_VERSION}.tgz \
    && tar zxvf docker.tgz \
    && rm -rf docker.tgz \
    && mkdir -p /usr/local/lib/docker/cli-plugins \
    && curl -fLo /usr/local/lib/docker/cli-plugins/docker-buildx \
        "https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-${TARGETARCH}" \
    && chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx

FROM ubuntu:questing-20251007 AS actions-runner

ARG TARGETARCH

# renovate: datasource=github-releases depName=google/go-containerregistry
ARG CRANE_VERSION=v0.20.6
# renovate: datasource=github-releases depName=mikefarah/yq
ARG YQ_VERSION=v4.48.1
# renovate: datasource=github-releases depName=getsops/sops
ARG SOPS_VERSION=v3.11.0
# renovate: datasource=github-tags depName=aws/aws-cli
ARG AWSCLI_VERSION=2.31.18

ENV DEBIAN_FRONTEND=noninteractive
ENV RUNNER_MANUALLY_TRAP_SIG=1
ENV ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1
ENV ImageOS=ubuntu25

# 'gpg-agent' and 'software-properties-common' are needed for the 'add-apt-repository' command that follows
RUN apt update -y \
    && apt-get install -y --no-install-recommends \
            curl \
            gpg-agent \
            libkrb5-3 \
            libssl3 \
            liblttng-ust1 \
            libicu76 \
            lsb-release \
            jq \
            software-properties-common \
            sudo \
            unzip \
            zlib1g \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure git-core/ppa based on guidance here:  https://git-scm.com/download/linux
RUN add-apt-repository ppa:git-core/ppa \
    && apt update -y \
    && apt install -y git \
    && rm -rf /var/lib/apt/lists/*

RUN adduser --disabled-password --gecos "" --uid 1001 runner \
    && groupadd docker --gid 123 \
    && usermod -aG sudo runner \
    && usermod -aG docker runner \
    && echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers \
    && echo "Defaults env_keep += \"DEBIAN_FRONTEND\"" >> /etc/sudoers

WORKDIR /home/runner

COPY --chown=runner:docker --from=build /actions-runner .
COPY --from=build /usr/local/lib/docker/cli-plugins/docker-buildx /usr/local/lib/docker/cli-plugins/docker-buildx

RUN install -o root -g root -m 755 docker/* /usr/bin/ && rm -rf docker

# Siderolabs custom packages
RUN apt-get update -y && \
    apt upgrade -y && \
    apt install -y \
    --no-install-recommends \
    curl \
    diffoscope \
    gh \
    iproute2 \
    iptables \
    make \
    mkisofs \
    openssh-client \
    ovmf \
    qemu-system \
    qemu-utils \
    socat \
    swtpm \
    tmux \
    unzip \
    zstd \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fSL https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${TARGETARCH} -o /usr/bin/yq && chmod +x /usr/bin/yq
RUN export CRANE_PLATFORM=${TARGETARCH} \
    && if [ "$CRANE_PLATFORM" = "amd64" ]; then CRANE_PLATFORM=x86_64 ; fi \
    && curl -fSL https://github.com/google/go-containerregistry/releases/download/${CRANE_VERSION}/go-containerregistry_Linux_${CRANE_PLATFORM}.tar.gz | tar xzf - -C /usr/local/bin/ crane
RUN curl -fSL https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.${TARGETARCH} -o /usr/bin/sops && chmod +x /usr/bin/sops
RUN export AWSCLI_PLATFORM=${TARGETARCH} \
    && if [ "$AWSCLI_PLATFORM" = "amd64" ]; then AWSCLI_PLATFORM=x86_64 ; fi \
    && if [ "$AWSCLI_PLATFORM" = "arm64" ]; then AWSCLI_PLATFORM=aarch64 ; fi \
    && curl -fSL https://awscli.amazonaws.com/awscli-exe-linux-${AWSCLI_PLATFORM}-${AWSCLI_VERSION}.zip -o awscliv2.zip && unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws

USER runner
