| Component | Technology | Rationale |
| --- | --- | --- |
| **Language** | Go (Golang) | Low overhead, native binary, high-performance concurrency. |
| **Memory Management** | `syscall.Mmap` | Forces physical hardware allocation (RSS) instead of virtual. |
| **CPU Saturation** | `crypto/sha256` | Computationally expensive hashing to maintain Load Average. |
| **Service Manager** | `systemd` | Ensures auto-restart and protects against OOM Killer. |
| **Network Mirror** | AARNet (Melbourne) | High-trust local Australian traffic to avoid detection. |
| **External Monitor** | Healthchecks.io | "Dead Man's Switch" for external alerting. |
