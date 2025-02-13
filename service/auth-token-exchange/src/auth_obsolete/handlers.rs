use axum::{extract::State, http::StatusCode, Json};
use openidconnect::{
    core::{CoreAuthenticationFlow, CoreClient, CoreProviderMetadata, CoreTokenResponse},
    reqwest::async_http_client,
    AuthorizationCode, ClientId, ClientSecret, IssuerUrl, RedirectUrl,
};
use std::sync::Arc;

use super::types::{OIDCConfig, TokenExchangeRequest, TokenResponse};

pub async fn token_exchange(
    State(config): State<Arc<OIDCConfig>>,
    Json(request): Json<TokenExchangeRequest>,
) -> Result<Json<TokenResponse>, StatusCode> {
    // Discover OIDC provider metadata
    let issuer_url =
        IssuerUrl::new(config.issuer_url.clone()).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let provider_metadata = CoreProviderMetadata::discover_async(issuer_url, async_http_client)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // Create OIDC client
    let client = CoreClient::from_provider_metadata(
        provider_metadata,
        ClientId::new(config.client_id.clone()),
        Some(ClientSecret::new(config.client_secret.clone())),
    )
    .set_redirect_uri(
        RedirectUrl::new(config.redirect_uri.clone())
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?,
    );

    // Exchange authorization code for tokens
    let token_response = client
        .exchange_code(AuthorizationCode::new(request.code))
        .request_async(async_http_client)
        .await
        .map_err(|_| StatusCode::BAD_REQUEST)?;

    // Convert to our response type
    Ok(Json(TokenResponse {
        access_token: token_response.access_token().secret().clone(),
        refresh_token: token_response
            .refresh_token()
            .map(|token| token.secret().clone()),
        id_token: token_response.id_token().map(|token| token.to_string()),
        expires_in: token_response.expires_in().unwrap_or_default().as_secs() as i64,
        token_type: "Bearer".to_string(),
    }))
}
