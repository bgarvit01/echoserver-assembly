---
title: Features
layout: default
---

# Features

## Overview

The Assembly Echo Server is a minimal HTTP server implemented in assembly language for Linux. It supports both **x86_64** (NASM) and **ARM64** (GNU as) with separate source files.

---

## Feature list

| Feature | Description |
|--------|-------------|
| **TCP socket server** | Uses Linux syscalls: `socket()`, `setsockopt()`, `bind()`, `listen()`, `accept()` |
| **HTTP/1.1** | Parses the request line and returns a valid HTTP response |
| **JSON response** | Includes `server_hosting_port`, `server_unique_id`, `host`, and `http.method` |
| **Configurable port** | Pass port as command-line argument (e.g. `./echoserver 3000`) |
| **Unique ID** | Per-response ID built from PID and timestamp |
| **Multi-architecture** | x86_64 (`echoserver.asm`) and ARM64 (`echoserver_arm64.asm`) |
| **Minimal dependencies** | No libc; only the Linux kernel |
| **Small binary** | Low memory and disk footprint |

---

## Architecture (syscalls)

- `socket()` — create TCP socket  
- `setsockopt()` — set SO_REUSEADDR  
- `bind()` — bind to address  
- `listen()` — listen for connections  
- `accept()` — accept a connection  
- `read()` — read HTTP request  
- `write()` — send HTTP response  
- `close()` — close connection  
- `getpid()` — process ID for unique ID  
- `time()` — timestamp for unique ID  

---

## Performance (reference)

Benchmark: 1000 requests, concurrency 10, server in Docker.

| Metric | Value |
|--------|-------|
| Requests/sec | **2284.62** |
| Latency (avg) | 4.345 ms |
| Latency (median) | 4.133 ms |
| Latency (P95) | 6.19 ms |
| Latency (P99) | 18.842 ms |

Single-threaded; throughput depends on concurrency and load.

---

## Limitations

1. **Linux only** — Uses Linux-specific syscalls (x86_64 or ARM64).
2. **Simplified JSON** — Small, fixed set of response fields.
3. **No HTTPS/TLS** — Plain HTTP only.
4. **No HTTP/2** — HTTP/1.1 only.
5. **Single-threaded** — One connection at a time.
6. **Limited error handling** — Basic handling only.
7. **No config file** — Port and behavior via command line only.

---

## Why assembly?

- Shows how HTTP servers work at a low level.  
- Uses the kernel’s system-call interface directly.  
- Keeps the server small and memory-efficient.  
- Useful for learning and experimentation.

[Back to home](index.html) · [Deployment options](deployment.html)
