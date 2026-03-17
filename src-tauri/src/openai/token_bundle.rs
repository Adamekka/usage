use crate::openai::token_refresh_response::TokenRefreshResponse;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct TokenBundle {
    pub id_token: String,
    pub access_token: String,
    pub refresh_token: String,
    #[serde(default)]
    pub account_id: Option<String>,
}

impl TokenBundle {
    pub fn validate(mut self) -> Result<Self, String> {
        self.id_token = self.id_token.trim().to_owned();
        self.access_token = self.access_token.trim().to_owned();
        self.refresh_token = self.refresh_token.trim().to_owned();
        self.account_id = self.account_id.take().and_then(normalize_optional_string);

        if self.id_token.is_empty() {
            return Err(String::from("`tokens.id_token` is missing."));
        }

        if self.access_token.is_empty() {
            return Err(String::from("`tokens.access_token` is missing."));
        }

        if self.refresh_token.is_empty() {
            return Err(String::from("`tokens.refresh_token` is missing."));
        }

        Ok(self)
    }

    pub fn refreshed(&self, response: TokenRefreshResponse) -> Self {
        Self {
            id_token: response.id_token,
            access_token: response.access_token,
            refresh_token: response.refresh_token,
            account_id: self.account_id.clone(),
        }
    }
}

fn normalize_optional_string(value: String) -> Option<String> {
    let trimmed = value.trim();

    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_owned())
    }
}
