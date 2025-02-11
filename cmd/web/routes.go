package main

import (
	"net/http"

	"github.com/go-chi/chi"
	"github.com/go-chi/chi/middleware"
	"github.com/lucasblopes/hotel-reservations/pkg/handlers"
)

func routes() http.Handler {
	mux := chi.NewRouter()

	// Using the recoverer middleware
	mux.Use(middleware.Recoverer)
	mux.Use(NoSurf)
	mux.Use(SessionLoad)

	mux.Get("/", handlers.Repo.Home)
	mux.Get("/about", handlers.Repo.About)
	return mux
}
