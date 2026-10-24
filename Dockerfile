# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM golang:1.27.3-alpine AS builder
ARG VERSION=1.104.2
ARG TARGETOS=linux
ARG TARGETARCH=amd64
ENV CGO_ENABLED=0 GOMAXPROCS=2
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH go install -p=2 -trimpath \
      -ldflags="-s -w -X tailscale.com/version.longStamp=${VERSION} -X tailscale.com/version.shortStamp=${VERSION}" \
      tailscale.com/cmd/derper@v${VERSION} \
    && mkdir /out \
    && cp "$(find /go/bin -type f -name derper)" /out/derper \
    && cp /go/pkg/mod/tailscale.com@v${VERSION}/LICENSE /out/LICENSE \
    && go version -m /out/derper > /out/BUILD-INFO.txt

FROM scratch
ARG VERSION=1.104.2
LABEL org.opencontainers.image.title="Tailscale DERP — community packaging" \
      org.opencontainers.image.description="Unmodified official Tailscale derper source in a minimal container; not an official Tailscale image." \
      org.opencontainers.image.source="https://github.com/pengpercy/tailscale-derper" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.licenses="BSD-3-Clause"
COPY --from=builder /out/derper /derper
COPY --from=builder /out/LICENSE /LICENSE
COPY --from=builder /out/BUILD-INFO.txt /BUILD-INFO.txt
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
ENTRYPOINT ["/derper"]
