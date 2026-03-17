pub mod auth_dot_json;
pub mod open_ai_credit_status;
pub mod open_ai_limit_window;
pub mod open_ai_rate_limit_status;
pub mod open_ai_snapshot;
pub mod open_ai_snapshot_status;
pub mod open_ai_tracked_subscription;
pub mod open_ai_usage_payload;
pub mod token_bundle;
pub mod token_refresh_request;
pub mod token_refresh_response;

pub use open_ai_snapshot::OpenAiSnapshot;

use auth_dot_json::AuthDotJson;
use chrono::Utc;
use dirs::home_dir;
use open_ai_tracked_subscription::OpenAiTrackedSubscription;
use open_ai_usage_payload::OpenAiUsagePayload;
use reqwest::Client;
use serde_json::Value;
use std::fs;
use std::io::ErrorKind;
use std::path::{Path, PathBuf};
use std::time::Duration;
use token_refresh_request::TokenRefreshRequest;
use token_refresh_response::TokenRefreshResponse;

const OPENAI_USAGE_URL: &str = "https://chatgpt.com/backend-api/wham/usage";
const OPENAI_TOKEN_REFRESH_URL: &str = "https://auth.openai.com/oauth/token";

pub async fn fetch_snapshot() -> OpenAiSnapshot {
    let auth_path = auth_path();
    let auth_path_text = auth_path.display().to_string();
    let mut auth = match load_auth(&auth_path) {
        Ok(auth) => auth,
        Err(message) => {
            return OpenAiSnapshot::needs_auth(auth_path_text, message);
        }
    };

    match fetch_usage_with_refresh(&mut auth, &auth_path).await {
        Ok(payload) => match OpenAiTrackedSubscription::from_usage(
            payload.plan_type.as_deref(),
            payload.rate_limit.as_ref(),
        ) {
            Ok(subscription) => OpenAiSnapshot::ready(
                auth_path_text,
                payload.plan_type,
                payload.rate_limit,
                payload.code_review_rate_limit,
                payload.credits,
                subscription,
            ),
            Err(message) => OpenAiSnapshot::request_error(auth_path_text, message),
        },
        Err(message) if is_auth_error(&message) => {
            OpenAiSnapshot::auth_error(auth_path_text, strip_error_prefix(&message))
        }
        Err(message) => OpenAiSnapshot::request_error(auth_path_text, message),
    }
}

fn auth_path() -> PathBuf {
    if let Some(codex_home) = std::env::var_os("CODEX_HOME") {
        return PathBuf::from(codex_home).join("auth.json");
    }

    home_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join(".codex")
        .join("auth.json")
}

fn load_auth(auth_path: &Path) -> Result<AuthDotJson, String> {
    let raw_auth = fs::read_to_string(auth_path).map_err(|error| match error.kind() {
        ErrorKind::NotFound => format!(
            "Sign into Codex with ChatGPT first. Expected local auth at {}.",
            auth_path.display()
        ),
        _ => format!("Could not read {}: {error}", auth_path.display()),
    })?;

    let parsed_auth = serde_json::from_str::<AuthDotJson>(&raw_auth)
        .map_err(|error| format!("Could not parse {}: {error}", auth_path.display()))?;

    parsed_auth
        .validate()
        .map_err(|error| format!("Fix {} before syncing OpenAI: {error}", auth_path.display()))
}

async fn fetch_usage_with_refresh(
    auth: &mut AuthDotJson,
    auth_path: &Path,
) -> Result<OpenAiUsagePayload, String> {
    let client = Client::builder()
        .timeout(Duration::from_secs(20))
        .build()
        .map_err(|error| format!("Could not create an OpenAI HTTP client: {error}"))?;

    let mut response = send_usage_request(&client, auth.require_tokens()?).await?;

    if is_unauthorized(response.status().as_u16()) {
        let refreshed_tokens = refresh_tokens(&client, auth.require_tokens()?).await?;
        auth.tokens = Some(refreshed_tokens);
        auth.last_refresh = Some(Utc::now().to_rfc3339());
        save_auth(auth_path, auth)?;

        response = send_usage_request(&client, auth.require_tokens()?).await?;

        if is_unauthorized(response.status().as_u16()) {
            return Err(String::from(
                "AUTH_ERROR: OpenAI rejected the refreshed Codex login. Run `codex` and sign in again.",
            ));
        }
    }

    parse_usage_response(response).await
}

fn save_auth(auth_path: &Path, auth: &AuthDotJson) -> Result<(), String> {
    let serialized = serde_json::to_string_pretty(auth)
        .map_err(|error| format!("Could not serialize refreshed auth.json: {error}"))?;

    fs::write(auth_path, format!("{serialized}\n"))
        .map_err(|error| format!("Could not update {}: {error}", auth_path.display()))
}

async fn send_usage_request(
    client: &Client,
    tokens: &crate::openai::token_bundle::TokenBundle,
) -> Result<reqwest::Response, String> {
    let mut request = client
        .get(OPENAI_USAGE_URL)
        .header("Authorization", format!("Bearer {}", tokens.access_token))
        .header("User-Agent", "usage-tauri");

    if let Some(account_id) = tokens.account_id.as_deref() {
        request = request.header("ChatGPT-Account-Id", account_id);
    }

    request
        .send()
        .await
        .map_err(|error| format!("Could not reach the OpenAI usage endpoint: {error}"))
}

async fn refresh_tokens(
    client: &Client,
    existing_tokens: &crate::openai::token_bundle::TokenBundle,
) -> Result<crate::openai::token_bundle::TokenBundle, String> {
    let response = client
        .post(OPENAI_TOKEN_REFRESH_URL)
        .header("User-Agent", "usage-tauri")
        .json(&TokenRefreshRequest::new(
            existing_tokens.refresh_token.clone(),
        ))
        .send()
        .await
        .map_err(|error| format!("Could not refresh the Codex login: {error}"))?;

    let status = response.status();

    if !status.is_success() {
        let body_text = response.text().await.unwrap_or_default();
        let error_message = extract_response_message(&body_text);

        if is_unauthorized(status.as_u16()) || status.as_u16() == 400 {
            return Err(format!(
                "AUTH_ERROR: OpenAI could not refresh the Codex login. {error_message}"
            ));
        }

        return Err(format!(
            "OpenAI token refresh failed with {}. {error_message}",
            status.as_u16()
        ));
    }

    let refreshed = response
        .json::<TokenRefreshResponse>()
        .await
        .map_err(|error| format!("Could not parse the token refresh response: {error}"))?
        .validate()?;

    Ok(existing_tokens.refreshed(refreshed))
}

async fn parse_usage_response(response: reqwest::Response) -> Result<OpenAiUsagePayload, String> {
    let status = response.status();

    if !status.is_success() {
        let body_text = response.text().await.unwrap_or_default();
        let error_message = extract_response_message(&body_text);

        if is_unauthorized(status.as_u16()) {
            return Err(format!(
                "AUTH_ERROR: OpenAI rejected the Codex login. {error_message}"
            ));
        }

        return Err(format!(
            "OpenAI usage request failed with {}. {error_message}",
            status.as_u16()
        ));
    }

    response
        .json::<OpenAiUsagePayload>()
        .await
        .map_err(|error| format!("Could not parse the OpenAI usage response: {error}"))
}

fn is_unauthorized(status_code: u16) -> bool {
    status_code == 401 || status_code == 403
}

fn extract_response_message(body_text: &str) -> String {
    let parsed_body = serde_json::from_str::<Value>(body_text).ok();

    if let Some(message) = parsed_body
        .as_ref()
        .and_then(|value| value.get("error_description"))
        .and_then(Value::as_str)
    {
        return message.trim().to_owned();
    }

    if let Some(message) = parsed_body
        .as_ref()
        .and_then(|value| value.get("error"))
        .and_then(|value| {
            if value.is_object() {
                value.get("message")
            } else {
                Some(value)
            }
        })
        .and_then(Value::as_str)
    {
        return message.trim().to_owned();
    }

    let trimmed_body = body_text.trim();

    if trimmed_body.is_empty() {
        return String::from("No error details were returned.");
    }

    trimmed_body.to_owned()
}

fn is_auth_error(message: &str) -> bool {
    message.starts_with("AUTH_ERROR: ")
}

fn strip_error_prefix(message: &str) -> String {
    message.trim_start_matches("AUTH_ERROR: ").to_owned()
}
