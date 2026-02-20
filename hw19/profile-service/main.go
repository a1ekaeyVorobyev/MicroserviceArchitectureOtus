package main

// =======================================
// PROFILE SERVICE
// =======================================
// - Reads user_id from validated JWT
// - Only allows user to access own profile
// =======================================

import (
    "database/sql"
    "encoding/json"
    "net/http"
    "os"

    "github.com/golang-jwt/jwt/v5"
    _ "github.com/lib/pq"
)

var db *sql.DB
var jwtSecret = []byte("supersecret")

type Profile struct {
    FirstName string `json:"first_name"`
    LastName  string `json:"last_name"`
    Phone     string `json:"phone"`
}

func main() {
    var err error
    db, err = sql.Open("postgres", os.Getenv("DATABASE_URL"))
    if err != nil {
        panic(err)
    }

    http.HandleFunc("/profile/me", authMiddleware(profileHandler))
    http.ListenAndServe(":8080", nil)
}

func authMiddleware(next http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        tokenStr := r.Header.Get("Authorization")
        if tokenStr == "" {
            http.Error(w, "unauthorized", 401)
            return
        }

        tokenStr = tokenStr[len("Bearer "):]

        token, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
            return jwtSecret, nil
        })

        if err != nil || !token.Valid {
            http.Error(w, "unauthorized", 401)
            return
        }

        claims := token.Claims.(jwt.MapClaims)
        r.Header.Set("user_id", claims["user_id"].(string))
        next(w, r)
    }
}

func profileHandler(w http.ResponseWriter, r *http.Request) {
    userID := r.Header.Get("user_id")

    switch r.Method {
    case http.MethodGet:
        var p Profile
        err := db.QueryRow(`SELECT first_name,last_name,phone FROM profiles WHERE user_id=$1`, userID).
            Scan(&p.FirstName, &p.LastName, &p.Phone)
        if err != nil {
            http.Error(w, "not found", 404)
            return
        }
        json.NewEncoder(w).Encode(p)

    case http.MethodPut:
        var p Profile
        json.NewDecoder(r.Body).Decode(&p)
        db.Exec(`UPDATE profiles SET first_name=$1,last_name=$2,phone=$3 WHERE user_id=$4`,
            p.FirstName, p.LastName, p.Phone, userID)
        w.WriteHeader(200)
    }
}
