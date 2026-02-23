---
title: Echo Server (Assembly)
layout: default
---

# Echo Server (Assembly)

A minimal HTTP echo server written in **x86_64** and **ARM64** assembly for Linux. It uses raw Linux syscalls—no libc—and returns a small JSON response with port, unique ID, host, and HTTP method.

---

## Features

| Feature | Description |
|--------|-------------|
| **TCP server** | Socket, bind, listen, accept using Linux syscalls |
| **HTTP/1.1** | Simple request parsing and response |
| **JSON response** | `server_hosting_port`, `server_unique_id`, `host`, `http.method` |
| **Port** | Configurable via command-line argument |
| **Multi-arch** | x86_64 (NASM) and ARM64 (GNU as) with separate sources |
| **Tiny footprint** | Minimal dependencies (Linux kernel only); small binary |

---

## Download binaries

Pre-built Linux binaries are attached to [GitHub Releases](https://github.com/bgarvit01/echoserver-assembly/releases):

| Architecture | Asset | Direct link (latest) |
|--------------|--------|------------------------|
| **Linux x86_64 (amd64)** | `echoserver-linux-amd64` | [Download](https://github.com/bgarvit01/echoserver-assembly/releases/latest/download/echoserver-linux-amd64) |
| **Linux ARM64** | `echoserver-linux-arm64` | [Download](https://github.com/bgarvit01/echoserver-assembly/releases/latest/download/echoserver-linux-arm64) |

After downloading: `chmod +x echoserver-linux-amd64` (or `-arm64`) and run `./echoserver-linux-amd64 8080`.

---

## Quick start

- **[Download binaries](#download-binaries)** — get the pre-built binary for your arch from Releases.
- **[Manual build & run](deployment.html#1-manual-build-and-run)** — build with `make` and run the binary.
- **[Docker](deployment.html#2-docker)** — run with `docker run` or `docker compose`.
- **[Kubernetes](deployment.html#3-kubernetes)** — deploy with `kubectl apply -f k8s/`.

---

## Documentation

| Page | Description |
|------|-------------|
| [Features](features.html) | Full feature list, architecture, limitations, performance |
| [Deployment](deployment.html) | Manual install, Docker, and Kubernetes deployment |

---

## Example response

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

---

## Links

- [GitHub repository](https://github.com/bgarvit01/echoserver-assembly)
- [Releases (binaries + source)](https://github.com/bgarvit01/echoserver-assembly/releases)
- [Docker Hub](https://hub.docker.com/r/garvitbhateja/echoserver-assembly)
