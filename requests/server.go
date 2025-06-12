package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

func main() {
	http.HandleFunc("/auth/register", echoToken)
	http.HandleFunc("/auth/login", echoJSON)
	http.HandleFunc("/auth/refresh", echoHeaders)

	fmt.Println("listening on :1323")
	http.ListenAndServe(":1323", nil)
}

func echoToken(w http.ResponseWriter, r *http.Request) {
	defer r.Body.Close()
	body := map[string]any{
		"token": fmt.Sprint(time.Now().UnixMicro()),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(body)
}

func echoJSON(w http.ResponseWriter, r *http.Request) {
	defer r.Body.Close()
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "couldn't read body", http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(body)
}

func echoHeaders(w http.ResponseWriter, r *http.Request) {
	auth := r.Header.Get("Authorization")

	resp := map[string]string{
		"authorization": auth,
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}
