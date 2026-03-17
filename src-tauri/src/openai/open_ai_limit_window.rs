use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct OpenAiLimitWindow {
    #[serde(alias = "used_percent")]
    pub used_percent: f64,
    #[serde(default, alias = "limit_window_seconds")]
    pub limit_window_seconds: Option<u64>,
    #[serde(default, alias = "reset_after_seconds")]
    pub reset_after_seconds: Option<i64>,
    #[serde(default, alias = "reset_at")]
    pub reset_at: Option<i64>,
}

impl OpenAiLimitWindow {
    pub fn rounded_used_percent(&self) -> f64 {
        self.used_percent.round()
    }
}
