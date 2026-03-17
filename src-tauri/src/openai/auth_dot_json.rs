use crate::openai::token_bundle::TokenBundle;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::BTreeMap;

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct AuthDotJson {
    #[serde(rename = "OPENAI_API_KEY", default)]
    pub openai_api_key: Option<String>,
    #[serde(default)]
    pub auth_mode: Option<String>,
    #[serde(default)]
    pub tokens: Option<TokenBundle>,
    #[serde(default)]
    pub last_refresh: Option<String>,
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

impl AuthDotJson {
    pub fn validate(mut self) -> Result<Self, String> {
        self.openai_api_key = self
            .openai_api_key
            .take()
            .and_then(normalize_optional_string);
        self.auth_mode = self.auth_mode.take().and_then(normalize_optional_string);
        self.last_refresh = self.last_refresh.take().and_then(normalize_optional_string);
        self.tokens = self.tokens.take().map(TokenBundle::validate).transpose()?;

        Ok(self)
    }

    pub fn require_tokens(&self) -> Result<&TokenBundle, String> {
        if let Some(tokens) = self.tokens.as_ref() {
            return Ok(tokens);
        }

        if self.openai_api_key.is_some() {
            return Err(String::from(
                "Codex is using API-key auth. Sign into Codex with ChatGPT to read subscription limits.",
            ));
        }

        Err(String::from(
            "Sign into Codex with ChatGPT first so auth.json contains OAuth tokens.",
        ))
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
