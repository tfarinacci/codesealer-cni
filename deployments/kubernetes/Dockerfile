FROM golang:latest as go-builder

ENV GO111MODULE=on
ENV CGO_ENABLED=0

WORKDIR /

COPY . .

RUN GO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o codesealer-cni ./cmd/codesealer-cni/main.go
RUN GO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o codesealer-install-cni ./cmd/codesealer-install-cni/main.go

FROM alpine:latest
# FROM scratch

WORKDIR /

LABEL description="Codesealer CNI plugin installer."

ARG TARGETARCH
COPY --from=go-builder /codesealer-cni /opt/cni/bin/codesealer-cni
COPY --from=go-builder /codesealer-install-cni /usr/local/bin/codesealer-install-cni

RUN chmod a+x /opt/cni/bin/codesealer-cni
RUN chmod a+x /usr/local/bin/codesealer-install-cni

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/cni/bin
WORKDIR /opt/cni/bin
CMD ["/usr/local/bin/codesealer-install-cni"]