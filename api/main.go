package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/go-chi/chi"
	"github.com/go-chi/chi/middleware"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8000"
	}

	// router routes the requests to the appropriate handler
	router := chi.NewRouter()

	// add logger middleware for logging requests
	router.Use(middleware.Logger)

	// handle GET requests for the root path
	router.Get("/", func(w http.ResponseWriter, r *http.Request) {
		// Return a JSON response
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		 
		// Return timestamp as an integer
		json.NewEncoder(w).Encode(map[string]int64{"The current epoch time": time.Now().Unix()})
	})

	fmt.Printf("Server started on port %s\n", port)
	http.ListenAndServe(":"+port, router)
}
