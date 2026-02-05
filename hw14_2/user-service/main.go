package main

import (
    "flag"
    "fmt"
    "log"
    "net/http"
    "os"
    "path/filepath"
    "strings"
    "github.com/a1eksey/users-service/db"
    "github.com/a1eksey/users-service/handlers"

    "github.com/gorilla/mux"
    "github.com/jmoiron/sqlx"
)

func main() {
    // Флаг для запуска миграций
    migrateFlag := flag.Bool("migrate", false, "Run DB migrations and exit")
    flag.Parse()

    // Чтение env переменных
    dbHost := getEnv("DB_HOST", "localhost")
    dbPort := getEnv("DB_PORT", "5432")
    dbName := getEnv("DB_NAME", "users")
    dbUser := getEnv("DB_USER", "user")
    dbPassword := getEnv("DB_PASSWORD", "password")

    connStr := fmt.Sprintf(
        "host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
        dbHost, dbPort, dbUser, dbPassword, dbName,
    )

    // Соединение через sqlx
    database, err := sqlx.Connect("postgres", connStr)
    if err != nil {
        log.Fatalf("Failed to connect to DB: %v", err)
    }
    defer database.Close()

    // Если миграции
    if *migrateFlag {
        log.Println("Running DB migrations...")
        if err := runMigrations(database); err != nil {
            log.Fatalf("Migrations failed: %v", err)
        }
        log.Println("Migrations completed successfully")
        return
    }

    // Основное подключение
    db.SetDB(database)

    // HTTP роутинг
    r := mux.NewRouter()
    r.HandleFunc("/users", handlers.GetUsers).Methods("GET")
    r.HandleFunc("/users/{id:[0-9]+}", handlers.GetUser).Methods("GET")
    r.HandleFunc("/users", handlers.CreateUser).Methods("POST")
    r.HandleFunc("/users/{id:[0-9]+}", handlers.UpdateUser).Methods("PUT")
    r.HandleFunc("/users/{id:[0-9]+}", handlers.DeleteUser).Methods("DELETE")

    log.Println("Users Service started on :8080")
    log.Fatal(http.ListenAndServe(":8080", r))
}

// runMigrations выполняет SQL файлы из migrations/
// runMigrations выполняет SQL файлы из migrations/
func runMigrations(db *sqlx.DB) error {
    files, err := filepath.Glob("migrations/*.sql")
    if err != nil {
        return fmt.Errorf("failed to read migrations: %w", err)
    }

    for _, f := range files {
        sqlBytes, err := os.ReadFile(f)
        if err != nil {
            return fmt.Errorf("failed to read file %s: %w", f, err)
        }

        if _, err := db.Exec(string(sqlBytes)); err != nil {
            // Проверяем, если ошибка о том что таблица уже существует - игнорируем
            if strings.Contains(err.Error(), "already exists") {
                log.Printf("Table already exists, skipping: %s", f)
                continue
            }
            return fmt.Errorf("failed to execute migration %s: %w", f, err)
        }

        log.Printf("Applied migration: %s", f)
    }

    return nil
}
// getEnv читает переменные окружения с дефолтом
func getEnv(key, def string) string {
    if val, ok := os.LookupEnv(key); ok {
        return val
    }
    return def
}
