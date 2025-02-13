use serde::{Deserialize, Serialize};

#[derive(Clone, Deserialize)]
pub struct OIDCConfig {
    pub issuer_url: String,
    pub client_id: String,
    pub client_secret: String,
    pub redirect_uri: String,
}

impl OIDCConfig {
    pub fn from_env() -> Self {
        Self {
            issuer_url: std::env::var("OIDC_ISSUER_URL").expect("OIDC_ISSUER_URL must be set"),
            client_id: std::env::var("OIDC_CLIENT_ID").expect("OIDC_CLIENT_ID must be set"),
            client_secret: std::env::var("OIDC_CLIENT_SECRET")
                .expect("OIDC_CLIENT_SECRET must be set"),
            redirect_uri: std::env::var("OIDC_REDIRECT_URI")
                .expect("OIDC_REDIRECT_URI must be set"),
        }
    }
}

#[derive(Deserialize)]
pub struct TokenExchangeRequest {
    pub code: String,
    pub state: Option<String>,
}

#[derive(Serialize)]
pub struct TokenResponse {
    pub access_token: String,
    pub refresh_token: Option<String>,
    pub id_token: Option<String>,
    pub expires_in: i64,
    pub token_type: String,
}
