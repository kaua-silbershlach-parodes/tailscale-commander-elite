fn main() {
    tauri_build::try_build(tauri_build::Attributes::new().app_manifest(
        tauri_build::AppManifest::new().commands(&["connection_settings", "connection_save", "connection_clear", "tailscale_status", "tunnel_start", "tunnel_stop", "tunnel_status"])
    )).expect("Tauri build configuration");
}
