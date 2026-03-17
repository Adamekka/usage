use serde::Serialize;

#[derive(Debug, Serialize)]
pub struct TokenRefreshRequest {
    pub client_id: &'static str,
    pub grant_type: &'static str,
    pub refresh_token: String,
}

impl TokenRefreshRequest {
    pub fn new(refresh_token: String) -> Self {
        Self {
            client_id: "app_EMoamEEZ73f0CkXaXp7hrann",
            grant_type: "refresh_token",
            refresh_token,
        }
    }
}
