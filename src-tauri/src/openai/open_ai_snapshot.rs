use crate::openai::open_ai_credit_status::OpenAiCreditStatus;
use crate::openai::open_ai_rate_limit_status::OpenAiRateLimitStatus;
use crate::openai::open_ai_snapshot_status::OpenAiSnapshotStatus;
use crate::openai::open_ai_tracked_subscription::OpenAiTrackedSubscription;
use chrono::Utc;
use serde::Serialize;

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct OpenAiSnapshot {
    pub status: OpenAiSnapshotStatus,
    pub status_message: String,
    pub auth_path: String,
    pub auth_source: String,
    pub fetched_at: Option<String>,
    pub plan_type: Option<String>,
    pub rate_limit: Option<OpenAiRateLimitStatus>,
    pub code_review_rate_limit: Option<OpenAiRateLimitStatus>,
    pub credits: Option<OpenAiCreditStatus>,
    pub subscription: Option<OpenAiTrackedSubscription>,
}

impl OpenAiSnapshot {
    pub fn ready(
        auth_path: String,
        plan_type: Option<String>,
        rate_limit: Option<OpenAiRateLimitStatus>,
        code_review_rate_limit: Option<OpenAiRateLimitStatus>,
        credits: Option<OpenAiCreditStatus>,
        subscription: OpenAiTrackedSubscription,
    ) -> Self {
        Self {
            status: OpenAiSnapshotStatus::Ok,
            status_message: String::from(
                "Synced the current Codex usage windows from local ChatGPT auth.",
            ),
            auth_path,
            auth_source: String::from("codex"),
            fetched_at: Some(Utc::now().to_rfc3339()),
            plan_type,
            rate_limit,
            code_review_rate_limit,
            credits,
            subscription: Some(subscription),
        }
    }

    pub fn needs_auth(auth_path: String, status_message: String) -> Self {
        Self {
            status: OpenAiSnapshotStatus::NeedsAuth,
            status_message,
            auth_path,
            auth_source: String::from("codex"),
            fetched_at: None,
            plan_type: None,
            rate_limit: None,
            code_review_rate_limit: None,
            credits: None,
            subscription: None,
        }
    }

    pub fn auth_error(auth_path: String, status_message: String) -> Self {
        Self {
            status: OpenAiSnapshotStatus::AuthError,
            status_message,
            auth_path,
            auth_source: String::from("codex"),
            fetched_at: None,
            plan_type: None,
            rate_limit: None,
            code_review_rate_limit: None,
            credits: None,
            subscription: None,
        }
    }

    pub fn request_error(auth_path: String, status_message: String) -> Self {
        Self {
            status: OpenAiSnapshotStatus::RequestError,
            status_message,
            auth_path,
            auth_source: String::from("codex"),
            fetched_at: None,
            plan_type: None,
            rate_limit: None,
            code_review_rate_limit: None,
            credits: None,
            subscription: None,
        }
    }
}
