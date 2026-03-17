use crate::claude::claude_auth_status_payload::ClaudeAuthStatusPayload;
use crate::claude::claude_snapshot_status::ClaudeSnapshotStatus;
use crate::claude::claude_tracked_subscription::ClaudeTrackedSubscription;
use crate::claude::claude_usage_window::ClaudeUsageWindow;
use chrono::Utc;
use serde::Serialize;

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ClaudeSnapshot {
    pub status: ClaudeSnapshotStatus,
    pub status_message: String,
    pub auth_path: String,
    pub auth_source: String,
    pub fetched_at: Option<String>,
    pub email: Option<String>,
    pub organization_id: Option<String>,
    pub organization_name: Option<String>,
    pub subscription_type: Option<String>,
    pub windows: Vec<ClaudeUsageWindow>,
    pub subscription: Option<ClaudeTrackedSubscription>,
}

impl ClaudeSnapshot {
    pub fn ready(
        auth_path: String,
        auth_status: ClaudeAuthStatusPayload,
        windows: Vec<ClaudeUsageWindow>,
        subscription: ClaudeTrackedSubscription,
    ) -> Self {
        Self {
            status: ClaudeSnapshotStatus::Ok,
            status_message: String::from(
                "Synced the current Claude Code session and weekly usage windows from local auth.",
            ),
            auth_path,
            auth_source: String::from("claude_code"),
            fetched_at: Some(Utc::now().to_rfc3339()),
            email: auth_status.email,
            organization_id: auth_status.org_id,
            organization_name: auth_status.org_name,
            subscription_type: auth_status.subscription_type,
            windows,
            subscription: Some(subscription),
        }
    }

    pub fn needs_auth(auth_path: String, status_message: String) -> Self {
        Self {
            status: ClaudeSnapshotStatus::NeedsAuth,
            status_message,
            auth_path,
            auth_source: String::from("claude_code"),
            fetched_at: None,
            email: None,
            organization_id: None,
            organization_name: None,
            subscription_type: None,
            windows: Vec::new(),
            subscription: None,
        }
    }

    pub fn auth_error(auth_path: String, status_message: String) -> Self {
        Self {
            status: ClaudeSnapshotStatus::AuthError,
            status_message,
            auth_path,
            auth_source: String::from("claude_code"),
            fetched_at: None,
            email: None,
            organization_id: None,
            organization_name: None,
            subscription_type: None,
            windows: Vec::new(),
            subscription: None,
        }
    }

    pub fn request_error(auth_path: String, status_message: String) -> Self {
        Self {
            status: ClaudeSnapshotStatus::RequestError,
            status_message,
            auth_path,
            auth_source: String::from("claude_code"),
            fetched_at: None,
            email: None,
            organization_id: None,
            organization_name: None,
            subscription_type: None,
            windows: Vec::new(),
            subscription: None,
        }
    }
}
