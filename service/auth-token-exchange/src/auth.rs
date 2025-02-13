use axum::{
    extract::{Form, Query},
    http::StatusCode,
    response::{Html, IntoResponse},
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::net::SocketAddr;

#[derive(serde::Deserialize, Debug)]
pub struct Params {
    pub client_id: Option<String>,
    pub client_secret: Option<String>,
    pub grant_type: Option<String>,
    pub code: Option<String>,
    pub redirect_uri: Option<String>,
}

#[derive(Debug, serde::Deserialize, serde::Serialize)]
pub struct TokenRequest {
    pub code: String,
    pub redirect_uri: String,
}

#[derive(Debug, serde::Serialize, serde::Deserialize)]
pub struct TokenResponse {
    pub access_token: String,
    pub token_type: String,
    pub expires_in: i32,
    pub scope: String,
}

pub fn routes() -> Router {
    fn ouath2_routes() -> Router {
        Router::new()
            .route("/oauth2_token", get(oauth2_token))
            .route("/oauth2_token", post(oauth2_token))
    }

    Router::new()
        .route("/health/status", get(health_status))
        .merge(ouath2_routes())
        .fallback(handler_404)
}

pub async fn health_status(Query(params): Query<Params>) -> impl IntoResponse {
    dbg!(&params);
    let id = params.client_id.as_deref().unwrap_or("NO ID RECEIVED");
    println!("--> Health status endpoint called with client_id: {}", id);

    Html(format!("Hello, {}", id)).into_response()
}

// OIDC Relying Party (RP) logic
// TODO: use proper tracing library for production
pub async fn oauth2_token(form: Form<TokenRequest>) -> impl IntoResponse {
    println!("--> oauth2_token endpoint called with payload: {:?}", form);

    let hydra_token_url = "http://hydra-admin/oauth2/token";

    let client = reqwest::Client::builder()
        .http2_prior_knowledge()
        .build()
        .unwrap();
    let response = client
        .post(hydra_token_url)
        .form(&[
            ("grant_type", "authorization_code"),
            ("code", &form.code),
            ("redirect_uri", &form.redirect_uri),
            ("client_id", "frontend-client-oauth"),
            ("client_secret", "your-client-secret"),
        ])
        .send()
        .await;

    println!("--> before response");
    match response {
        Ok(res) => match res.json::<TokenResponse>().await {
            Ok(token) => {
                println!("--> Token received: {:?}", token);
                Json(token).into_response()
            }
            Err(_) => {
                println!("--> Failed to parse token response");
                StatusCode::INTERNAL_SERVER_ERROR.into_response()
            }
        },
        Err(_) => {
            println!("--> Request to hydra token endpoint failed");
            StatusCode::INTERNAL_SERVER_ERROR.into_response()
        }
    }
}

pub async fn handler_404() -> impl IntoResponse {
    println!("--> fallback 404 handler called");

    (
        StatusCode::NOT_FOUND,
        Html("<h1>404</h1><p>Nothing to see here</p>"),
    )
}
