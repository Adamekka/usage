use crate::copilot::copilot_snapshot_status::CopilotSnapshotStatus;
use crate::copilot::copilot_tracked_subscription::CopilotTrackedSubscription;
use chrono::Utc;
use serde::Serialize;

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CopilotSnapshot {
    pub status: CopilotSnapshotStatus,
    pub status_message: String,
    pub auth_path: String,
    pub auth_source: String,
    pub fetched_at: Option<String>,
    pub plan: Option<String>,
    pub used_percent: Option<f64>,
    pub reset_at: Option<i64>,
    pub subscription: Option<CopilotTrackedSubscription>,
}

impl CopilotSnapshot {
    pub fn ready(
        auth_path: String,
        plan: String,
        used_percent: f64,
        reset_at: Option<i64>,
        subscription: CopilotTrackedSubscription,
    ) -> Self {
        Self {
            status: CopilotSnapshotStatus::Ok,
            status_message: String::from(
                "Synced the GitHub Copilot premium requests quota from GitHub CLI auth.",
            ),
            auth_path,
            auth_source: String::from("gh_cli"),
            fetched_at: Some(Utc::now().to_rfc3339()),
            plan: Some(plan),
            used_percent: Some(used_percent),
            reset_at,
            subscription: Some(subscription),
        }
    }

    pub fn needs_auth(auth_path: String, status_message: String) -> Self {
        Self {
            status: CopilotSnapshotStatus::NeedsAuth,
            status_message,
            auth_path,
            auth_source: String::from("gh_cli"),
            fetched_at: None,
            plan: None,
            used_percent: None,
            reset_at: None,
            subscription: None,
        }
    }

    pub fn auth_error(auth_path: String, status_message: String) -> Self {
        Self {
            status: CopilotSnapshotStatus::AuthError,
            status_message,
            auth_path,
            auth_source: String::from("gh_cli"),
            fetched_at: None,
            plan: None,
            used_percent: None,
            reset_at: None,
            subscription: None,
        }
    }

    pub fn request_error(auth_path: String, status_message: String) -> Self {
        Self {
            status: CopilotSnapshotStatus::RequestError,
            status_message,
            auth_path,
            auth_source: String::from("gh_cli"),
            fetched_at: None,
            plan: None,
            used_percent: None,
            reset_at: None,
            subscription: None,
        }
    }
}
