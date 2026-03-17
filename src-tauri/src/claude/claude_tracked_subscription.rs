use crate::claude::claude_usage_window::ClaudeUsageWindow;
use crate::claude::claude_usage_window_kind::ClaudeUsageWindowKind;
use serde::Serialize;

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ClaudeTrackedSubscription {
    pub plan: String,
    pub unit: String,
    pub used: f64,
    pub limit: f64,
}

impl ClaudeTrackedSubscription {
    pub fn from_usage(
        subscription_type: Option<&str>,
        windows: &[ClaudeUsageWindow],
    ) -> Result<Self, String> {
        let Some(session_window) = windows
            .iter()
            .find(|window| window.kind == ClaudeUsageWindowKind::Session)
        else {
            return Err(String::from(
                "Claude Code did not return the current session usage window.",
            ));
        };

        Ok(Self {
            plan: display_plan(subscription_type),
            unit: String::from("%"),
            used: session_window.rounded_used_percent(),
            limit: 100.0,
        })
    }
}

fn display_plan(subscription_type: Option<&str>) -> String {
    let Some(subscription_type) = subscription_type
        .map(str::trim)
        .filter(|value| !value.is_empty())
    else {
        return String::from("Claude");
    };

    match subscription_type {
        "pro" => String::from("Claude Pro"),
        "max" => String::from("Claude Max"),
        other => format!("Claude {}", title_case(other)),
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
