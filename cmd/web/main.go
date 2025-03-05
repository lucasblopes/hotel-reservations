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
	"github.com/lucasblopes/hotel-reservations/internal/driver"
	"github.com/lucasblopes/hotel-reservations/internal/handlers"
	"github.com/lucasblopes/hotel-reservations/internal/helpers"
	"github.com/lucasblopes/hotel-reservations/internal/models"
	"github.com/lucasblopes/hotel-reservations/internal/render"
)

const portNumber = ":8080"

var (
	app      config.AppConfig
	session  *scs.SessionManager
	infoLog  *log.Logger
	errorLog *log.Logger
)

// main is the main function
func main() {
	db, err := run()
	if err != nil {
		log.Fatal(err)
	}

	// Close the DB connection when the program finishes
	defer db.SQL.Close()

	defer close(app.MailChan)
	listenForMail()
	fmt.Println("Starting mail listener...")

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
func run() (*driver.DB, error) {
	// what am i going to put in the session
	gob.Register(models.Reservation{})
	gob.Register(models.User{})
	gob.Register(models.Room{})
	gob.Register(models.Restriction{})

	mailChan := make(chan models.MailData)
	app.MailChan = mailChan

	// change this to true when in production
	app.InProduction = false

	// add detailed logging to config
	infoLog = log.New(os.Stdout, "INFO\t", log.Ldate|log.Ltime)
	app.InfoLog = infoLog

	errorLog = log.New(os.Stdout, "ERROR\t", log.Ldate|log.Ltime|log.Lshortfile)
	app.ErrorLog = errorLog

	session = scs.New()
	session.Lifetime = 24 * time.Hour

	// Cokie persis even when the user closes the browser
	session.Cookie.Persist = true
	session.Cookie.SameSite = http.SameSiteLaxMode
	session.Cookie.Secure = app.InProduction

	app.Session = session

	// Connect to database
	log.Println("Connecting to database...")
	db, err := driver.ConnectSQL("host=localhost port=5432 dbname=bookings user=lucas password=admin")
	if err != nil {
		log.Fatal("Cannot connect to database! Dying...")
	}
	log.Println("Connected to database!")

	tc, err := render.CreateTemplateCache()
	if err != nil {
		log.Fatal(err, "cannot create template cache")
		return nil, err
	}

	app.TemplateCache = tc
	app.UseCache = false

	repo := handlers.NewRepo(&app, db)
	handlers.NewHandlers(repo)
	render.NewRenderer(&app)
	helpers.NewHelpers(&app)

	return db, nil
}
