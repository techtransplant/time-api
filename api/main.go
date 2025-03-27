package main

import (
	"fmt"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/go-chi/chi"
	"github.com/go-chi/chi/middleware"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
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
		w.Write([]byte(`{"The current epoch time":"` + strconv.FormatInt(time.Now().Unix(), 10) + `"}`))
	})

	fmt.Printf("Server started on port %s\n", port)
	http.ListenAndServe(":"+port, router)
}
