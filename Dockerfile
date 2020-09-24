ARG DOCKER=docker:19.03.12
ARG BUILDKIT=moby/buildkit:v0.7.1
ARG GOLANG=golang:1.14-alpine

FROM $DOCKER as docker
FROM $BUILDKIT as buildkit

FROM $GOLANG as tc-redirect-tap

ARG FIRECRACKER_SDK_VERSION=v0.19.0

WORKDIR /src

RUN apk add --update --no-cache \
  curl \
  make

# TODO: switch to awslabs/tc-redirect-tap once it has a release
RUN curl -LO https://github.com/firecracker-microvm/firecracker-go-sdk/archive/${FIRECRACKER_SDK_VERSION}.tar.gz
RUN tar xzf ${FIRECRACKER_SDK_VERSION}.tar.gz --strip-components=1
RUN make -C cni install

FROM alpine:3.11

ARG CLOUD_SDK_VERSION=304.0.0
ARG CNI_PLUGINS_VERSION=v0.8.5
ARG FIRECRACKER_VERSION=v0.21.0
ARG BUILDX=v0.4.1
ARG GIT_CHGLOG_VERSION=0.9.1

# janky janky janky
ENV PATH /google-cloud-sdk/bin:$PATH

RUN apk add --update --no-cache \
  bash \
  curl \
  gcc \
  git \
  gnupg \
  iptables \
  ip6tables \
  jq \
  libc6-compat \
  libffi-dev \
  make \
  musl-dev \
  openssh-client \
  openssl-dev \
  ovmf \
  py3-crcmod \
  py3-pip \
  python3 \
  python3-dev \
  qemu-img \
  qemu-system-aarch64 \
  qemu-system-x86_64 \
  xz

# Install gcloud
RUN curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
  tar xzf google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
  rm google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
  gcloud config set core/disable_usage_reporting true && \
  gcloud config set component_manager/disable_update_check true && \
  gcloud config set metrics/environment github_docker_image

# Install aws
RUN pip3 install awscli s3cmd

# Install azure
RUN pip3 install azure-cli

# Install CNI
RUN mkdir -p /opt/cni/bin /etc/cni/conf.d /var/lib/cni
RUN curl -LO https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-amd64-${CNI_PLUGINS_VERSION}.tgz && \
  tar xzf cni-plugins-linux-amd64-${CNI_PLUGINS_VERSION}.tgz  -C /opt/cni/bin && \
  rm cni-plugins-linux-amd64-${CNI_PLUGINS_VERSION}.tgz

# Install firecracker
RUN curl -Lo /usr/local/bin/firecracker https://github.com/firecracker-microvm/firecracker/releases/download/${FIRECRACKER_VERSION}/firecracker-${FIRECRACKER_VERSION}-x86_64 \
  && chmod 755 /usr/local/bin/firecracker

# Required by docker-compose for zlib.
ENV LD_LIBRARY_PATH=/lib:/usr/lib

# Install buildx
RUN curl --create-dirs -Lo /root/.docker/cli-plugins/docker-buildx https://github.com/docker/buildx/releases/download/${BUILDX}/buildx-${BUILDX}.linux-amd64 \
  && chmod 755 /root/.docker/cli-plugins/docker-buildx

# Install custom scripts
ADD hack/scripts/ /usr/local/bin/
ADD hack/buildkit.conf /usr/local/etc/

RUN curl -Lo /usr/local/bin/git-chglog https://github.com/git-chglog/git-chglog/releases/download/${GIT_CHGLOG_VERSION}/git-chglog_linux_amd64
RUN chmod +x /usr/local/bin/git-chglog

COPY --from=docker /usr/local/bin/docker /usr/local/bin/dockerd /usr/local/bin/
COPY --from=buildkit /usr/bin/buildctl /usr/local/bin/
COPY --from=tc-redirect-tap /opt/cni/bin/tc-redirect-tap /opt/cni/bin/
