use crate::copilot::copilot_quota_snapshot::CopilotQuotaSnapshot;
use serde::Deserialize;

#[derive(Clone, Debug, Deserialize)]
pub struct CopilotQuotaSnapshots {
    pub premium_interactions: Option<CopilotQuotaSnapshot>,
}

#[derive(Clone, Debug, Deserialize)]
pub struct CopilotUserPayload {
    pub copilot_plan: Option<String>,
    pub quota_reset_date_utc: Option<String>,
    pub quota_snapshots: Option<CopilotQuotaSnapshots>,
}
