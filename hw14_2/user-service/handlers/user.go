package handlers


import (
    "encoding/json"
    "net/http"
    "strconv"

    "github.com/a1eksey/users-service/db"
    "github.com/a1eksey/users-service/models"  // Добавьте этот импорт
    "github.com/gorilla/mux"
)

func GetUsers(w http.ResponseWriter, r *http.Request) {
    var users []models.User
    if err := db.DB.Select(&users, "SELECT id, name, email FROM users"); err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    json.NewEncoder(w).Encode(users)
}

func GetUser(w http.ResponseWriter, r *http.Request) {
    idStr := mux.Vars(r)["id"]
    id, _ := strconv.Atoi(idStr)
    var user models.User
    if err := db.DB.Get(&user, "SELECT id, name, email FROM users WHERE id=$1", id); err != nil {
        http.Error(w, "User not found", http.StatusNotFound)
        return
    }
    json.NewEncoder(w).Encode(user)
}

func CreateUser(w http.ResponseWriter, r *http.Request) {
    var user models.User
    json.NewDecoder(r.Body).Decode(&user)

    var id int
    err := db.DB.QueryRow(
        "INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id",
        user.Name, user.Email,
    ).Scan(&id)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    user.ID = id
    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(user)
}

func UpdateUser(w http.ResponseWriter, r *http.Request) {
    idStr := mux.Vars(r)["id"]
    id, _ := strconv.Atoi(idStr)
    var user models.User
    json.NewDecoder(r.Body).Decode(&user)

    _, err := db.DB.Exec(
        "UPDATE users SET name=$1, email=$2 WHERE id=$3",
        user.Name, user.Email, id,
    )
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    user.ID = id
    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(user)
}

func DeleteUser(w http.ResponseWriter, r *http.Request) {
    idStr := mux.Vars(r)["id"]
    id, _ := strconv.Atoi(idStr)
    _, err := db.DB.Exec("DELETE FROM users WHERE id=$1", id)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    w.WriteHeader(http.StatusNoContent)
}
