# renovate: datasource=github-releases extractVersion=^gha-runner-scale-set-(?<version>.*)$ depName=actions/actions-runner-controller
ARG ACTIONS_RUNNER_CONTROLLER_VERSION=0.23.7
FROM scratch AS actions-runner-controller-source
ADD https://github.com/actions/actions-runner-controller.git#${ACTIONS_RUNNER_CONTROLLER_VERSION}:runner /

# Ref: https://github.com/actions/actions-runner-controller/blob/master/runner/actions-runner-dind.ubuntu-22.04.dockerfile
FROM ubuntu:plucky-20250730 AS build-container-ghaction

ARG TARGETPLATFORM
# renovate: datasource=github-releases extractVersion=^v(?<version>.*)$ depName=actions/runner
ARG RUNNER_VERSION=2.328.0
# renovate: datasource=github-releases extractVersion=^v(?<version>.*)$ depName=actions/runner-container-hooks
ARG RUNNER_CONTAINER_HOOKS_VERSION=0.7.0
# Docker and Docker Compose arguments
ARG CHANNEL=stable
# renovate: datasource=github-releases extractVersion=^v(?<version>.*)$ depName=moby/moby
ARG DOCKER_VERSION=28.3.3
# renovate: datasource=github-releases depName=docker/compose
ARG DOCKER_COMPOSE_VERSION=v2.39.2
# renovate: datasource=github-releases extractVersion=^v(?<version>.*)$ depName=yelp/dumb-init
ARG DUMB_INIT_VERSION=1.2.5
ARG RUNNER_USER_UID=1001
ARG DOCKER_GROUP_GID=121

# renovate: datasource=github-releases depName=google/go-containerregistry
ARG CRANE_VERSION=v0.20.6
# renovate: datasource=github-releases depName=mikefarah/yq
ARG YQ_VERSION=v4.47.1
# renovate: datasource=github-releases depName=getsops/sops
ARG SOPS_VERSION=v3.10.2
# renovate: datasource=github-tags depName=aws/aws-cli
ARG AWSCLI_VERSION=2.28.14

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y \
    && apt-get install -y software-properties-common \
    && add-apt-repository -y ppa:git-core/ppa \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    iptables \
    jq \
    software-properties-common \
    sudo \
    unzip \
    zip \
    && rm -rf /var/lib/apt/lists/*

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
    libicu76 \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fSL https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 -o /usr/bin/yq && chmod +x /usr/bin/yq
RUN curl -fSL https://github.com/google/go-containerregistry/releases/download/${CRANE_VERSION}/go-containerregistry_Linux_x86_64.tar.gz | tar xzf - -C /usr/local/bin/ crane
RUN curl -fSL https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.amd64 -o /usr/bin/sops && chmod +x /usr/bin/sops
RUN curl -fSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip -o awscliv2.zip && unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws

# Runner user
RUN adduser --disabled-password --gecos "" --uid $RUNNER_USER_UID runner \
    && groupadd docker --gid $DOCKER_GROUP_GID \
    && usermod -aG sudo runner \
    && usermod -aG docker runner \
    && echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers \
    && echo "Defaults env_keep += \"DEBIAN_FRONTEND\"" >> /etc/sudoers

ENV HOME=/home/runner

RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi \
    && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x86_64 ; fi \
    && curl -fLo /usr/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_${ARCH} \
    && chmod +x /usr/bin/dumb-init

# installdependencies.sh is not updated for Ubuntu 25.04, so we add libicu76 manually above.
ENV RUNNER_ASSETS_DIR=/runnertmp
RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x64 ; fi \
    && mkdir -p "$RUNNER_ASSETS_DIR" \
    && cd "$RUNNER_ASSETS_DIR" \
    && curl -fLo runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./runner.tar.gz \
    && rm -f runner.tar.gz \
    && ./bin/installdependencies.sh \
    # libyaml-dev is required for ruby/setup-ruby action.
    # It is installed after installdependencies.sh and before removing /var/lib/apt/lists
    # to avoid rerunning apt-update on its own.
    && apt-get install -y libyaml-dev \
    && rm -rf /var/lib/apt/lists/*

ENV RUNNER_TOOL_CACHE=/opt/hostedtoolcache
RUN mkdir /opt/hostedtoolcache \
    && chgrp docker /opt/hostedtoolcache \
    && chmod g+rwx /opt/hostedtoolcache

RUN cd "$RUNNER_ASSETS_DIR" \
    && curl -fLo runner-container-hooks.zip https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_VERSION}/actions-runner-hooks-k8s-${RUNNER_CONTAINER_HOOKS_VERSION}.zip \
    && unzip ./runner-container-hooks.zip -d ./k8s \
    && rm -f runner-container-hooks.zip

RUN set -vx; \
    export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi \
    && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x86_64 ; fi \
    && curl -fLo docker.tgz https://download.docker.com/linux/static/${CHANNEL}/${ARCH}/docker-${DOCKER_VERSION}.tgz \
    && tar zxvf docker.tgz \
    && install -o root -g root -m 755 docker/* /usr/bin/ \
    && rm -rf docker docker.tgz

RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi \
    && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x86_64 ; fi \
    && mkdir -p /usr/libexec/docker/cli-plugins \
    && curl -fLo /usr/libexec/docker/cli-plugins/docker-compose https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-${ARCH} \
    && chmod +x /usr/libexec/docker/cli-plugins/docker-compose \
    && ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/bin/docker-compose \
    && which docker-compose \
    && docker compose version

# We place the scripts in `/usr/bin` so that users who extend this image can
# override them with scripts of the same name placed in `/usr/local/bin`.
ARG RUNNER_CONTROLLER_SCRIPT_DIR_URL=https://raw.githubusercontent.com/actions/actions-runner-controller/refs/tags/gha-runner-scale-set-0.10.1/runner
ADD ${RUNNER_CONTROLLER_SCRIPT_DIR_URL}/entrypoint-dind.sh \
    ${RUNNER_CONTROLLER_SCRIPT_DIR_URL}/startup.sh \
    ${RUNNER_CONTROLLER_SCRIPT_DIR_URL}/logger.sh \
    ${RUNNER_CONTROLLER_SCRIPT_DIR_URL}/wait.sh \
    ${RUNNER_CONTROLLER_SCRIPT_DIR_URL}/graceful-stop.sh \
    ${RUNNER_CONTROLLER_SCRIPT_DIR_URL}/update-status \
    /usr/bin/
COPY --from=actions-runner-controller-source \
    /entrypoint-dind.sh \
    /startup.sh \
    /logger.sh \
    /wait.sh \
    /graceful-stop.sh \
    /update-status \
    /usr/bin/
RUN chmod +x /usr/bin/entrypoint-dind.sh /usr/bin/startup.sh

# Copy the docker shim which propagates the docker MTU to underlying networks
# to replace the docker binary in the PATH.
COPY --from=actions-runner-controller-source /docker-shim.sh /usr/local/bin/docker

# Configure hooks folder structure.
COPY --from=actions-runner-controller-source /hooks /etc/arc/hooks/

VOLUME /var/lib/docker

# Add the Python "User Script Directory" to the PATH
ENV PATH="${PATH}:${HOME}/.local/bin"
ENV ImageOS=ubuntu25

RUN echo "PATH=${PATH}" > /etc/environment \
    && echo "ImageOS=${ImageOS}" >> /etc/environment

# No group definition, as that makes it harder to run docker.
USER runner

ENTRYPOINT ["/bin/bash", "-c"]
CMD ["entrypoint-dind.sh"]
