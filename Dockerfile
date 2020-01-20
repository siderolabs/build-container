ARG DOCKER_COMPOSE=docker/compose:1.24.1
ARG DOCKER=docker:19.03.1
ARG BUILDKIT=moby/buildkit:v0.6.1
ARG GOLANG=golang:1.13.6-alpine

FROM $DOCKER_COMPOSE as docker_compose
FROM $DOCKER as docker
FROM $BUILDKIT as buildkit

FROM $GOLANG as tc-redirect-tap

ENV FIRECRACKER_SDK_VERSION=v0.19.0

WORKDIR /src

RUN apk add --update --no-cache \
  curl \
  make

RUN curl -LO https://github.com/firecracker-microvm/firecracker-go-sdk/archive/${FIRECRACKER_SDK_VERSION}.tar.gz
RUN tar xzf ${FIRECRACKER_SDK_VERSION}.tar.gz --strip-components=1
RUN make -C cni install

FROM alpine:3.9

ENV BUILDX_VERSION=v0.3.0
ENV GITMETA_VERSION=v0.1.0-alpha.3
ENV CLOUD_SDK_VERSION=258.0.0
ENV CNI_PLUGINS_VERSION=v0.8.4

# janky janky janky
ENV PATH /google-cloud-sdk/bin:$PATH

RUN apk add --update --no-cache \
  bash \
  curl \
  gcc \
  git \
  gnupg \
  jq \
  libc6-compat \
  libffi-dev \
  make \
  musl-dev \
  openssh-client \
  openssl-dev \
  py-crcmod \
  py-pip \
  python2 \
  python2-dev

# Install docker buildx
ADD buildx/bin/buildx /root/.docker/cli-plugins/docker-buildx
RUN chmod 755 /root/.docker/cli-plugins/docker-buildx

# Install gitmeta
RUN curl --create-dirs -Lo /usr/local/bin/gitmeta https://github.com/talos-systems/gitmeta/releases/download/${GITMETA_VERSION}/gitmeta-linux-amd64 \
  && chmod 755 /usr/local/bin/gitmeta

# Install gcloud
RUN curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
  tar xzf google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
  rm google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
  gcloud config set core/disable_usage_reporting true && \
  gcloud config set component_manager/disable_update_check true && \
  gcloud config set metrics/environment github_docker_image

# Install aws
RUN pip install awscli s3cmd

# Install azure
RUN pip install azure-cli

# Install CNI
RUN mkdir -p /opt/cni/bin /etc/cni/conf.d /var/lib/cni
RUN curl -LO https://github.com/containernetworking/plugins/releases/download/v0.8.4/cni-plugins-linux-amd64-${CNI_PLUGINS_VERSION}.tgz && \
  tar xzf cni-plugins-linux-amd64-${CNI_PLUGINS_VERSION}.tgz  -C /opt/cni/bin && \
  rm cni-plugins-linux-amd64-${CNI_PLUGINS_VERSION}.tgz

# Install firecracker
ADD firecracker/build/cargo_target/x86_64-unknown-linux-musl/debug/firecracker /usr/bin/firecracker

# Required by docker-compose for zlib.
ENV LD_LIBRARY_PATH=/lib:/usr/lib

COPY --from=docker_compose /usr/local/bin/docker-compose /usr/local/bin/
COPY --from=docker /usr/local/bin/docker /usr/local/bin/dockerd /usr/local/bin/
COPY --from=buildkit /usr/bin/buildctl /usr/local/bin/
COPY --from=tc-redirect-tap /opt/cni/bin/tc-redirect-tap /opt/cni/bin/
