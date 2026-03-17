mod openai;

use openai::OpenAiSnapshot;

#[tauri::command]
async fn fetch_openai_snapshot() -> OpenAiSnapshot {
    openai::fetch_snapshot().await
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![fetch_openai_snapshot])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
