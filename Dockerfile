FROM alpine:3.9
RUN apk add --update make docker go musl-dev bash curl git jq
RUN go get github.com/talos-systems/gitmeta \
    && mv /root/go/bin/gitmeta /usr/local/bin/
RUN curl -o /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub \
    && curl -LO https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.29-r0/glibc-2.29-r0.apk \
    && apk add glibc-2.29-r0.apk \
    && rm glibc-2.29-r0.apk
# Required by docker-compose for zlib.
ENV LD_LIBRARY_PATH=/lib:/usr/lib
COPY --from=docker/compose:1.23.2 /usr/local/bin/docker-compose /usr/local/bin/
COPY --from=docker:18.09.4 /usr/local/bin/docker /usr/local/bin/
COPY --from=moby/buildkit:v0.3.3 /usr/bin/buildctl /usr/local/bin/
