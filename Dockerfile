# Dockerfile for Assembly Echo Server (x86_64)
# Build with: docker buildx build --platform linux/amd64 -f Dockerfile .

ARG TARGETPLATFORM
FROM --platform=$TARGETPLATFORM debian:bookworm-slim AS builder

# Install NASM and build tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    nasm \
    binutils \
    make \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy source files
COPY echoserver.asm Makefile ./

# Build the server
RUN make

# Runtime stage - minimal image
FROM --platform=$TARGETPLATFORM debian:bookworm-slim

WORKDIR /app

# Copy the binary from builder
COPY --from=builder /app/echoserver .

# Default port
EXPOSE 8080

# Run the server
ENTRYPOINT ["./echoserver"]
CMD ["8080"]
