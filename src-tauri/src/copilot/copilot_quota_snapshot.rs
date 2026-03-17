use serde::Deserialize;

#[derive(Clone, Debug, Deserialize)]
pub struct CopilotQuotaSnapshot {
    pub entitlement: Option<u32>,
    pub remaining: Option<u32>,
    pub percent_remaining: Option<f64>,
    pub unlimited: Option<bool>,
}
