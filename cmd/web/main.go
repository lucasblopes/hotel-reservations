package main

import (
	"encoding/gob"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/alexedwards/scs/v2"
	"github.com/lucasblopes/hotel-reservations/internal/config"
	"github.com/lucasblopes/hotel-reservations/internal/handlers"
	"github.com/lucasblopes/hotel-reservations/internal/models"
	"github.com/lucasblopes/hotel-reservations/internal/render"
)

const portNumber = ":8080"

var (
	app     config.AppConfig
	session *scs.SessionManager
)

// main is the main function
func main() {
	err := run()
	if err != nil {
		log.Fatal(err)
	}

	if app.InProduction {
		hostname, err := os.Hostname()
		if err != nil {
			fmt.Println("Error getting hostname:", err)
			return
		}
		fmt.Printf("Starting application on: http://%s%s\n", hostname, portNumber)
	} else {
		fmt.Printf("Starting application on: http://localhost%s\n", portNumber)
	}

	srv := &http.Server{
		Addr:    portNumber,
		Handler: routes(&app),
	}

	err = srv.ListenAndServe()
	if err != nil {
		log.Fatal(err)
	}
}

// run starts the application
func run() error {
	// what am i going to put in the session
	gob.Register(models.Reservation{})
	// change this to true when in production
	app.InProduction = false
	session = scs.New()
	session.Lifetime = 24 * time.Hour
	// Cokie persis even when the user closes the browser
	session.Cookie.Persist = true
	session.Cookie.SameSite = http.SameSiteLaxMode
	session.Cookie.Secure = app.InProduction

	app.Session = session

	tc, err := render.CreateTemplateCache()
	if err != nil {
		log.Fatal(err, "cannot create template cache")
		return err
	}

	app.TemplateCache = tc
	app.UseCache = false

	repo := handlers.NewRepo(&app)
	handlers.NewHandlers(repo)

	render.NewTemplates(&app)

	return nil
}
