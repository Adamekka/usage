use serde::Serialize;

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CopilotTrackedSubscription {
    pub plan: String,
    pub unit: String,
    pub used: f64,
    pub limit: f64,
}
