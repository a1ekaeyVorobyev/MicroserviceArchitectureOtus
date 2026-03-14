package main

import (
    "encoding/json"
    "fmt"
    "net/http"
    "strings"
    "sync"
)

type Account struct {
    UserID  string  `json:"user_id"`
    Balance float64 `json:"balance"`
}

type Transaction struct {
    UserID string  `json:"user_id"`
    Amount float64 `json:"amount"`
    Type   string  `json:"type"` // "deposit" or "withdraw"
}

var (
    accounts = make(map[string]*Account)
    mutex    = &sync.RWMutex{}
)

func createAccount(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }

    var account Account
    if err := json.NewDecoder(r.Body).Decode(&account); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }

    mutex.Lock()
    accounts[account.UserID] = &Account{UserID: account.UserID, Balance: 0}
    mutex.Unlock()

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(map[string]string{"status": "created", "user_id": account.UserID})
}

func deposit(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }

    // Получаем user_id из URL
    pathParts := strings.Split(r.URL.Path, "/")
    if len(pathParts) < 4 || pathParts[3] != "deposit" {
        http.Error(w, "Invalid URL", http.StatusBadRequest)
        return
    }
    userID := pathParts[2]

    var transaction Transaction
    if err := json.NewDecoder(r.Body).Decode(&transaction); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }

    mutex.Lock()
    account, exists := accounts[userID]
    if !exists {
        mutex.Unlock()
        http.Error(w, "Account not found", http.StatusNotFound)
        return
    }

    account.Balance += transaction.Amount
    mutex.Unlock()

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(account)
}

func withdraw(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }

    // Получаем user_id из URL
    pathParts := strings.Split(r.URL.Path, "/")
    if len(pathParts) < 4 || pathParts[3] != "withdraw" {
        http.Error(w, "Invalid URL", http.StatusBadRequest)
        return
    }
    userID := pathParts[2]

    var transaction Transaction
    if err := json.NewDecoder(r.Body).Decode(&transaction); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }

    mutex.Lock()
    account, exists := accounts[userID]
    if !exists {
        mutex.Unlock()
        http.Error(w, "Account not found", http.StatusNotFound)
        return
    }

    if account.Balance < transaction.Amount {
        mutex.Unlock()
        http.Error(w, "Insufficient funds", http.StatusPaymentRequired)
        return
    }

    account.Balance -= transaction.Amount
    mutex.Unlock()

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(account)
}

func getBalance(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodGet {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }

    // Получаем user_id из URL
    pathParts := strings.Split(r.URL.Path, "/")
    if len(pathParts) < 3 {
        http.Error(w, "Invalid URL", http.StatusBadRequest)
        return
    }
    userID := pathParts[2]

    mutex.RLock()
    account, exists := accounts[userID]
    mutex.RUnlock()

    if !exists {
        http.Error(w, "Account not found", http.StatusNotFound)
        return
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(account)
}

func health(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]string{
        "service": "billing",
        "status":  "ok",
    })
}

func main() {
    http.HandleFunc("/health", health)
    http.HandleFunc("/accounts", createAccount)
    http.HandleFunc("/accounts/", func(w http.ResponseWriter, r *http.Request) {
        pathParts := strings.Split(r.URL.Path, "/")
        if len(pathParts) < 3 {
            http.Error(w, "Invalid URL", http.StatusBadRequest)
            return
        }
        
        switch {
        case len(pathParts) >= 4 && pathParts[3] == "deposit":
            deposit(w, r)
        case len(pathParts) >= 4 && pathParts[3] == "withdraw":
            withdraw(w, r)
        default:
            getBalance(w, r)
        }
    })

    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        if r.URL.Path == "/" {
            w.Header().Set("Content-Type", "application/json")
            json.NewEncoder(w).Encode(map[string]string{
                "service": "billing",
                "message": "Billing service is running. Available endpoints: /health, /accounts, /accounts/{id}, /accounts/{id}/deposit, /accounts/{id}/withdraw",
            })
            return
        }
        http.NotFound(w, r)
    })

    fmt.Println("Billing service starting on :8080")
    if err := http.ListenAndServe(":8080", nil); err != nil {
        fmt.Printf("Server failed: %v\n", err)
    }
}