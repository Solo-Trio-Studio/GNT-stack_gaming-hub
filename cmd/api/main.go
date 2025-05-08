package main

import (
	"Gaming_Hub/cmd/api/middleware"
	"Gaming_Hub/pkg/database"
	"Gaming_Hub/pkg/handler"
	"Gaming_Hub/pkg/handler/annoucements"
	crt "Gaming_Hub/pkg/handler/cart"
	delv "Gaming_Hub/pkg/handler/delivery"
	notify "Gaming_Hub/pkg/handler/notification"
	"Gaming_Hub/pkg/handler/restaurant"
	revw "Gaming_Hub/pkg/handler/review"
	"Gaming_Hub/pkg/handler/user"
	"Gaming_Hub/pkg/nats"
	"Gaming_Hub/pkg/service/announcements"
	"Gaming_Hub/pkg/service/cart_order"
	"Gaming_Hub/pkg/service/delivery"
	"Gaming_Hub/pkg/service/notification"
	restro "Gaming_Hub/pkg/service/restaurant"
	"Gaming_Hub/pkg/service/review"
	usr "Gaming_Hub/pkg/service/user"
	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
	"github.com/gorilla/websocket"
	"github.com/joho/godotenv"
	"log"
	"os"
)

func main() {
	// load .env file
	err := godotenv.Load()
	if err != nil {
		log.Fatal("Error loading .env file")
	}

	env := os.Getenv("APP_ENV")
	db := database.New()
	// Create Tables
	if err := db.Migrate(); err != nil {
		log.Fatalf("Error migrating database: %s", err)
	}

	// Connect NATS
	natServer, err := nats.NewNATS("nats://127.0.0.1:4222")

	// WebSocket Clients
	wsClients := make(map[string]*websocket.Conn)

	s := handler.NewServer(db, true)

	// Initialize Validator
	validate := validator.New()

	// Middlewares List
	middlewares := []gin.HandlerFunc{middleware.AuthMiddleware()}

	// User
	userService := usr.NewUserService(db, env)
	user.NewUserHandler(s, "/user", userService, validate)

	// Restaurant
	restaurantService := restro.NewRestaurantService(db, env)
	restaurant.NewRestaurantHandler(s, "/restaurant", restaurantService)

	// Reviews
	reviewService := review.NewReviewService(db, env)
	revw.NewReviewProtectedHandler(s, "/review", reviewService, middlewares, validate)

	// Cart
	cartService := cart_order.NewCartService(db, env, natServer)
	crt.NewCartHandler(s, "/cart", cartService, middlewares, validate)

	// Delivery
	deliveryService := delivery.NewDeliveryService(db, env, natServer)
	delv.NewDeliveryHandler(s, "/delivery", deliveryService, middlewares, validate)

	// Notification
	notifyService := notification.NewNotificationService(db, env, natServer)

	// Subscribe to multiple events.
	_ = notifyService.SubscribeNewOrders(wsClients)
	_ = notifyService.SubscribeOrderStatus(wsClients)

	notify.NewNotifyHandler(s, "/notify", notifyService, middlewares, validate, wsClients)

	// Events/Announcements
	announceService := announcements.NewAnnouncementService(db, env)
	annoucements.NewAnnouncementHandler(s, "/announcements", announceService, middlewares, validate)
	log.Fatal(s.Run())

}
