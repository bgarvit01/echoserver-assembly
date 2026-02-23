# Assembly Echo Server

A minimal HTTP echo server written in x86_64 assembly language for Linux.

## Features

- TCP socket server using Linux syscalls
- HTTP/1.1 request handling
- JSON response with:
  - `server_hosting_port` - The port the server is running on
  - `server_unique_id` - Unique identifier (PID + timestamp based)
  - `host` - Basic host information
  - `http.method` - The HTTP method used
- Configurable port via command line argument
- Minimal dependencies (just Linux kernel)

## Requirements

- **Platform**: Linux (x86_64 or ARM64)
- **x86_64**: NASM (Netwide Assembler) and ld (GNU linker)
- **ARM64**: GNU as and ld

## Download binaries (GitHub Releases)

Pre-built Linux binaries are published on [GitHub Releases](https://github.com/bgarvit01/echoserver-assembly/releases). Each release includes:

| Architecture | Asset | Direct link (latest) |
|--------------|--------|------------------------|
| **Linux x86_64 (amd64)** | `echoserver-linux-amd64` | [Download](https://github.com/bgarvit01/echoserver-assembly/releases/latest/download/echoserver-linux-amd64) |
| **Linux ARM64** | `echoserver-linux-arm64` | [Download](https://github.com/bgarvit01/echoserver-assembly/releases/latest/download/echoserver-linux-arm64) |

```bash
# Example: download and run on Linux x86_64
curl -L -o echoserver https://github.com/bgarvit01/echoserver-assembly/releases/latest/download/echoserver-linux-amd64
chmod +x echoserver
./echoserver 8080
```

Binaries are built by [Release binaries](.github/workflows/release-binaries.yml) when you push a version tag (e.g. `v1.0.0`).

## Building from source

### Install build tools

```bash
# Ubuntu/Debian (x86_64: NASM + binutils; ARM64: binutils; both: add gcc-aarch64-linux-gnu for cross-build)
sudo apt-get install nasm binutils

# Fedora/RHEL
sudo dnf install nasm binutils

# Arch Linux
sudo pacman -S nasm binutils
```

### Build

```bash
# Build for current architecture
make

# Or manually (x86_64):
nasm -f elf64 echoserver.asm -o echoserver.o
ld echoserver.o -o echoserver
```

## Usage

```bash
# Run on default port 8080
./echoserver

# Run on custom port
./echoserver 3000
```

## Example Response

```json
{
  "server_hosting_port": 8080,
  "server_unique_id": "asm-0000000000001234-0000000065d12345",
  "host": {
    "hostname": "asm-echoserver"
  },
  "http": {
    "method": "GET"
  }
}
```

## Performance

Benchmark results (1000 requests, concurrency 10, server in Docker on Linux):

| Metric | Value |
|--------|-------|
| Total requests | 1000 |
| Successful | 1000 |
| Failed | 0 |
| Total time | 0.438 sec |
| **Requests/sec** | **2284.62** |
| Latency (min) | 1.417 ms |
| Latency (max) | 21.963 ms |
| Latency (avg) | 4.345 ms |
| Latency (median) | 4.133 ms |
| Latency (P95) | 6.19 ms |
| Latency (P99) | 18.842 ms |

Single-threaded; throughput will vary with concurrency and network. To reproduce: `docker compose up -d` then run HTTP requests against `http://localhost:8082/`.

## Docker

Pre-built images are published to Docker Hub as **`echoserver-assembly`** with multi-arch support (linux/amd64 and linux/arm64), so the same image works on x86_64, ARM64, and Apple Silicon:

```bash
docker run -p 8080:8080 garvitbhateja/echoserver-assembly:latest
```

Or use docker-compose from this repo (builds locally):

```bash
docker compose up -d
# Server on http://localhost:8080
```

### Kubernetes

Manifests in `k8s/` deploy the echoserver as a Deployment with a ClusterIP Service:

```bash
kubectl apply -f k8s/

# Or apply both separately
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

- **Deployment**: 2 replicas, small CPU/memory requests and limits, HTTP liveness and readiness probes on port 8080.
- **Service**: ClusterIP on port 8080; use an Ingress or LoadBalancer in front if you need external access.


## Architecture

The assembly server uses direct Linux syscalls:

- `socket()` - Create TCP socket
- `setsockopt()` - Set socket options (SO_REUSEADDR)
- `bind()` - Bind to address
- `listen()` - Listen for connections
- `accept()` - Accept connections
- `read()` - Read HTTP request
- `write()` - Send HTTP response
- `close()` - Close connection
- `getpid()` - Get process ID (for unique ID)
- `time()` - Get timestamp (for unique ID)

## Limitations

1. **Simplified JSON** - Minimal set of response fields
2. **No HTTPS/TLS** - Plain HTTP only
3. **No HTTP/2** - HTTP/1.1 only

## Why Assembly?

This is primarily an educational exercise to demonstrate:

1. How HTTP servers work at the lowest level
2. Direct system call interface with the kernel
3. Memory-efficient server implementation
4. Performance characteristics of compiled vs interpreted code

## Troubleshooting

### "Permission denied" when running
```bash
chmod +x echoserver
```

### "Cannot bind to port 80"
Ports below 1024 require root privileges. Use a higher port number:
```bash
./echoserver 8080
```

### Segmentation fault
Ensure you're running on x86_64 Linux. The assembly code uses Linux-specific syscalls and x86_64 calling conventions.

## Documentation (GitHub Pages)

Site URL: `https://bgarvit01.github.io/echoserver-assembly/`

## Files

- `echoserver.asm` - Main assembly source code (x86_64)
- `echoserver_arm64.asm` - ARM64 assembly source
- `Makefile` - Build configuration
- `k8s/deployment.yaml` - Kubernetes Deployment
- `k8s/service.yaml` - Kubernetes Service
- `docs/` - GitHub Pages documentation (index, features, deployment)
- `LICENSE` - MIT License
- `README.md` - This file
