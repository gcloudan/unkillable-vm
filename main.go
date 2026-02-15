package main

import (
	"crypto/sha256"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"runtime"
	"syscall"
	"time"
)

const (
	TargetMemBytes = 12 * 1024 * 1024 * 1024 // 12GB Physical Anchor
	CPUWorkers     = 2                       // 50% Load (Load Avg ~2.0)
	DownloadURL    = "http://mirror.aarnet.edu.au/pub/rocky/9/isos/aarch64/Rocky-9-latest-aarch64-minimal.iso"
	
	// REPLACE THIS with your actual URL from healthchecks.io
	HealthCheckURL = "https://hc-ping.com/your-uuid-here" 
)

func main() {
	fmt.Println("[System] Initializing Persistent Critical Service...")

	// 1. MEMORY LOCK
	data, err := syscall.Mmap(-1, 0, TargetMemBytes, syscall.PROT_READ|syscall.PROT_WRITE, syscall.MAP_ANON|syscall.MAP_PRIVATE|syscall.MAP_POPULATE)
	if err != nil {
		fmt.Printf("[Error] Mem Lock Failed: %v\n", err)
		return
	}
	fmt.Println("[Success] Physical RAM Locked.")

	// 2. CPU WORKERS (Saturates Load Average)
	for i := 0; i < CPUWorkers; i++ {
		go func(id int) {
			fmt.Printf("[CPU] Worker %d Online\n", id)
			h := sha256.New()
			r := rand.New(rand.NewSource(time.Now().UnixNano()))
			for {
				idx := r.Intn(TargetMemBytes - 65536)
				h.Write(data[idx : idx+65536])
				h.Sum(nil)
				h.Reset()
				time.Sleep(50 * time.Microsecond)
			}
		}(i)
	}

	// 3. NETWORK PULSE + HEALTHCHECK PING
	go func() {
		client := &http.Client{Timeout: 30 * time.Second}
		for {
			// A. Send Ping to Healthchecks.io (The "Dead Man's Switch")
			fmt.Println("[Alert] Sending Heartbeat Ping...")
			client.Get(HealthCheckURL)

			// B. Wait 3-6 minutes
			time.Sleep(time.Duration(180+rand.Intn(180)) * time.Second)

			// C. Run the AARNet Mirror Pulse (The "Network Requirement")
			fmt.Println("[Net] Starting Sync Pulse (100MB)...")
			resp, err := client.Get(DownloadURL)
			if err == nil {
				io.CopyN(io.Discard, resp.Body, 100*1024*1024)
				resp.Body.Close()
				fmt.Println("[Net] Pulse Complete.")
			}
		}
	}()

	runtime.KeepAlive(data)
	select {}
}
