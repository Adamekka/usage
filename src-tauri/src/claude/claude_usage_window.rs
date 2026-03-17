use crate::claude::claude_usage_window_kind::ClaudeUsageWindowKind;
use serde::Serialize;

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ClaudeUsageWindow {
    pub kind: ClaudeUsageWindowKind,
    pub label: String,
    pub used_percent: f64,
    /// Unix timestamp of the reset moment, if parseable from the CLI output.
    pub reset_at: Option<i64>,
}

impl ClaudeUsageWindow {
    pub fn new(
        kind: ClaudeUsageWindowKind,
        label: String,
        used_percent: f64,
        reset_at: Option<i64>,
    ) -> Self {
        Self {
            kind,
            label,
            used_percent,
            reset_at,
        }
    }

    pub fn rounded_used_percent(&self) -> f64 {
        self.used_percent.round()
    }
}
