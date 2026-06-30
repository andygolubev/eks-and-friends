use actix_web::{web, App, HttpServer, HttpResponse, middleware};
use serde::{Deserialize, Serialize};
use std::env;
use tokio_postgres::NoTls;

#[derive(Serialize)]
struct HealthResponse {
    status: String,
    service: String,
    db_connected: bool,
}

#[derive(Serialize)]
struct Product {
    id: i32,
    name: String,
    description: String,
    price_cents: i32,
    category: String,
    emoji: String,
    stock: i32,
}

#[derive(Deserialize)]
struct OrderLineRequest {
    product_id: i32,
    quantity: i32,
}

#[derive(Deserialize)]
struct CreateOrderRequest {
    customer: String,
    items: Vec<OrderLineRequest>,
}

#[derive(Serialize)]
struct OrderResponse {
    id: i32,
    customer: String,
    total_cents: i32,
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

fn map_product(row: &tokio_postgres::Row) -> Product {
    Product {
        id: row.get("id"),
        name: row.get("name"),
        description: row.get("description"),
        price_cents: row.get("price_cents"),
        category: row.get("category"),
        emoji: row.get("emoji"),
        stock: row.get("stock"),
    }
}

async fn get_products(data: web::Data<AppState>) -> HttpResponse {
    match get_db_client(&data.db_url).await {
        Ok(client) => {
            match client
                .query(
                    "SELECT id, name, description, price_cents, category, emoji, stock \
                     FROM products ORDER BY id",
                    &[],
                )
                .await
            {
                Ok(rows) => {
                    let products: Vec<Product> = rows.iter().map(map_product).collect();
                    HttpResponse::Ok().json(products)
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

async fn get_product(path: web::Path<i32>, data: web::Data<AppState>) -> HttpResponse {
    let id = path.into_inner();
    match get_db_client(&data.db_url).await {
        Ok(client) => {
            match client
                .query_opt(
                    "SELECT id, name, description, price_cents, category, emoji, stock \
                     FROM products WHERE id = $1",
                    &[&id],
                )
                .await
            {
                Ok(Some(row)) => HttpResponse::Ok().json(map_product(&row)),
                Ok(None) => HttpResponse::NotFound().json(serde_json::json!({"error": "not found"})),
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

async fn create_order(body: web::Json<CreateOrderRequest>, data: web::Data<AppState>) -> HttpResponse {
    if body.items.is_empty() {
        return HttpResponse::BadRequest().json(serde_json::json!({"error": "cart is empty"}));
    }

    let mut client = match get_db_client(&data.db_url).await {
        Ok(c) => c,
        Err(e) => {
            log::error!("DB connect error: {}", e);
            return HttpResponse::ServiceUnavailable().json(serde_json::json!({"error": "db unavailable"}));
        }
    };

    let tx = match client.transaction().await {
        Ok(t) => t,
        Err(e) => {
            log::error!("tx error: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({"error": "tx failed"}));
        }
    };

    // Create the order row first with a zero total, then accumulate as we add lines.
    let order_row = match tx
        .query_one(
            "INSERT INTO orders (customer, total_cents) VALUES ($1, 0) RETURNING id",
            &[&body.customer],
        )
        .await
    {
        Ok(r) => r,
        Err(e) => {
            log::error!("insert order error: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({"error": "could not create order"}));
        }
    };
    let order_id: i32 = order_row.get("id");

    let mut total_cents: i32 = 0;
    for line in &body.items {
        if line.quantity <= 0 {
            continue;
        }
        let product = match tx
            .query_opt(
                "SELECT name, price_cents FROM products WHERE id = $1",
                &[&line.product_id],
            )
            .await
        {
            Ok(Some(p)) => p,
            Ok(None) => {
                let _ = tx.rollback().await;
                return HttpResponse::BadRequest()
                    .json(serde_json::json!({"error": format!("unknown product {}", line.product_id)}));
            }
            Err(e) => {
                log::error!("lookup error: {}", e);
                let _ = tx.rollback().await;
                return HttpResponse::InternalServerError().json(serde_json::json!({"error": "lookup failed"}));
            }
        };

        let name: String = product.get("name");
        let price_cents: i32 = product.get("price_cents");
        let line_total = price_cents * line.quantity;
        total_cents += line_total;

        if let Err(e) = tx
            .execute(
                "INSERT INTO order_items (order_id, product_id, product_name, quantity, price_cents) \
                 VALUES ($1, $2, $3, $4, $5)",
                &[&order_id, &line.product_id, &name, &line.quantity, &price_cents],
            )
            .await
        {
            log::error!("insert line error: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({"error": "could not add line item"}));
        }
    }

    if let Err(e) = tx
        .execute("UPDATE orders SET total_cents = $1 WHERE id = $2", &[&total_cents, &order_id])
        .await
    {
        log::error!("update total error: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(serde_json::json!({"error": "could not finalize order"}));
    }

    if let Err(e) = tx.commit().await {
        log::error!("commit error: {}", e);
        return HttpResponse::InternalServerError().json(serde_json::json!({"error": "commit failed"}));
    }

    HttpResponse::Ok().json(OrderResponse {
        id: order_id,
        customer: body.customer.clone(),
        total_cents,
    })
}

async fn get_orders(data: web::Data<AppState>) -> HttpResponse {
    match get_db_client(&data.db_url).await {
        Ok(client) => {
            match client
                .query("SELECT id, customer, total_cents FROM orders ORDER BY id DESC", &[])
                .await
            {
                Ok(rows) => {
                    let orders: Vec<OrderResponse> = rows
                        .iter()
                        .map(|row| OrderResponse {
                            id: row.get("id"),
                            customer: row.get("customer"),
                            total_cents: row.get("total_cents"),
                        })
                        .collect();
                    HttpResponse::Ok().json(orders)
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

    log::info!("Starting backend (shop) on port {}", listen_port);

    let data = web::Data::new(AppState { db_url });

    HttpServer::new(move || {
        App::new()
            .app_data(data.clone())
            .wrap(middleware::Logger::default())
            .route("/api/health", web::get().to(health))
            .route("/api/products", web::get().to(get_products))
            .route("/api/products/{id}", web::get().to(get_product))
            .route("/api/orders", web::get().to(get_orders))
            .route("/api/orders", web::post().to(create_order))
            .route("/healthz/ready", web::get().to(readiness))
            .route("/healthz/live", web::get().to(liveness))
    })
    .bind(format!("0.0.0.0:{}", listen_port))?
    .run()
    .await
}
