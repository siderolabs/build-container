ARG DOCKER=docker:19.03.13
ARG GOLANG=golang:1.14-alpine

FROM $DOCKER as docker

FROM alpine:3.13

ARG CLOUD_SDK_VERSION=304.0.0
ARG BUILDX=v0.5.1
ARG GIT_CHGLOG_VERSION=0.9.1

# janky janky janky
ENV PATH /google-cloud-sdk/bin:$PATH

RUN apk add --update --no-cache \
  bash \
  coreutils \
  curl \
  gcc \
  git \
  git-lfs \
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
  rust \
  sed \
  tar \
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

# Required by docker-compose for zlib.
ENV LD_LIBRARY_PATH=/lib:/usr/lib

# Install buildx
RUN curl --create-dirs -Lo /root/.docker/cli-plugins/docker-buildx https://github.com/docker/buildx/releases/download/${BUILDX}/buildx-${BUILDX}.linux-amd64 \
  && chmod 755 /root/.docker/cli-plugins/docker-buildx

# Install custom scripts
ADD hack/scripts/ /usr/local/bin/

RUN curl -Lo /usr/local/bin/git-chglog https://github.com/git-chglog/git-chglog/releases/download/${GIT_CHGLOG_VERSION}/git-chglog_linux_amd64
RUN chmod +x /usr/local/bin/git-chglog

COPY --from=docker /usr/local/bin/docker /usr/local/bin/dockerd /usr/local/bin/
