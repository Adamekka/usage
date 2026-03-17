mod claude;
mod openai;

use claude::ClaudeSnapshot;
use openai::OpenAiSnapshot;

#[tauri::command]
async fn fetch_openai_snapshot() -> OpenAiSnapshot {
    openai::fetch_snapshot().await
}

#[tauri::command]
async fn fetch_claude_snapshot() -> ClaudeSnapshot {
    claude::fetch_snapshot().await
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            fetch_openai_snapshot,
            fetch_claude_snapshot
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
