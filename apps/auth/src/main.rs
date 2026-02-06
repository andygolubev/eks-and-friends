use actix_web::{web, App, HttpServer, HttpResponse, middleware};
use mongodb::{Client, options::ClientOptions};
use serde::{Deserialize, Serialize};
use std::env;

#[derive(Clone)]
struct AppState {
    db: mongodb::Database,
}

#[derive(Serialize)]
struct HealthResponse {
    status: String,
    service: String,
    db_connected: bool,
}

#[derive(Serialize, Deserialize)]
struct User {
    username: String,
    email: String,
}

#[derive(Deserialize)]
struct LoginRequest {
    username: String,
    password: String,
}

#[derive(Serialize)]
struct TokenResponse {
    token: String,
    username: String,
}

async fn health(data: web::Data<AppState>) -> HttpResponse {
    let db_connected = data.db
        .run_command(mongodb::bson::doc! { "ping": 1 })
        .await
        .is_ok();

    HttpResponse::Ok().json(HealthResponse {
        status: "ok".into(),
        service: "auth".into(),
        db_connected,
    })
}

async fn login(body: web::Json<LoginRequest>, data: web::Data<AppState>) -> HttpResponse {
    let collection = data.db.collection::<mongodb::bson::Document>("users");

    match collection
        .find_one(mongodb::bson::doc! { "username": &body.username })
        .await
    {
        Ok(Some(_user)) => {
            // Simplified: in production, verify password hash
            let token = uuid::Uuid::new_v4().to_string();
            HttpResponse::Ok().json(TokenResponse {
                token,
                username: body.username.clone(),
            })
        }
        Ok(None) => {
            HttpResponse::Unauthorized().json(serde_json::json!({"error": "invalid credentials"}))
        }
        Err(e) => {
            log::error!("DB error: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({"error": "internal error"}))
        }
    }
}

async fn liveness() -> HttpResponse {
    HttpResponse::Ok().body("ok")
}

async fn readiness(data: web::Data<AppState>) -> HttpResponse {
    match data.db.run_command(mongodb::bson::doc! { "ping": 1 }).await {
        Ok(_) => HttpResponse::Ok().body("ok"),
        Err(_) => HttpResponse::ServiceUnavailable().body("db unavailable"),
    }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    env_logger::init();

    let mongo_uri = env::var("MONGO_URI")
        .unwrap_or_else(|_| "mongodb://root:rootpass@localhost:27017".into());
    let db_name = env::var("MONGO_DB").unwrap_or_else(|_| "authdb".into());
    let listen_port = env::var("PORT").unwrap_or_else(|_| "8080".into());

    let client_options = ClientOptions::parse(&mongo_uri)
        .await
        .expect("Failed to parse MongoDB URI");
    let client = Client::with_options(client_options)
        .expect("Failed to create MongoDB client");
    let db = client.database(&db_name);

    log::info!("Starting auth service on port {}", listen_port);

    let data = web::Data::new(AppState { db });

    HttpServer::new(move || {
        App::new()
            .app_data(data.clone())
            .wrap(middleware::Logger::default())
            .route("/auth/health", web::get().to(health))
            .route("/auth/login", web::post().to(login))
            .route("/healthz/ready", web::get().to(readiness))
            .route("/healthz/live", web::get().to(liveness))
    })
    .bind(format!("0.0.0.0:{}", listen_port))?
    .run()
    .await
}
