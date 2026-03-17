use crate::openai::open_ai_limit_window::OpenAiLimitWindow;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct OpenAiRateLimitStatus {
    #[serde(default)]
    pub allowed: bool,
    #[serde(default, alias = "limit_reached")]
    pub limit_reached: bool,
    #[serde(default, alias = "primary_window")]
    pub primary_window: Option<OpenAiLimitWindow>,
    #[serde(default, alias = "secondary_window")]
    pub secondary_window: Option<OpenAiLimitWindow>,
}
