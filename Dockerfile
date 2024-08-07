ARG DOCKER=docker:27.1.1-dind

FROM $DOCKER as docker

FROM alpine:3.20.2 as build-container-drone

# https://github.com/twistedpair/google-cloud-sdk/ is a mirror that replicates the gcloud sdk versions
# renovate: datasource=github-tags depName=twistedpair/google-cloud-sdk
ARG CLOUD_SDK_VERSION=487.0.0
# renovate: datasource=github-releases depName=docker/buildx
ARG BUILDX_VERSION=v0.16.2
# renovate: datasource=github-releases extractVersion=^v(?<version>.*)$ depName=hashicorp/terraform
ARG TERRAFORM_VERSION=1.7.3

# janky janky janky
ENV PATH /google-cloud-sdk/bin:$PATH

RUN apk add --update --no-cache \
  aws-cli \
  bash \
  cargo \
  coreutils \
  crane \
  curl \
  diffoscope \
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
  perl-utils \
  py3-crcmod \
  py3-pip \
  python3 \
  python3-dev \
  qemu-img \
  qemu-system-aarch64 \
  qemu-system-x86_64 \
  rust \
  s3cmd \
  sed \
  socat \
  swtpm \
  tar \
  yq \
  xz \
  zstd

# workaround, install older OVMF version from Alpine 3.18
RUN apk add --no-cache ovmf=0.0.202302-r0 --repository=https://dl-cdn.alpinelinux.org/alpine/v3.18/community

# Install gcloud
RUN curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
  tar xzf google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
  rm google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
  gcloud config set core/disable_usage_reporting true && \
  gcloud config set component_manager/disable_update_check true && \
  gcloud config set metrics/environment github_docker_image

# Install azure
RUN pip3 install azure-cli --break-system-packages

# Required by docker-compose for zlib.
ENV LD_LIBRARY_PATH=/lib:/usr/lib

# Install buildx
RUN curl --create-dirs -Lo /root/.docker/cli-plugins/docker-buildx https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.linux-amd64 \
  && chmod 755 /root/.docker/cli-plugins/docker-buildx

# Install terraform
RUN curl -Lo /tmp/terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
  && unzip /tmp/terraform.zip -d /usr/local/bin \
  && chmod +x /usr/local/bin/terraform \
  && rm /tmp/terraform.zip

# Install codecov
RUN curl -o codecov https://codecov.io/bash
RUN curl https://raw.githubusercontent.com/codecov/codecov-bash/master/SHA512SUM | head -n 1 | shasum -a 512 -c
RUN chmod +x codecov && mv codecov /usr/local/bin/

# Install custom scripts
ADD hack/scripts/ /usr/local/bin/

COPY --from=docker /usr/local/bin/docker /usr/local/bin/dockerd /usr/local/bin/

FROM summerwind/actions-runner-dind:ubuntu-22.04 as build-container-ghaction
# renovate: datasource=github-releases depName=google/go-containerregistry
ARG CRANE_VERSION=v0.20.2
# renovate: datasource=github-releases depName=mikefarah/yq
ARG YQ_VERSION=v4.44.3
# renovate: datasource=github-releases depName=getsops/sops
ARG SOPS_VERSION=v3.9.0
# renovate: datasource=github-tags depName=aws/aws-cli
ARG AWSCLI_VERSION=2.17.24
USER root
RUN apt update && \
	apt upgrade -y && \
	apt install -y \
	--no-install-recommends \
	make \
	tmux \
	qemu-system \
	qemu-utils \
	socat \
	ovmf \
	swtpm \
	iptables \
	iproute2 \
	openssh-client \
	docker.io \
	diffoscope \
	gh \
	zstd

RUN curl -fSL https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 -o /usr/bin/yq && chmod +x /usr/bin/yq
RUN curl -fSL https://github.com/google/go-containerregistry/releases/download/${CRANE_VERSION}/go-containerregistry_Linux_x86_64.tar.gz | tar xzf - -C /usr/local/bin/ crane
RUN curl -fSL https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.amd64 -o /usr/bin/sops && chmod +x /usr/bin/sops
RUN curl -fSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip -o awscliv2.zip && unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws
USER runner
