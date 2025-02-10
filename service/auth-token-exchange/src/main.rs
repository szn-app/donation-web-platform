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
    let app = Router::new()
        .route("/health/status", get(health_status))
        .merge(ouath2_routes());

    // Run our application
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("Server running on http://0.0.0.0:3000");
    axum::serve(listener, app).await.unwrap();
}

fn ouath2_routes() -> Router {
    Router::new().route("/oauth2/token", get(oauth2_token))
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

    Html(format!("Hello, {}", id)).into_response()
    // StatusCode::OK
}

async fn oauth2_token() -> impl IntoResponse {
    StatusCode::OK
}
