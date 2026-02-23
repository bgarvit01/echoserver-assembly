---
title: Deployment
layout: default
---

# Deployment

You can run the Assembly Echo Server in three ways: **manual build and run**, **Docker**, or **Kubernetes**.

---

## 1. Manual build and run

You can **download a pre-built binary** from GitHub Releases or **build from source** on a Linux machine (x86_64 or ARM64).

### Option A: Download pre-built binary (no build tools needed)

Binaries are published on [GitHub Releases](https://github.com/bgarvit01/echoserver-assembly/releases). Use the latest release or the direct links below 

| Architecture | Direct link (latest) |
|--------------|----------------------|
| **Linux x86_64 (amd64)** | [echoserver-linux-amd64](https://github.com/bgarvit01/echoserver-assembly/releases/latest/download/echoserver-linux-amd64) |
| **Linux ARM64** | [echoserver-linux-arm64](https://github.com/bgarvit01/echoserver-assembly/releases/latest/download/echoserver-linux-arm64) |

```bash
# Linux x86_64
curl -L -o echoserver https://github.com/bgarvit01/echoserver-assembly/releases/latest/download/echoserver-linux-amd64
chmod +x echoserver
./echoserver 8080

# Linux ARM64
curl -L -o echoserver https://github.com/bgarvit01/echoserver-assembly/releases/latest/download/echoserver-linux-arm64
chmod +x echoserver
./echoserver 8080
```

### Option B: Build from source

### Requirements

- **Platform**: Linux (x86_64 or ARM64)
- **x86_64**: NASM and `ld` (GNU linker)
- **ARM64**: GNU `as` and `ld`

### Install build tools

**x86_64 (NASM):**

```bash
# Ubuntu/Debian
sudo apt-get install nasm binutils

# Fedora/RHEL
sudo dnf install nasm binutils

# Arch Linux
sudo pacman -S nasm binutils
```

**ARM64 (GNU as):**

```bash
# Ubuntu/Debian / Fedora / Arch
sudo apt-get install binutils   # or dnf/pacman
```

### Build

```bash
# Clone the repo (or use your copy)
git clone https://github.com/YOUR_USERNAME/echoserver-assembly.git
cd echoserver-assembly

# Build for current architecture
make

# Optional: build both architectures (Linux)
make both
```

This produces `echoserver` (a symlink to `echoserver_x86` or `echoserver_arm64`).

### Run

```bash
# Default port 8080
./echoserver

# Custom port
./echoserver 3000
```

### Optional: install to system

```bash
# Copy binary to a PATH directory (e.g. /usr/local/bin)
sudo cp echoserver /usr/local/bin/echoserver-assembly
sudo chmod +x /usr/local/bin/echoserver-assembly

# Run from anywhere
echoserver-assembly 8080
```

### Troubleshooting (manual)

- **Permission denied**: `chmod +x echoserver`
- **Cannot bind to port 80**: Use a port ≥ 1024 or run as root (not recommended).
- **Segmentation fault**: Ensure you’re on the correct architecture (x86_64 or ARM64 Linux).

---

## 2. Docker

Run the server as a container using Docker or Docker Compose. Images are multi-arch (linux/amd64 and linux/arm64).

### Option A: Pre-built image from Docker Hub


```bash
# Pull and run (port 8080 on host)
docker run -d -p 8080:8080 --name echoserver garvitbhateja/echoserver-assembly:latest

# Test
curl http://localhost:8080/

# Stop and remove
docker stop echoserver && docker rm echoserver
```

### Option B: Build and run with Docker Compose

Use the repo’s `docker-compose.yml` to build and run locally:

```bash
git clone https://github.com/YOUR_USERNAME/echoserver-assembly.git
cd echoserver-assembly

# Build and start (server on host port 8082)
docker compose up -d

# Test
curl http://localhost:8082/

# View logs
docker compose logs -f

# Stop
docker compose down
```

### Option C: Build image yourself

```bash
# x86_64
docker build -t echoserver-assembly:latest .

# ARM64 (e.g. Apple Silicon)
docker build -f Dockerfile.arm64 -t echoserver-assembly:latest .

# Run
docker run -d -p 8080:8080 echoserver-assembly:latest
```

### Docker summary

| Method | Command | Host port |
|--------|--------|-----------|
| Pre-built image | `docker run -p 8080:8080 USER/echoserver-assembly:latest` | 8080 |
| Docker Compose | `docker compose up -d` | 8082 |

---

## 3. Kubernetes

Deploy the server as a Kubernetes Deployment with a Service using the manifests in the `k8s/` directory.

### Prerequisites

- `kubectl` configured for your cluster
- Cluster can pull the image (e.g. from Docker Hub or a private registry)

### Deploy

**Step 1:** Set the image in the Deployment to your image (edit `k8s/deployment.yaml` or override with `kubectl`).

```bash
# Clone repo
git clone https://github.com/YOUR_USERNAME/echoserver-assembly.git
cd echoserver-assembly
```

Edit `k8s/deployment.yaml` and set the container image, for example:

```yaml
image: YOUR_DOCKERHUB_USER/echoserver-assembly:latest
```

**Step 2:** Apply the manifests.

```bash
kubectl apply -f k8s/
```

This creates:

- **Deployment** `echoserver-assembly` (2 replicas by default) with:
  - HTTP liveness and readiness probes on port 8080
  - Small CPU/memory requests and limits
- **Service** `echoserver-assembly` (ClusterIP) on port 8080

### Override image without editing the file

```bash
kubectl apply -f k8s/deployment.yaml
kubectl set image deployment/echoserver-assembly echoserver=YOUR_DOCKERHUB_USER/echoserver-assembly:latest
kubectl apply -f k8s/service.yaml
```

### Check status

```bash
kubectl get pods -l app=echoserver-assembly
kubectl get svc echoserver-assembly
```

### Access the service

- **Inside the cluster**: `http://echoserver-assembly:8080/` (from another pod in the same namespace).
- **From outside**: Add an Ingress or change the Service to type LoadBalancer/NodePort and use the external address or node port.

### Scale

```bash
kubectl scale deployment/echoserver-assembly --replicas=5
```

### Remove

```bash
kubectl delete -f k8s/
```

---

## Summary

| Method | Use case |
|--------|----------|
| **Manual** | Development, learning, or running on a single Linux server |
| **Docker** | Local or server runs without installing build tools; same image on amd64/arm64 |
| **Kubernetes** | Production-style deployment with replicas, probes, and service discovery |

[Back to home](index.html) · [Features](features.html)
