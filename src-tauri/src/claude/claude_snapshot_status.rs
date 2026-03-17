use serde::Serialize;

#[derive(Clone, Copy, Debug, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ClaudeSnapshotStatus {
    Ok,
    NeedsAuth,
    AuthError,
    RequestError,
}
