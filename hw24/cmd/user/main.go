package main

import (
    "bytes"
    "encoding/json"
    "fmt"
    "net/http"
    "sync"
)

type User struct {
    ID    string `json:"id"`
    Email string `json:"email"`
}

type Account struct {
    UserID  string  `json:"user_id"`
    Balance float64 `json:"balance"`
}

var (
    users              = make(map[string]User)
    userMutex          = &sync.RWMutex{}
    billingServiceURL  = "http://billing-service:8080"
)

func createUser(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }

    var user User
    if err := json.NewDecoder(r.Body).Decode(&user); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }

    // Генерируем ID
    userMutex.Lock()
    user.ID = fmt.Sprintf("%d", len(users)+1)
    users[user.ID] = user
    userMutex.Unlock()

    // Создаем аккаунт в биллинге
    account := Account{UserID: user.ID, Balance: 0}
    accountJSON, _ := json.Marshal(account)

    // Вызываем billing service
    resp, err := http.Post(billingServiceURL+"/accounts", "application/json", bytes.NewBuffer(accountJSON))
    if err != nil {
        http.Error(w, "Failed to create billing account", http.StatusInternalServerError)
        return
    }
    defer resp.Body.Close()

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(user)
}

func getUsers(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    userMutex.RLock()
    usersList := make([]User, 0, len(users))
    for _, user := range users {
        usersList = append(usersList, user)
    }
    userMutex.RUnlock()
    json.NewEncoder(w).Encode(usersList)
}

func health(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]string{
        "service": "user",
        "status":  "ok",
    })
}

func main() {
    // Регистрируем обработчики
    http.HandleFunc("/health", health)
    
    // Обработчик для /users (без слеша)
    http.HandleFunc("/users", func(w http.ResponseWriter, r *http.Request) {
        fmt.Printf("Received %s request to /users\n", r.Method)
        switch r.Method {
        case http.MethodPost:
            createUser(w, r)
        case http.MethodGet:
            getUsers(w, r)
        default:
            http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        }
    })

    // Обработчик для /users/ (со слешем) - перенаправляет на /users
    http.HandleFunc("/users/", func(w http.ResponseWriter, r *http.Request) {
        http.Redirect(w, r, "/users", http.StatusTemporaryRedirect)
    })

    // Обработчик для корневого пути - отдаём информацию о сервисе
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        if r.URL.Path == "/" {
            w.Header().Set("Content-Type", "application/json")
            json.NewEncoder(w).Encode(map[string]string{
                "service": "user",
                "message": "User service is running. Available endpoints: /health, /users",
            })
            return
        }
        http.NotFound(w, r)
    })

    // Запускаем сервер
    fmt.Println("User service starting on :8080")
    if err := http.ListenAndServe(":8080", nil); err != nil {
        fmt.Printf("Server failed: %v\n", err)
    }
}