use crate::openai::open_ai_credit_status::OpenAiCreditStatus;
use crate::openai::open_ai_rate_limit_status::OpenAiRateLimitStatus;
use serde::Deserialize;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OpenAiUsagePayload {
    #[serde(default, alias = "plan_type")]
    pub plan_type: Option<String>,
    #[serde(default, alias = "rate_limit")]
    pub rate_limit: Option<OpenAiRateLimitStatus>,
    #[serde(default, alias = "code_review_rate_limit")]
    pub code_review_rate_limit: Option<OpenAiRateLimitStatus>,
    #[serde(default)]
    pub credits: Option<OpenAiCreditStatus>,
}
