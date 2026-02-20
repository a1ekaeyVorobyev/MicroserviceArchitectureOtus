package main

// ================================
// PRODUCTION AUTH SERVICE
// ================================
// - Issues short-lived access tokens (JWT)
// - Stores refresh tokens in Redis
// - Password hashing using bcrypt
// - Fully commented for clarity
// ================================

import (
    "context"
    "database/sql"
    "encoding/json"
    "net/http"
    "os"
    "time"
    "log"

    "github.com/golang-jwt/jwt/v5"
    "github.com/google/uuid"
    _ "github.com/lib/pq"
    "github.com/redis/go-redis/v9"
    "golang.org/x/crypto/bcrypt"
)

var db *sql.DB
var rdb *redis.Client
var jwtSecret = []byte("supersecret")
var ctx = context.Background()

type Credentials struct {
    Email    string `json:"email"`
    Password string `json:"password"`
}

func main() {
    var err error

    // Connect to PostgreSQL
    db, err = sql.Open("postgres", os.Getenv("DATABASE_URL"))
    if err != nil {
        panic(err)
    }


    // Retry until DB is ready
    for i := 0; i < 5; i++ {
        if err = db.Ping(); err == nil {
            break
        }
        time.Sleep(2 * time.Second)
    }
    if err != nil {
        panic("cannot connect to database: " + err.Error())
    }

    // Apply migrations
    if err := applyMigrations(db); err != nil {
        panic("migration failed: " + err.Error())
    }

    // Connect to Redis (for refresh tokens)
    rdb = redis.NewClient(&redis.Options{
        Addr: os.Getenv("REDIS_ADDR"),
    })

    log.Println("auth-service started on :8080")

    http.HandleFunc("/auth/register", register)
    http.HandleFunc("/auth/login", login)
    http.HandleFunc("/auth/refresh", refresh)

    http.ListenAndServe(":8080", nil)
}

// Registers user and creates empty profile
func register(w http.ResponseWriter, r *http.Request) {
    var c Credentials
    json.NewDecoder(r.Body).Decode(&c)

    hash, _ := bcrypt.GenerateFromPassword([]byte(c.Password), 14)
    id := uuid.New()

    _, err := db.Exec(`INSERT INTO users(id,email,password_hash) VALUES($1,$2,$3)`, id, c.Email, hash)
    if err != nil {
        http.Error(w, err.Error(), 400)
        return
    }

    db.Exec(`INSERT INTO profiles(id,user_id) VALUES($1,$2)`, uuid.New(), id)

    log.Printf("User registered: %s\n", id)
    log.Printf("User logged in: %s\n", c.Email)

    w.WriteHeader(http.StatusCreated)
}

// Login returns access + refresh tokens
func login(w http.ResponseWriter, r *http.Request) {
    var c Credentials
    json.NewDecoder(r.Body).Decode(&c)

    var id string
    var hash string

    err := db.QueryRow(`SELECT id,password_hash FROM users WHERE email=$1`, c.Email).Scan(&id, &hash)
    if err != nil || bcrypt.CompareHashAndPassword([]byte(hash), []byte(c.Password)) != nil {
        http.Error(w, "invalid credentials", 401)
        return
    }

    access := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
        "user_id": id,
        "exp":     time.Now().Add(15 * time.Minute).Unix(),
    })
    accessString, _ := access.SignedString(jwtSecret)

    refreshToken := uuid.New().String()

    // Store refresh token in Redis for 7 days
    rdb.Set(ctx, refreshToken, id, 7*24*time.Hour)

    json.NewEncoder(w).Encode(map[string]string{
        "access_token":  accessString,
        "refresh_token": refreshToken,
    })
}

// Refresh endpoint generates new access token
func refresh(w http.ResponseWriter, r *http.Request) {
    var body map[string]string
    json.NewDecoder(r.Body).Decode(&body)

    userID, err := rdb.Get(ctx, body["refresh_token"]).Result()
    if err != nil {
        http.Error(w, "invalid refresh token", 401)
        return
    }

    access := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
        "user_id": userID,
        "exp":     time.Now().Add(15 * time.Minute).Unix(),
    })

    accessString, _ := access.SignedString(jwtSecret)

    json.NewEncoder(w).Encode(map[string]string{
        "access_token": accessString,
    })
}


//migartion
func applyMigrations(db *sql.DB) error {
    sqlBytes, err := os.ReadFile("./migrations/001_init.sql")
    if err != nil {
        return err
    }

    _, err = db.Exec(string(sqlBytes))
    if err != nil {
        return err
    }

    return nil
}