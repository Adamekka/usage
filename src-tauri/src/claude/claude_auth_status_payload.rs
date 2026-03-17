use serde::Deserialize;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ClaudeAuthStatusPayload {
    #[serde(default, alias = "loggedIn")]
    pub logged_in: bool,
    #[serde(default, alias = "authMethod")]
    pub auth_method: Option<String>,
    #[serde(default, alias = "apiProvider")]
    pub api_provider: Option<String>,
    #[serde(default)]
    pub email: Option<String>,
    #[serde(default, alias = "orgId")]
    pub org_id: Option<String>,
    #[serde(default, alias = "orgName")]
    pub org_name: Option<String>,
    #[serde(default, alias = "subscriptionType")]
    pub subscription_type: Option<String>,
}

impl ClaudeAuthStatusPayload {
    pub fn validate(mut self) -> Self {
        self.auth_method = self.auth_method.take().and_then(normalize_optional_string);
        self.api_provider = self.api_provider.take().and_then(normalize_optional_string);
        self.email = self.email.take().and_then(normalize_optional_string);
        self.org_id = self.org_id.take().and_then(normalize_optional_string);
        self.org_name = self.org_name.take().and_then(normalize_optional_string);
        self.subscription_type = self
            .subscription_type
            .take()
            .and_then(normalize_optional_string);

        self
    }
}

fn normalize_optional_string(value: String) -> Option<String> {
    let trimmed = value.trim();

    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_owned())
    }
}
