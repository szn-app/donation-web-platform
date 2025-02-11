// https://docs.rs/tower/latest/tower/trait.Service.html

use axum::{
    extract::Query,
    http::StatusCode,
    response::{Html, IntoResponse},
    routing::{get, post},
    Router,
};
use std::net::SocketAddr;

#[tokio::main]
async fn main() {
    // Build our application with a single route
    let app = routes();

    // Run our application
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("Server running on http://0.0.0.0:3000");
    axum::serve(listener, app).await.unwrap();
}

fn routes() -> Router {
    fn ouath2_routes() -> Router {
        Router::new().route("/oauth2/token", get(oauth2_token))
    }

    Router::new()
        .route("/health/status", get(health_status))
        .merge(ouath2_routes())
        .fallback(handler_404)
}

#[derive(serde::Deserialize, Debug)]
struct params {
    client_id: Option<String>,
    client_secret: Option<String>,
    grant_type: Option<String>,
    code: Option<String>,
    redirect_uri: Option<String>,
}

async fn health_status(Query(params): Query<params>) -> impl IntoResponse {
    dbg!(&params);
    let id = params.client_id.as_deref().unwrap_or("NO ID RECEIVED");
    println!("--> Health status endpoint called with client_id: {}", id);

    Html(format!("Hello, {}", id)).into_response()
}

async fn oauth2_token() -> impl IntoResponse {
    println!("--> OAuth2 token endpoint called");
    StatusCode::OK
}

async fn handler_404() -> impl IntoResponse {
    println!("--> fallback 404 handler called");

    (
        StatusCode::NOT_FOUND,
        Html("<h1>404</h1><p>Nothing to see here</p>"),
    )
}
