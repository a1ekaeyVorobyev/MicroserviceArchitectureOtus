package main

import (
        "log"
        "net/http"
        "net/http/httputil"
        "net/url"
)

func main() {
        authURL, _ := url.Parse("http://auth-service:80")
        profileURL, _ := url.Parse("http://profile-service:80")

        authProxy := httputil.NewSingleHostReverseProxy(authURL)
        profileProxy := httputil.NewSingleHostReverseProxy(profileURL)

        authProxy.ErrorLog = log.Default()
        profileProxy.ErrorLog = log.Default()

        // Auth прокси - сохраняем полный путь с /auth
        http.HandleFunc("/auth/", func(w http.ResponseWriter, r *http.Request) {
                log.Printf("Auth request: %s", r.URL.Path)
                // НЕ удаляем префикс /auth
                authProxy.ServeHTTP(w, r)
        })

        // Profile прокси - сохраняем полный путь с /profile
        http.HandleFunc("/profile/", func(w http.ResponseWriter, r *http.Request) {
                log.Printf("Profile request: %s", r.URL.Path)
                // НЕ удаляем префикс /profile
                profileProxy.ServeHTTP(w, r)
        })

        http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
                log.Printf("Root path accessed: %s", r.URL.Path)
                w.WriteHeader(404)
                w.Write([]byte("404 page not found"))
        })

        log.Println("API Gateway running on :8080")
        log.Fatal(http.ListenAndServe(":8080", nil))
}