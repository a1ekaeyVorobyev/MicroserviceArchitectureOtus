package main

import (
    "fmt"
    "log"
    "math/rand"
    "net/http"
    "strconv"
    "time"

    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    httpRequestsTotal = promauto.NewCounterVec(
	prometheus.CounterOpts{
	    Name: "http_requests_total",
	    Help: "Total HTTP requests",
	},
	[]string{"method", "endpoint", "status"},
    )

    // ИСПРАВЛЕННАЯ гистограмма с bucket-ами для квантилей
    httpRequestDurationSeconds = promauto.NewHistogramVec(
	prometheus.HistogramOpts{
	    Name:    "http_request_duration_seconds",
	    Help:    "HTTP request duration in seconds",
	    Buckets: prometheus.DefBuckets, // Используем стандартные bucket-ы: [.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10]
	},
	[]string{"method", "endpoint"},
    )

    // Альтернативно можно задать свои bucket-ы:
    // Buckets: []float64{0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2, 5},
)

// Middleware для отслеживания метрик
func metricsMiddleware(next http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
	start := time.Now()

	// Создаем ResponseWriter для перехвата статуса
	rw := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}

	next(rw, r)

	duration := time.Since(start).Seconds()

	// Записываем метрики
	httpRequestsTotal.WithLabelValues(r.Method, r.URL.Path, strconv.Itoa(rw.statusCode)).Inc()
	httpRequestDurationSeconds.WithLabelValues(r.Method, r.URL.Path).Observe(duration)
    }
}

type responseWriter struct {
    http.ResponseWriter
    statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
    rw.statusCode = code
    rw.ResponseWriter.WriteHeader(code)
}

func apiHandler(w http.ResponseWriter, r *http.Request) {
    // Параметры для тестирования
    delayParam := r.URL.Query().Get("delay")
    errorParam := r.URL.Query().Get("error")

    // Задержка
    var delay time.Duration
    if delayParam != "" {
	if ms, err := strconv.Atoi(delayParam); err == nil {
	    delay = time.Duration(ms) * time.Millisecond
	}
    } else {
	delay = time.Duration(rand.Intn(300)) * time.Millisecond
    }

    time.Sleep(delay)

    // Статус ответа
    status := http.StatusOK

    // Принудительная ошибка через параметр
    if errorParam == "true" || r.URL.Path == "/api/force-error" {
	status = http.StatusInternalServerError
    } else if rand.Intn(100) < 5 { // 5% случайных ошибок
	if rand.Intn(2) == 0 {
	    status = http.StatusInternalServerError
	} else {
	    status = http.StatusBadRequest
	}
    }

    // Ответ
    if status >= 400 {
	http.Error(w, fmt.Sprintf(`{"error": "Something went wrong", "path": "%s"}`, r.URL.Path), status)
    } else {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	fmt.Fprintf(w, `{"path": "%s", "delay_ms": %d, "status": %d}`,
	    r.URL.Path, delay.Milliseconds(), status)
    }
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK)
    w.Write([]byte(`{"status": "healthy", "timestamp": "` + time.Now().Format(time.RFC3339) + `"}`))
}

func main() {
    rand.Seed(time.Now().UnixNano())

    // API endpoints с middleware
    http.HandleFunc("/api/", metricsMiddleware(apiHandler))
    http.HandleFunc("/api/users", metricsMiddleware(apiHandler))
    http.HandleFunc("/api/orders", metricsMiddleware(apiHandler))
    http.HandleFunc("/api/products", metricsMiddleware(apiHandler))
    http.HandleFunc("/api/test", metricsMiddleware(apiHandler))
    http.HandleFunc("/api/force-error", metricsMiddleware(apiHandler))

    http.HandleFunc("/health", healthHandler)
    http.Handle("/metrics", promhttp.Handler())

    // Статические файлы
    fs := http.FileServer(http.Dir("./static"))
    http.Handle("/static/", http.StripPrefix("/static/", fs))

    // Главная страница
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
	    http.ServeFile(w, r, "./static"+r.URL.Path)
	    return
	}
	http.ServeFile(w, r, "./static/index.html")
    })

    port := ":8080"
    log.Printf("🚀 Server starting on http://localhost%s", port)
    log.Printf("📊 Metrics: http://localhost%s/metrics", port)
    
    log.Fatal(http.ListenAndServe(port, nil))
}