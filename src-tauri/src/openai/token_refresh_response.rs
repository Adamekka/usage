use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct TokenRefreshResponse {
    pub id_token: String,
    pub access_token: String,
    pub refresh_token: String,
}

impl TokenRefreshResponse {
    pub fn validate(mut self) -> Result<Self, String> {
        self.id_token = self.id_token.trim().to_owned();
        self.access_token = self.access_token.trim().to_owned();
        self.refresh_token = self.refresh_token.trim().to_owned();

        if self.id_token.is_empty() {
            return Err(String::from("Refresh response did not include `id_token`."));
        }

        if self.access_token.is_empty() {
            return Err(String::from(
                "Refresh response did not include `access_token`.",
            ));
        }

        if self.refresh_token.is_empty() {
            return Err(String::from(
                "Refresh response did not include `refresh_token`.",
            ));
        }

        Ok(self)
    }
}
