FROM alpine:3.9
RUN apk add --update --no-cache make musl-dev bash curl git jq

RUN curl --create-dirs -Lo /root/.docker/cli-plugins/docker-buildx https://github.com/docker/buildx/releases/download/v0.3.0/buildx-v0.3.0.linux-amd64 \
    && chmod 755 /root/.docker/cli-plugins/docker-buildx

RUN curl --create-dirs -Lo /usr/local/bin/gitmeta https://github.com/talos-systems/gitmeta/releases/download/v0.1.0-alpha.2/gitmeta-linux-amd64 \
    && chmod 755 /usr/local/bin/gitmeta

RUN curl -o /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub \
    && curl -LO https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.29-r0/glibc-2.29-r0.apk \
    && apk add glibc-2.29-r0.apk \
    && rm glibc-2.29-r0.apk

# Required by docker-compose for zlib.
ENV LD_LIBRARY_PATH=/lib:/usr/lib

COPY --from=docker/compose:1.24.1 /usr/local/bin/docker-compose /usr/local/bin/
COPY --from=docker:19.03.1 /usr/local/bin/docker /usr/local/bin/dockerd /usr/local/bin/
COPY --from=moby/buildkit:v0.6.1 /usr/bin/buildctl /usr/local/bin/
COPY --from=autonomy/bldr:946e61b-scratch /bldr /usr/local/bin/
