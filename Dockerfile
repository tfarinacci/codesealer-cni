# Step 1: Build the CNI plugin using a Go builder image
FROM golang:1.19 as builder

# Set the working directory inside the container
WORKDIR /go/src/codesealer-cni

# Copy the Go source code into the container
COPY ./cmd/cni/ .

# Disable CGO and set the OS to Linux
# Build the Go code with Go 1.19
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o codesealer-cni .

# Step 2: Create a minimal runtime image
FROM alpine:latest

# Install iptables in the runtime image
RUN apk --no-cache add iptables

# Copy the compiled binary from the builder stage
COPY --from=builder /go/src/codesealer-cni/codesealer-cni /usr/local/bin/codesealer-cni

# Set the entrypoint to your CNI plugin
ENTRYPOINT ["/usr/local/bin/codesealer-cni"]

# Set necessary capabilities for iptables manipulation
# Note: This might not be needed if the container runs as root, but it's a good practice
CMD ["setcap", "cap_net_admin=eip", "/usr/local/bin/codesealer-cni"]
