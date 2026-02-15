### **The Oracle Defender**

**Goal:** Prevent OCI "Always Free" reclamation by maintaining >20% utilization in CPU, RAM, and Network via legitimate-looking local activity.

### **Usage Commands**

To check if the defender is alive:
`systemctl status defender`

To view live activity:
`journalctl -u defender -f`

To update after code changes (The "One-Liner"):
`go build -o /usr/bin/defender main.go && chmod +x /usr/bin/defender && restorecon -v /usr/bin/defender && systemctl restart defender`

### **The Rationale**

1. **RAM:** Oracle reclaims A1 shapes if RAM usage is below 20%. We lock **12GB (~55%)** using a memory anchor.
2. **CPU:** We hash data in loops to keep the **Load Average ~2.0**. This signals a "Production Workload" to the hypervisor.
3. **Network:** We pulse **100MB downloads** from AARNet every few minutes to maintain the **95th percentile** network metric without abusing the 10TB cap.
