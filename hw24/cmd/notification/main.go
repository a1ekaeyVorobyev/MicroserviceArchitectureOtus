package main

import (
    "database/sql"
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
    "time"

    _ "github.com/lib/pq"
)

type Notification struct {
    ID        int       `json:"id"`
    UserID    string    `json:"user_id"`
    Email     string    `json:"email"`
    Message   string    `json:"message"`
    CreatedAt time.Time `json:"created_at"`
    Status    string    `json:"status"`
}

var db *sql.DB

func initDB() {
    // Получаем параметры подключения из переменных окружения
    host := getEnv("DB_HOST", "postgres-notification")
    port := getEnv("DB_PORT", "5432")
    user := getEnv("DB_USER", "notification_user")
    password := getEnv("DB_PASSWORD", "notification_password")
    dbname := getEnv("DB_NAME", "notifications")

    connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable connect_timeout=10",
        host, port, user, password, dbname)

    log.Printf("🔄 Подключение к PostgreSQL: %s:%s/%s", host, port, dbname)

    var err error
    db, err = sql.Open("postgres", connStr)
    if err != nil {
        log.Fatal("❌ Ошибка подключения к БД:", err)
    }

    // Настраиваем пул соединений
    db.SetMaxOpenConns(25)
    db.SetMaxIdleConns(5)
    db.SetConnMaxLifetime(5 * time.Minute)

    // Проверяем подключение с повторными попытками
    var pingErr error
    for i := 1; i <= 5; i++ {
        pingErr = db.Ping()
        if pingErr == nil {
            break
        }
        log.Printf("⚠️  Попытка %d/5: не удалось подключиться к БД: %v", i, pingErr)
        time.Sleep(time.Duration(i*2) * time.Second)
    }

    if pingErr != nil {
        log.Fatal("❌ Не удалось подключиться к БД после 5 попыток:", pingErr)
    }

    // Создаем таблицу, если её нет
    createTableSQL := `
    CREATE TABLE IF NOT EXISTS notifications (
        id SERIAL PRIMARY KEY,
        user_id VARCHAR(50) NOT NULL,
        email VARCHAR(255) NOT NULL,
        message TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        status VARCHAR(20) DEFAULT 'sent'
    );
    CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
    `
    
    _, err = db.Exec(createTableSQL)
    if err != nil {
        log.Printf("⚠️ Ошибка создания таблицы: %v", err)
    } else {
        log.Println("✅ Таблица notifications готова")
    }

    log.Println("✅ Успешное подключение к PostgreSQL")
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}

func createNotification(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }

    var notification Notification
    if err := json.NewDecoder(r.Body).Decode(&notification); err != nil {
        log.Printf("❌ Ошибка декодирования запроса: %v", err)
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }

    log.Printf("📝 Попытка сохранить уведомление: UserID=%s, Message=%s", notification.UserID, notification.Message)

    // Проверяем подключение перед запросом
    if err := db.Ping(); err != nil {
        log.Printf("❌ Потеряно подключение к БД, переподключаемся: %v", err)
        initDB()
    }

    // Сохраняем в PostgreSQL
    var id int
    var createdAt time.Time

    err := db.QueryRow(`
        INSERT INTO notifications (user_id, email, message, status, created_at)
        VALUES ($1, $2, $3, 'sent', NOW())
        RETURNING id, created_at`,
        notification.UserID, notification.Email, notification.Message,
    ).Scan(&id, &createdAt)

    if err != nil {
        log.Printf("❌ Ошибка сохранения в БД: %v", err)
        
        // Пробуем еще раз через секунду
        time.Sleep(1 * time.Second)
        err = db.QueryRow(`
            INSERT INTO notifications (user_id, email, message, status, created_at)
            VALUES ($1, $2, $3, 'sent', NOW())
            RETURNING id, created_at`,
            notification.UserID, notification.Email, notification.Message,
        ).Scan(&id, &createdAt)
        
        if err != nil {
            log.Printf("❌ Повторная ошибка сохранения в БД: %v", err)
            http.Error(w, "Database error: "+err.Error(), http.StatusInternalServerError)
            return
        }
    }

    notification.ID = id
    notification.CreatedAt = createdAt
    notification.Status = "sent"

    log.Printf("✅ Уведомление успешно сохранено в БД: ID=%d, UserID=%s", id, notification.UserID)

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(notification)
}

func getNotifications(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodGet {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }

    userID := r.URL.Query().Get("user_id")

    // Проверяем подключение
    if err := db.Ping(); err != nil {
        log.Printf("❌ Потеряно подключение к БД: %v", err)
        http.Error(w, "Database connection lost", http.StatusInternalServerError)
        return
    }

    var rows *sql.Rows
    var err error

    if userID != "" {
        // Получаем уведомления конкретного пользователя
        rows, err = db.Query(`
            SELECT id, user_id, email, message, created_at, status
            FROM notifications
            WHERE user_id = $1
            ORDER BY created_at DESC`,
            userID)
        log.Printf("📖 Запрос к БД: уведомления для пользователя %s", userID)
    } else {
        // Получаем все уведомления
        rows, err = db.Query(`
            SELECT id, user_id, email, message, created_at, status
            FROM notifications
            ORDER BY created_at DESC`)
        log.Printf("📖 Запрос к БД: все уведомления")
    }

    if err != nil {
        log.Printf("❌ Ошибка запроса к БД: %v", err)
        http.Error(w, "Database error", http.StatusInternalServerError)
        return
    }
    defer rows.Close()

    var notifications []Notification
    for rows.Next() {
        var n Notification
        err := rows.Scan(&n.ID, &n.UserID, &n.Email, &n.Message, &n.CreatedAt, &n.Status)
        if err != nil {
            log.Printf("❌ Ошибка сканирования: %v", err)
            continue
        }
        notifications = append(notifications, n)
    }

    log.Printf("📊 Найдено %d уведомлений", len(notifications))

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(notifications)
}

func health(w http.ResponseWriter, r *http.Request) {
    // Проверяем подключение к БД
    err := db.Ping()
    status := "ok"
    dbStatus := "connected"
    if err != nil {
        status = "degraded"
        dbStatus = "disconnected"
        log.Printf("⚠️ Проблема с подключением к БД: %v", err)
    }

    // Получаем количество записей для информации
    var count int
    countErr := db.QueryRow("SELECT COUNT(*) FROM notifications").Scan(&count)
    if countErr != nil {
        log.Printf("⚠️ Не удалось получить количество записей: %v", countErr)
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "service":         "notification",
        "status":          status,
        "database":        dbStatus,
        "records_count":   count,
    })
}

func testDB(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodGet {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }

    log.Println("🧪 Тестирование подключения к БД")

    // Проверяем подключение
    if err := db.Ping(); err != nil {
        log.Printf("❌ Ошибка подключения к БД: %v", err)
        http.Error(w, "DB connection failed: "+err.Error(), http.StatusInternalServerError)
        return
    }

    // Создаем тестовую запись
    var id int
    err := db.QueryRow(`
        INSERT INTO notifications (user_id, email, message, status, created_at)
        VALUES ('test', 'test@example.com', 'Тестовое уведомление', 'sent', NOW())
        RETURNING id
    `).Scan(&id)

    if err != nil {
        log.Printf("❌ Ошибка вставки тестовой записи: %v", err)
        http.Error(w, "Failed to insert: "+err.Error(), http.StatusInternalServerError)
        return
    }

    log.Printf("✅ Тестовая запись создана с ID: %d", id)

    // Получаем количество записей
    var count int
    err = db.QueryRow(`SELECT COUNT(*) FROM notifications`).Scan(&count)
    if err != nil {
        log.Printf("❌ Ошибка подсчета записей: %v", err)
        http.Error(w, "Failed to count: "+err.Error(), http.StatusInternalServerError)
        return
    }

    // Получаем последние 5 записей
    rows, err := db.Query(`
        SELECT id, user_id, email, message, created_at, status 
        FROM notifications 
        ORDER BY created_at DESC 
        LIMIT 5
    `)
    if err != nil {
        log.Printf("❌ Ошибка получения последних записей: %v", err)
        http.Error(w, "Failed to get recent records: "+err.Error(), http.StatusInternalServerError)
        return
    }
    defer rows.Close()

    var recentNotifications []Notification
    for rows.Next() {
        var n Notification
        rows.Scan(&n.ID, &n.UserID, &n.Email, &n.Message, &n.CreatedAt, &n.Status)
        recentNotifications = append(recentNotifications, n)
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "status":           "ok",
        "last_insert_id":   id,
        "total_count":      count,
        "recent":           recentNotifications,
    })
}

func main() {
    // Инициализируем подключение к БД
    initDB()
    defer db.Close()

    // Регистрируем обработчики
    http.HandleFunc("/health", health)
    http.HandleFunc("/test-db", testDB)
    http.HandleFunc("/notifications", func(w http.ResponseWriter, r *http.Request) {
        log.Printf("📨 Получен %s запрос к /notifications от %s", r.Method, r.RemoteAddr)
        switch r.Method {
        case http.MethodPost:
            createNotification(w, r)
        case http.MethodGet:
            getNotifications(w, r)
        default:
            http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        }
    })

    // Обработчик для корневого пути
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        if r.URL.Path == "/" {
            w.Header().Set("Content-Type", "application/json")
            json.NewEncoder(w).Encode(map[string]string{
                "service": "notification",
                "version": "v1",
                "endpoints": "/health, /test-db, /notifications (GET, POST)",
            })
            return
        }
        http.NotFound(w, r)
    })

    log.Println("📦 Notification Service запущен на :8080")
    log.Println("💾 Используется PostgreSQL для хранения уведомлений")
    log.Println("🔗 Доступные эндпоинты: /health, /test-db, /notifications")
    
    if err := http.ListenAndServe(":8080", nil); err != nil {
        log.Fatalf("❌ Server failed: %v", err)
    }
}