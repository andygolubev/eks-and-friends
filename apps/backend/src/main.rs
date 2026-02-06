use actix_web::{web, App, HttpServer, HttpResponse, middleware};
use serde::Serialize;
use std::env;
use tokio_postgres::NoTls;

#[derive(Serialize)]
struct HealthResponse {
    status: String,
    service: String,
    db_connected: bool,
}

#[derive(Serialize)]
struct Item {
    id: i32,
    name: String,
    description: String,
}

struct AppState {
    db_url: String,
}

async fn get_db_client(db_url: &str) -> Result<tokio_postgres::Client, tokio_postgres::Error> {
    let (client, connection) = tokio_postgres::connect(db_url, NoTls).await?;
    tokio::spawn(async move {
        if let Err(e) = connection.await {
            log::error!("DB connection error: {}", e);
        }
    });
    Ok(client)
}

async fn health(data: web::Data<AppState>) -> HttpResponse {
    let db_connected = get_db_client(&data.db_url).await.is_ok();
    HttpResponse::Ok().json(HealthResponse {
        status: "ok".into(),
        service: "backend".into(),
        db_connected,
    })
}

async fn get_items(data: web::Data<AppState>) -> HttpResponse {
    match get_db_client(&data.db_url).await {
        Ok(client) => {
            match client.query("SELECT id, name, description FROM items ORDER BY id", &[]).await {
                Ok(rows) => {
                    let items: Vec<Item> = rows.iter().map(|row| Item {
                        id: row.get("id"),
                        name: row.get("name"),
                        description: row.get("description"),
                    }).collect();
                    HttpResponse::Ok().json(items)
                }
                Err(e) => {
                    log::error!("Query error: {}", e);
                    HttpResponse::InternalServerError().json(serde_json::json!({"error": "query failed"}))
                }
            }
        }
        Err(e) => {
            log::error!("DB connect error: {}", e);
            HttpResponse::ServiceUnavailable().json(serde_json::json!({"error": "db unavailable"}))
        }
    }
}

async fn readiness(data: web::Data<AppState>) -> HttpResponse {
    match get_db_client(&data.db_url).await {
        Ok(_) => HttpResponse::Ok().body("ok"),
        Err(_) => HttpResponse::ServiceUnavailable().body("db unavailable"),
    }
}

async fn liveness() -> HttpResponse {
    HttpResponse::Ok().body("ok")
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    env_logger::init();

    let db_host = env::var("DB_HOST").unwrap_or_else(|_| "localhost".into());
    let db_port = env::var("DB_PORT").unwrap_or_else(|_| "5432".into());
    let db_user = env::var("DB_USER").unwrap_or_else(|_| "appuser".into());
    let db_password = env::var("DB_PASSWORD").unwrap_or_else(|_| "apppass".into());
    let db_name = env::var("DB_NAME").unwrap_or_else(|_| "appdb".into());
    let listen_port = env::var("PORT").unwrap_or_else(|_| "8080".into());

    let db_url = format!(
        "host={} port={} user={} password={} dbname={}",
        db_host, db_port, db_user, db_password, db_name
    );

    log::info!("Starting backend on port {}", listen_port);

    let data = web::Data::new(AppState { db_url });

    HttpServer::new(move || {
        App::new()
            .app_data(data.clone())
            .wrap(middleware::Logger::default())
            .route("/api/health", web::get().to(health))
            .route("/api/items", web::get().to(get_items))
            .route("/healthz/ready", web::get().to(readiness))
            .route("/healthz/live", web::get().to(liveness))
    })
    .bind(format!("0.0.0.0:{}", listen_port))?
    .run()
    .await
}
