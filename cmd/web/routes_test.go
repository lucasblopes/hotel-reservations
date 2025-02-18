package main

import (
	"fmt"
	"testing"

	"github.com/go-chi/chi"
	"github.com/lucasblopes/hotel-reservations/internal/config"
)

func TestRoutes(t *testing.T) {
	var app config.AppConfig
	mux := routes(&app)

	switch v := mux.(type) {
	case *chi.Mux:
		// passed
	default:
		t.Error(fmt.Printf("type is not *chi.Mux, type is %T", v))
	}
}
