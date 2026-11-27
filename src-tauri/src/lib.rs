#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let log_level = if cfg!(debug_assertions) {
        log::LevelFilter::Info
    } else {
        log::LevelFilter::Warn
    };

    let result = tauri::Builder::default()
        .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(tauri_plugin_process::init())
        .plugin(
            tauri_plugin_log::Builder::default()
                .level(log_level)
                .build(),
        )
        .run(tauri::generate_context!());

    if let Err(err) = result {
        log::error!("error while running the application: {err}");
        std::process::exit(1);
    }
}

#[cfg(test)]
mod security_tests {
    use serde_json::{json, Value};

    fn config() -> Value {
        serde_json::from_str(include_str!("../tauri.conf.json")).unwrap()
    }

    #[test]
    fn updater_requires_signed_versions_and_denies_downgrades() {
        let c = config();
        let u = &c["plugins"]["updater"];
        assert_eq!(u["requireSignedVersion"], true);
        assert_eq!(u["allowDowngrades"], false);
        for key in ["dangerousInsecureTransportProtocol", "dangerousAcceptInvalidCerts",
                    "dangerousAcceptInvalidHostnames"] {
            assert!(u[key].is_null() || u[key] == false);
        }
        assert_eq!(u["endpoints"], json!(["https://github.com/kaua-silbershlach-parodes/tailscale-commander-elite/releases/latest/download/latest.json"]));
        assert_eq!(u["pubkey"], "dW50cnVzdGVkIGNvbW1lbnQ6IG1pbmlzaWduIHB1YmxpYyBrZXk6IDU3QzUzM0U0MzNGOTBGRUMKUldUc0Qva3o1RFBGVis3T09GT21wKzNGbFo3Nm9mMkZjWEJ3cldlWGpkU2F1dDFqdHZpL2Nad04K");
    }

    #[test]
    fn webview_has_restrictive_csp() {
        let c = config();
        let security = &c["app"]["security"];
        assert_eq!(security["freezePrototype"], true);
        let csp = security["csp"].as_str().unwrap();
        for directive in ["default-src 'self'", "script-src 'self'", "object-src 'none'",
                          "base-uri 'none'", "frame-ancestors 'none'", "form-action 'none'",
                          "connect-src 'self' ipc: http://ipc.localhost"] {
            assert!(csp.split(';').any(|d| d.trim() == directive), "{directive}");
        }
        assert!(!csp.contains("unsafe-eval") && !csp.contains("unsafe-inline"));
    }

    #[test]
    fn main_window_has_only_declared_capabilities() {
        let c = config();
        let cap: Value = serde_json::from_str(include_str!("../capabilities/default.json")).unwrap();
        assert_eq!(cap["windows"], json!(["main"]));
        assert_eq!(cap["permissions"], json!(["core:app:allow-version", "updater:default", "process:allow-restart"]));
        assert_eq!(c["app"]["windows"].as_array().unwrap().len(), 1);
        assert_eq!(c["app"]["windows"][0]["label"], "main");
        assert_eq!(c["bundle"]["windows"]["nsis"]["installMode"], "currentUser");
    }

    #[test]
    fn candidate_version_is_consistent() {
        let c = config();
        let version = c["version"].as_str().unwrap();
        assert_eq!(version, env!("CARGO_PKG_VERSION"));
        let mix = include_str!("../../backend/mix.exs");
        assert!(mix.lines().any(|line| line.trim() == format!("version: \"{version}\",")));
    }
}

#[cfg(all(test, target_os = "linux"))]
#[test]
fn glib_variant_string_iterator_backport_regression() {
    use glib::{prelude::*, Variant};
    let v = Variant::array_from_iter::<String>(
        ["first", "second", "third", "fourth"].map(|s| s.to_variant())
    );
    let mut i = v.array_iter_str().unwrap();
    assert_eq!(i.next(), Some("first"));
    assert_eq!(i.next_back(), Some("fourth"));
    assert_eq!(i.nth(0), Some("second"));
    assert_eq!(i.nth_back(0), Some("third"));
    assert_eq!(i.next(), None);
    assert_eq!(v.array_iter_str().unwrap().last(), Some("fourth"));
}
