FROM ghcr.io/actions/actions-runner:2.328.0 AS actions-runner

# renovate: datasource=github-releases depName=google/go-containerregistry
ARG CRANE_VERSION=v0.20.6
# renovate: datasource=github-releases depName=mikefarah/yq
ARG YQ_VERSION=v4.47.1
# renovate: datasource=github-releases depName=getsops/sops
ARG SOPS_VERSION=v3.10.2
# renovate: datasource=github-tags depName=aws/aws-cli
ARG AWSCLI_VERSION=2.28.14

USER root

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

RUN curl -fSL https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 -o /usr/bin/yq && chmod +x /usr/bin/yq
RUN curl -fSL https://github.com/google/go-containerregistry/releases/download/${CRANE_VERSION}/go-containerregistry_Linux_x86_64.tar.gz | tar xzf - -C /usr/local/bin/ crane
RUN curl -fSL https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.amd64 -o /usr/bin/sops && chmod +x /usr/bin/sops
RUN curl -fSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip -o awscliv2.zip && unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws

USER runner
