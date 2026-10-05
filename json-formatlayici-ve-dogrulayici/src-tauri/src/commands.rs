use notify::{Config, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use std::path::Path;
use std::sync::mpsc;
use std::{fs, thread};
use tauri::{AppHandle, Emitter};

#[derive(Clone, serde::Serialize)]
struct FileUpdatedPayload {
    path: String,
    content: String,
}

#[tauri::command]
pub fn read_text_file(path: String) -> Result<String, String> {
    fs::read_to_string(&path).map_err(|e| e.to_string())
}

#[tauri::command]
pub fn start_file_watch(app: AppHandle, path: String) -> Result<(), String> {
    let path_buf = Path::new(&path).to_path_buf();
    if !path_buf.is_file() {
        return Err("Dosya bulunamadı".into());
    }

    let (tx, rx) = mpsc::channel();
    let mut watcher =
        RecommendedWatcher::new(tx, Config::default()).map_err(|e| e.to_string())?;
    watcher
        .watch(&path_buf, RecursiveMode::NonRecursive)
        .map_err(|e| e.to_string())?;

    // İzleyici bu thread'e taşınarak canlı tutulur; her yazma olayında dosya yeniden okunup
    // "file-updated" olayıyla (path + içerik) webview'a gönderilir. İzleyiciler durdurulmaz,
    // bu yüzden JS tarafı olayları path'e göre süzer.
    let watch_path = path.clone();
    thread::spawn(move || {
        let _watcher = watcher;
        while let Ok(event) = rx.recv() {
            if let Ok(ev) = event {
                let is_write = matches!(
                    ev.kind,
                    EventKind::Modify(_) | EventKind::Create(_) | EventKind::Any
                );
                if is_write {
                    if let Ok(content) = fs::read_to_string(&watch_path) {
                        let _ = app.emit(
                            "file-updated",
                            FileUpdatedPayload {
                                path: watch_path.clone(),
                                content,
                            },
                        );
                    }
                }
            }
        }
    });

    Ok(())
}
