use axum::{
    routing::get,
    Router,
    http::StatusCode,
};

async fn health_status() -> StatusCode {
    StatusCode::OK
}

async fn oauth2_token() -> StatusCode {
    StatusCode::OK
}

#[tokio::main]
async fn main() {
    // Build our application with a single route
    let app = Router::new()
        .route("/health/status", get(health_status))
        .route("/oauth2/token", get(oauth2_token));

    // Run our application
    let listener = tokio::net::TcpListener::bind("localhost:3000").await.unwrap();
    println!("Server running on http://localhost:3000");
    axum::serve(listener, app).await.unwrap();
}