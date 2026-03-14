package main

import (
    "bytes"
    "encoding/json"
    "fmt"
    "net/http"
    "sync"
    "time"
)

type Order struct {
    ID     string  `json:"id"`
    UserID string  `json:"user_id"`
    Amount float64 `json:"amount"`
    Status string  `json:"status"`
    Email  string  `json:"email"`
}

type Notification struct {
    UserID  string `json:"user_id"`
    Email   string `json:"email"`
    Message string `json:"message"`
}

var (
    orders                 = make(map[string]Order)
    orderMutex             = &sync.RWMutex{}
    billingServiceURL      = "http://billing-service:8080"
    notificationServiceURL = "http://notification-service:8080"
    orderCounter           int
)

// Функция для асинхронной отправки уведомления
func sendNotificationAsync(userID, email, message string) {
    // Запускаем в отдельной горутине, чтобы не блокировать основной поток
    go func() {
        // Небольшая задержка для имитации асинхронности
        time.Sleep(100 * time.Millisecond)
        
        notification := Notification{
            UserID:  userID,
            Email:   email,
            Message: message,
        }
        notificationJSON, _ := json.Marshal(notification)
        
        // Отправляем уведомление в Notification Service
        resp, err := http.Post(notificationServiceURL+"/notifications", 
                              "application/json", 
                              bytes.NewBuffer(notificationJSON))
        
        if err != nil {
            fmt.Printf("❌ Ошибка отправки уведомления: %v\n", err)
            return
        }
        defer resp.Body.Close()
        
        fmt.Printf("📨 Уведомление асинхронно отправлено, статус: %d\n", resp.StatusCode)
    }()
}

func createOrder(w http.ResponseWriter, r *http.Request) {
    fmt.Println("\n=== СОЗДАНИЕ ЗАКАЗА (АСИНХРОННЫЕ НОТИФИКАЦИИ) ===")
    
    if r.Method != http.MethodPost {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }

    var order Order
    if err := json.NewDecoder(r.Body).Decode(&order); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }

    fmt.Printf("📦 Получен заказ: UserID=%s, Amount=%.2f, Email=%s\n", 
        order.UserID, order.Amount, order.Email)

    // Генерируем ID заказа
    orderMutex.Lock()
    orderCounter++
    order.ID = fmt.Sprintf("%d", orderCounter)
    orderMutex.Unlock()

    // 1. СИНХРОННО снимаем деньги через Billing Service
    fmt.Println("💰 Синхронный вызов Billing Service...")
    
    withdrawReq := map[string]interface{}{
        "user_id": order.UserID,
        "amount":  order.Amount,
    }
    withdrawJSON, _ := json.Marshal(withdrawReq)
    
    resp, err := http.Post(billingServiceURL+"/accounts/"+order.UserID+"/withdraw",
                          "application/json",
                          bytes.NewBuffer(withdrawJSON))

    var orderStatus string
    var httpStatus int
    var notificationMessage string

    if err != nil {
        fmt.Printf("❌ Ошибка вызова billing service: %v\n", err)
        orderStatus = "failed"
        httpStatus = http.StatusInternalServerError
        notificationMessage = fmt.Sprintf("Заказ %s: ошибка сервиса биллинга", order.ID)
    } else {
        defer resp.Body.Close()
        
        switch resp.StatusCode {
        case http.StatusOK:
            orderStatus = "completed"
            httpStatus = http.StatusCreated
            notificationMessage = fmt.Sprintf("Заказ %s успешно оформлен! Спасибо за покупку!", order.ID)
            fmt.Println("✅ Деньги сняты успешно")
            
        case http.StatusPaymentRequired:
            orderStatus = "insufficient_funds"
            httpStatus = http.StatusPaymentRequired
            notificationMessage = fmt.Sprintf("Заказ %s: недостаточно средств на счете", order.ID)
            fmt.Println("⚠️  Недостаточно средств")
            
        default:
            orderStatus = "failed"
            httpStatus = http.StatusInternalServerError
            notificationMessage = fmt.Sprintf("Заказ %s: ошибка обработки", order.ID)
            fmt.Printf("❌ Неожиданный статус от billing: %d\n", resp.StatusCode)
        }
    }

    order.Status = orderStatus

    // Сохраняем заказ
    orderMutex.Lock()
    orders[order.ID] = order
    orderMutex.Unlock()

    // 2. АСИНХРОННО отправляем уведомление (не блокирует ответ клиенту)
    fmt.Println("📤 Асинхронная отправка уведомления...")
    sendNotificationAsync(order.UserID, order.Email, notificationMessage)

    // Отправляем ответ клиенту НЕМЕДЛЕННО
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(httpStatus)
    json.NewEncoder(w).Encode(order)
    
    fmt.Printf("✅ Ответ отправлен клиенту (статус: %d)\n", httpStatus)
    fmt.Println("=== ЗАКАЗ ОБРАБОТАН ===\n")
}

func getOrders(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodGet {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }

    w.Header().Set("Content-Type", "application/json")
    orderMutex.RLock()
    ordersList := make([]Order, 0, len(orders))
    for _, order := range orders {
        ordersList = append(ordersList, order)
    }
    orderMutex.RUnlock()
    
    fmt.Printf("📋 Запрошен список заказов: всего %d\n", len(ordersList))
    json.NewEncoder(w).Encode(ordersList)
}

func health(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]string{
        "service": "order",
        "status":  "ok",
    })
}

func main() {
    http.HandleFunc("/health", health)
    http.HandleFunc("/orders", func(w http.ResponseWriter, r *http.Request) {
        switch r.Method {
        case http.MethodPost:
            createOrder(w, r)
        case http.MethodGet:
            getOrders(w, r)
        default:
            http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        }
    })

    fmt.Println("📦 Order Service запущен на :8080")
    fmt.Println("🔄 Режим: синхронное списание + асинхронные нотификации")
    if err := http.ListenAndServe(":8080", nil); err != nil {
        fmt.Printf("❌ Server failed: %v\n", err)
    }
}