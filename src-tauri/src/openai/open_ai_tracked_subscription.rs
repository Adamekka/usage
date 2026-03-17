use crate::openai::open_ai_rate_limit_status::OpenAiRateLimitStatus;
use serde::Serialize;

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct OpenAiTrackedSubscription {
    pub plan: String,
    pub unit: String,
    pub used: f64,
    pub limit: f64,
}

impl OpenAiTrackedSubscription {
    pub fn from_usage(
        plan_type: Option<&str>,
        rate_limit: Option<&OpenAiRateLimitStatus>,
    ) -> Result<Self, String> {
        let Some(primary_window) = rate_limit.and_then(|status| status.primary_window.as_ref())
        else {
            return Err(String::from(
                "OpenAI did not return the primary Codex usage window.",
            ));
        };

        Ok(Self {
            plan: display_plan(plan_type),
            unit: String::from("%"),
            used: primary_window.rounded_used_percent(),
            limit: 100.0,
        })
    }
}

fn display_plan(plan_type: Option<&str>) -> String {
    let Some(plan_type) = plan_type.map(str::trim).filter(|value| !value.is_empty()) else {
        return String::from("ChatGPT");
    };

    match plan_type {
        "free" => String::from("ChatGPT Free"),
        "plus" => String::from("ChatGPT Plus"),
        "pro" => String::from("ChatGPT Pro"),
        "team" => String::from("ChatGPT Team"),
        "edu" => String::from("ChatGPT Edu"),
        "enterprise" => String::from("ChatGPT Enterprise"),
        other => format!("ChatGPT {}", title_case(other)),
    }
}

fn title_case(value: &str) -> String {
    value
        .split(['_', '-', ' '])
        .filter(|segment| !segment.is_empty())
        .map(capitalize)
        .collect::<Vec<_>>()
        .join(" ")
}

fn capitalize(value: &str) -> String {
    let mut characters = value.chars();
    let Some(first) = characters.next() else {
        return String::new();
    };

    format!(
        "{}{}",
        first.to_ascii_uppercase(),
        characters.as_str().to_ascii_lowercase()
    )
}
