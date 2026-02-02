package main

import (
    "encoding/json"
    "log"
    "net"
    "net/http"
    "os"
    "time"
)

type HealthResponse struct {
    Status   string `json:"status"`
    IP       string `json:"ip"`
    DateTime string `json:"dateTime"`
}

func getPodIP() string {
    // 1️⃣ пробуем из переменной окружения (лучший вариант)
    if ip := os.Getenv("POD_IP"); ip != "" {
	return ip
    }

    // 2️⃣ fallback — первый не loopback IP
    addrs, err := net.InterfaceAddrs()
    if err != nil {
	return "unknown"
    }

    for _, addr := range addrs {
	if ipNet, ok := addr.(*net.IPNet); ok {
	    if !ipNet.IP.IsLoopback() && ipNet.IP.To4() != nil {
		return ipNet.IP.String()
	    }
	}
    }

    return "unknown"
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")

    resp := HealthResponse{
	Status:   "OK",
	IP:       getPodIP(),
	DateTime: time.Now().Format(time.RFC3339),
    }

    json.NewEncoder(w).Encode(resp)
}

func main() {
    http.HandleFunc("/health", healthHandler)

    log.Println("Starting server on :8000")
    log.Fatal(http.ListenAndServe(":8000", nil))
}