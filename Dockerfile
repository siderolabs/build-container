ARG DOCKER=docker:20.10.21-dind

FROM $DOCKER as docker

FROM alpine:3.16.3

# https://github.com/twistedpair/google-cloud-sdk/ is a mirror that replicates the gcloud sdk versions
# renovate: datasource=github-tags depName=twistedpair/google-cloud-sdk
ARG CLOUD_SDK_VERSION=410.0.0
# renovate: datasource=github-releases depName=docker/buildx
ARG BUILDX_VERSION=v0.9.1
# renovate: datasource=github-releases depName=git-chglog/git-chglog extractVersion=^v(?<version>.*)$
ARG GIT_CHGLOG_VERSION=0.15.1

# janky janky janky
ENV PATH /google-cloud-sdk/bin:$PATH

RUN apk add --update --no-cache \
  aws-cli \
  bash \
  cargo \
  coreutils \
  curl \
  gcc \
  git \
  git-lfs \
  gnupg \
  ip6tables \
  iptables \
  jq \
  libc6-compat \
  libffi-dev \
  make \
  musl-dev \
  openssh-client \
  openssl-dev \
  ovmf \
  perl-utils \
  py3-crcmod \
  py3-pip \
  python3 \
  python3-dev \
  qemu-img \
  qemu-system-aarch64 \
  qemu-system-x86_64 \
  rust \
  sed \
  socat \
  tar \
  xz

# Install gcloud
RUN curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
  tar xzf google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
  rm google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
  gcloud config set core/disable_usage_reporting true && \
  gcloud config set component_manager/disable_update_check true && \
  gcloud config set metrics/environment github_docker_image

RUN apk add s3cmd --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing

# Install azure
RUN pip3 install azure-cli

# Required by docker-compose for zlib.
ENV LD_LIBRARY_PATH=/lib:/usr/lib

# Install buildx
RUN curl --create-dirs -Lo /root/.docker/cli-plugins/docker-buildx https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.linux-amd64 \
  && chmod 755 /root/.docker/cli-plugins/docker-buildx

# Install git-chglog
RUN curl -Lo /usr/local/bin/git-chglog https://github.com/git-chglog/git-chglog/releases/download/${GIT_CHGLOG_VERSION}/git-chglog_linux_amd64
RUN curl -L https://github.com/git-chglog/git-chglog/releases/download/v${GIT_CHGLOG_VERSION}/git-chglog_${GIT_CHGLOG_VERSION}_linux_amd64.tar.gz | tar xzf - -C /usr/local/bin git-chglog
RUN chmod +x /usr/local/bin/git-chglog

# Install codecov
RUN curl -o codecov https://codecov.io/bash
RUN curl https://raw.githubusercontent.com/codecov/codecov-bash/master/SHA512SUM | head -n 1 | shasum -a 512 -c
RUN chmod +x codecov && mv codecov /usr/local/bin/

# Install custom scripts
ADD hack/scripts/ /usr/local/bin/

COPY --from=docker /usr/local/bin/docker /usr/local/bin/dockerd /usr/local/bin/
