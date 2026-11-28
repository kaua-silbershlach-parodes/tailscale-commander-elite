//! Native desktop shell for Tailscale Commander Elite.
//!
//! This crate initializes the Tauri application, logging, signed updater and
//! restart support. The separate Elixir/OTP service is not started or managed
//! by this crate. The internal regression helpers are not a public API.

/// Starts the native application and enters the Tauri event loop.
///
/// A startup or application-run error is logged and terminates the process
/// with exit status 1. Explicit process exit does not run remaining stack
/// destructors; do not rely on them for application-wide shutdown guarantees.
/// This function is an application entry point, not a reusable background-service API.
///
/// # Examples
///
/// The entry-point signature can be checked without launching a window:
///
/// ```
/// let _entry_point: fn() = tailscale_commander_elite_lib::run;
/// ```
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
        serde_json::from_str(include_str!("../tauri.conf.json"))
            .expect("embedded Tauri configuration must be valid JSON")
    }

    fn secure_transport_options(updater: &Value) -> Result<(), &'static str> {
        if !updater.is_object() {
            return Err("updater must be an object");
        }
        for key in [
            "dangerousInsecureTransportProtocol",
            "dangerousAcceptInvalidCerts",
            "dangerousAcceptInvalidHostnames",
        ] {
            match updater.get(key) {
                None | Some(Value::Bool(false)) => {}
                Some(_) => return Err(key),
            }
        }
        Ok(())
    }

    const CSP_DIRECTIVES: [&str; 9] = [
        "default-src 'self'",
        "script-src 'self'",
        "style-src 'self'",
        "img-src 'self' data:",
        "connect-src 'self' ipc: http://ipc.localhost",
        "object-src 'none'",
        "base-uri 'none'",
        "frame-ancestors 'none'",
        "form-action 'none'",
    ];

    #[derive(Debug, PartialEq, Eq)]
    enum CspViolation<'a> {
        Unexpected(&'a str),
        Duplicate(&'a str),
        Missing(&'static str),
    }

    fn validate_csp(csp: &str) -> Result<(), CspViolation<'_>> {
        let mut seen = [false; CSP_DIRECTIVES.len()];
        for directive in csp.split(';').map(str::trim).filter(|d| !d.is_empty()) {
            let index = CSP_DIRECTIVES.iter().position(|expected| *expected == directive)
                .ok_or(CspViolation::Unexpected(directive))?;
            if seen[index] {
                return Err(CspViolation::Duplicate(directive));
            }
            seen[index] = true;
        }
        for (index, expected) in CSP_DIRECTIVES.iter().enumerate() {
            if !seen[index] {
                return Err(CspViolation::Missing(*expected));
            }
        }
        Ok(())
    }

    const UPDATE_ENDPOINT: &str = "https://github.com/kaua-silbershlach-parodes/tailscale-commander-elite/releases/latest/download/latest.json";
    const UPDATE_PUBLIC_KEY: &str = "dW50cnVzdGVkIGNvbW1lbnQ6IG1pbmlzaWduIHB1YmxpYyBrZXk6IDU3QzUzM0U0MzNGOTBGRUMKUldUc0Qva3o1RFBGVis3T09GT21wKzNGbFo3Nm9mMkZjWEJ3cldlWGpkU2F1dDFqdHZpL2Nad04K";

    #[derive(Debug, PartialEq, Eq)]
    enum UpdaterViolation {
        Transport(&'static str),
        SignedVersionRequired,
        DowngradesNotDenied,
        InvalidEndpoints,
        InvalidPublicKey,
    }

    // Test-only source configuration guard; not a signature verifier.
    fn validate_updater(updater: &Value) -> Result<(), UpdaterViolation> {
        secure_transport_options(updater).map_err(UpdaterViolation::Transport)?;
        match (updater.get("requireSignedVersion"), updater.get("allowDowngrades")) {
            (Some(Value::Bool(true)), Some(Value::Bool(false))) => {}
            (Some(Value::Bool(true)), _) => return Err(UpdaterViolation::DowngradesNotDenied),
            _ => return Err(UpdaterViolation::SignedVersionRequired),
        }
        match updater.get("endpoints").and_then(Value::as_array).map(Vec::as_slice) {
            Some([Value::String(endpoint)]) if endpoint.as_str() == UPDATE_ENDPOINT => {}
            _ => return Err(UpdaterViolation::InvalidEndpoints),
        }
        match updater.get("pubkey") {
            Some(Value::String(key)) if key.as_str() == UPDATE_PUBLIC_KEY => Ok(()),
            _ => Err(UpdaterViolation::InvalidPublicKey),
        }
    }

    #[test]
    fn updater_requires_signed_versions_and_denies_downgrades() {
        let c = config();
        assert_eq!(validate_updater(&c["plugins"]["updater"]), Ok(()));
    }

    #[test]
    fn updater_policy_rejects_each_invalid_shape_or_value() {
        use UpdaterViolation::*;
        let baseline = json!({
            "requireSignedVersion": true,
            "allowDowngrades": false,
            "endpoints": [UPDATE_ENDPOINT],
            "pubkey": UPDATE_PUBLIC_KEY
        });
        assert_eq!(validate_updater(&baseline), Ok(()));
        for (field, invalid, expected) in [
            ("requireSignedVersion", json!(false), SignedVersionRequired),
            ("requireSignedVersion", json!("true"), SignedVersionRequired),
            ("requireSignedVersion", Value::Null, SignedVersionRequired),
            ("allowDowngrades", json!(true), DowngradesNotDenied),
            ("allowDowngrades", json!("false"), DowngradesNotDenied),
            ("allowDowngrades", Value::Null, DowngradesNotDenied),
            ("endpoints", json!(UPDATE_ENDPOINT), InvalidEndpoints),
            ("endpoints", json!([]), InvalidEndpoints),
            ("endpoints", json!([UPDATE_ENDPOINT, UPDATE_ENDPOINT]), InvalidEndpoints),
            ("endpoints", json!([null]), InvalidEndpoints),
            ("endpoints", json!(["http://example.invalid/latest.json"]), InvalidEndpoints),
            ("endpoints", json!(["https://example.invalid/latest.json"]), InvalidEndpoints),
            ("pubkey", json!(""), InvalidPublicKey),
            ("pubkey", json!("different-public-key"), InvalidPublicKey),
            ("pubkey", json!(123), InvalidPublicKey),
            ("dangerousAcceptInvalidCerts", json!(true), Transport("dangerousAcceptInvalidCerts")),
        ] {
            let mut candidate = baseline.clone();
            candidate[field] = invalid;
            assert_eq!(validate_updater(&candidate), Err(expected), "invalid field: {field}");
        }
        for (field, expected) in [
            ("requireSignedVersion", SignedVersionRequired),
            ("allowDowngrades", DowngradesNotDenied),
            ("endpoints", InvalidEndpoints),
            ("pubkey", InvalidPublicKey),
        ] {
            let mut candidate = baseline.clone();
            candidate.as_object_mut().expect("object fixture").remove(field);
            assert_eq!(validate_updater(&candidate), Err(expected), "missing field: {field}");
        }
        assert_eq!(validate_updater(&Value::Null), Err(Transport("updater must be an object")));
    }

    #[test]
    fn webview_has_restrictive_csp() -> Result<(), String> {
        let c = config();
        let security = &c["app"]["security"];
        assert_eq!(security["freezePrototype"], true, "WebView prototypes must be frozen");
        let csp = security["csp"].as_str().ok_or("CSP must be a string")?;
        validate_csp(csp).map_err(|violation| format!("CSP policy violation: {violation:?}"))
    }

    #[test]
    fn csp_accepts_equivalent_directive_order_and_whitespace() {
        let ordered = CSP_DIRECTIVES.join("; ");
        let reversed = CSP_DIRECTIVES.iter().rev().copied().collect::<Vec<_>>().join(";\t");
        assert_eq!(validate_csp(&ordered), Ok(()), "canonical policy rejected");
        assert_eq!(validate_csp(&format!(" {reversed}; ")), Ok(()), "equivalent policy rejected");
    }

    #[test]
    fn csp_rejects_duplicate_extra_and_weakened_directives() {
        let valid = CSP_DIRECTIVES.join("; ");
        assert_eq!(validate_csp(&valid), Ok(()));
        assert_eq!(validate_csp(&format!("script-src *; {valid}")), Err(CspViolation::Unexpected("script-src *")));
        assert_eq!(validate_csp(&format!("{valid}; script-src 'self'")), Err(CspViolation::Duplicate("script-src 'self'")));
        assert_eq!(validate_csp(""), Err(CspViolation::Missing("default-src 'self'")));
        assert_eq!(validate_csp(&format!("{valid}; script-src-elem https:")), Err(CspViolation::Unexpected("script-src-elem https:")));
        assert_eq!(validate_csp(&valid.replace("style-src 'self'", "style-src *")), Err(CspViolation::Unexpected("style-src *")));
        assert_eq!(validate_csp(&valid.replace("img-src 'self' data:", "img-src *")), Err(CspViolation::Unexpected("img-src *")));
        assert_eq!(validate_csp(&valid.replace("object-src 'none'; ", "")), Err(CspViolation::Missing("object-src 'none'")));
    }

    #[test]
    fn csp_rejects_each_missing_required_directive() {
        for required in CSP_DIRECTIVES {
            let incomplete = CSP_DIRECTIVES.iter().copied()
                .filter(|directive| *directive != required)
                .collect::<Vec<_>>().join("; ");
            assert_eq!(validate_csp(&incomplete), Err(CspViolation::Missing(required)), "required directive: {required}");
        }
    }

    #[test]
    fn updater_rejects_non_object_transport_configuration() {
        for invalid in [Value::Null, json!([]), json!(false), json!(0), json!("updater")] {
            assert_eq!(secure_transport_options(&invalid), Err("updater must be an object"), "input: {invalid}");
        }
    }

    #[test]
    fn updater_rejects_insecure_or_malformed_transport_options() {
        assert_eq!(secure_transport_options(&json!({})), Ok(()));
        for key in [
            "dangerousInsecureTransportProtocol",
            "dangerousAcceptInvalidCerts",
            "dangerousAcceptInvalidHostnames",
        ] {
            let mut updater = json!({});
            updater[key] = json!(false);
            assert_eq!(secure_transport_options(&updater), Ok(()));
            for invalid in [json!(true), Value::Null, json!("false"), json!(0)] {
                updater[key] = invalid;
                assert_eq!(secure_transport_options(&updater), Err(key), "invalid option {key}: {}", updater[key]);
            }
        }
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

    #[derive(Debug, PartialEq, Eq)]
    enum VersionViolation {
        MissingShellVersion,
        ShellVersionMismatch,
        MissingBackendVersion,
        DuplicateBackendVersion,
        BackendVersionMismatch,
    }

    // This is an exact source-format guard for the current Mix manifest, not an Elixir parser.
    fn validate_candidate_versions(
        shell: &Value,
        cargo_version: &str,
        mix_manifest: &str,
    ) -> Result<(), VersionViolation> {
        let shell_version = shell["version"].as_str()
            .ok_or(VersionViolation::MissingShellVersion)?;
        if shell_version != cargo_version {
            return Err(VersionViolation::ShellVersionMismatch);
        }

        let mut declarations = mix_manifest.lines()
            .filter_map(|line| line.trim().strip_prefix("version:"));
        let backend = declarations.next()
            .ok_or(VersionViolation::MissingBackendVersion)?;
        if declarations.next().is_some() {
            return Err(VersionViolation::DuplicateBackendVersion);
        }
        // Borrow the version directly from the manifest instead of allocating a comparison string.
        let backend_version = backend.trim().strip_prefix('"')
            .and_then(|value| value.strip_suffix("\","));
        if backend_version != Some(cargo_version) {
            return Err(VersionViolation::BackendVersionMismatch);
        }
        Ok(())
    }

    #[test]
    fn candidate_version_is_consistent() {
        let c = config();
        let mix = include_str!("../../backend/mix.exs");
        assert_eq!(
            validate_candidate_versions(&c, env!("CARGO_PKG_VERSION"), mix),
            Ok(()),
            "Tauri, Cargo and Mix versions must agree"
        );
    }

    #[test]
    fn version_validation_rejects_missing_malformed_and_conflicting_metadata() {
        let valid = json!({"version": "1.2.3"});
        let mix = "  version: \"1.2.3\",\n";
        assert_eq!(validate_candidate_versions(&valid, "1.2.3", mix), Ok(()));
        for missing in [json!({}), json!({"version": null}), json!({"version": 123})] {
            assert_eq!(validate_candidate_versions(&missing, "1.2.3", mix), Err(VersionViolation::MissingShellVersion));
        }
        assert_eq!(validate_candidate_versions(&json!({"version":"1.2.4"}), "1.2.3", mix), Err(VersionViolation::ShellVersionMismatch));
        assert_eq!(validate_candidate_versions(&valid, "1.2.3", "# version: \"1.2.3\",\n"), Err(VersionViolation::MissingBackendVersion));
        assert_eq!(validate_candidate_versions(&valid, "1.2.3", "version: \"1.2.4\",\n"), Err(VersionViolation::BackendVersionMismatch));
        for malformed in ["version: 123,\n", "version: \"1.2.3\"\n", "version: \"1.2.3\", extra\n", "version: \"1.2.30\",\n"] {
            assert_eq!(validate_candidate_versions(&valid, "1.2.3", malformed), Err(VersionViolation::BackendVersionMismatch), "manifest: {malformed:?}");
        }
        for duplicate in [format!("{mix}{mix}"), format!("{mix}version: \"1.2.4\",\n")] {
            assert_eq!(validate_candidate_versions(&valid, "1.2.3", &duplicate), Err(VersionViolation::DuplicateBackendVersion));
        }
    }
}

#[cfg(all(test, target_os = "linux"))]
#[test]
fn glib_variant_string_iterator_backport_regression() {
    use glib::{prelude::*, Variant};

    // Compile-time contract for the existing borrowed-string iterator API.
    fn assert_iterator_contract<'a, I>(_: &I)
    where
        I: DoubleEndedIterator<Item = &'a str>
            + ExactSizeIterator
            + std::iter::FusedIterator,
    {
    }

    let v = Variant::array_from_iter::<String>(
        ["first", "second", "third", "fourth"].map(|s| s.to_variant())
    );
    let mut i = v.array_iter_str().unwrap();
    assert_iterator_contract(&i);
    assert_eq!(i.size_hint(), (4, Some(4)));
    assert_eq!(i.next(), Some("first"));
    assert_eq!(i.len(), 3);
    assert_eq!(i.next_back(), Some("fourth"));
    assert_eq!(i.len(), 2);
    assert_eq!(i.nth(0), Some("second"));
    assert_eq!(i.len(), 1);
    assert_eq!(i.nth_back(0), Some("third"));
    assert_eq!(i.size_hint(), (0, Some(0)));
    assert_eq!(i.next(), None);
    assert_eq!(i.next_back(), None);
    assert_eq!(i.next(), None);
    assert_eq!(v.array_iter_str().unwrap().last(), Some("fourth"));
    assert_eq!(v.array_iter_str().unwrap().count(), 4);

    // A borrowed string is tied to the owning Variant, not to the iterator.
    let retained = {
        let mut scoped = v.array_iter_str().unwrap();
        scoped.next().expect("nonempty fixture")
    };
    assert_eq!(retained, "first");

    // Independent iterators borrow the same owner without sharing cursor state.
    let mut left = v.array_iter_str().unwrap();
    let mut right = v.array_iter_str().unwrap();
    assert_eq!(left.nth(1), Some("second"));
    assert_eq!(right.nth_back(1), Some("third"));
    drop(left);
    assert_eq!(right.next(), Some("first"));
    assert_eq!(retained, "first");

    let text = Variant::array_from_iter::<String>(
        ["", "a\u{00e7}\u{00e3}o", "\u{1f680}"].map(|s| s.to_variant())
    );
    let borrowed = text.array_iter_str().unwrap().collect::<Vec<_>>();
    assert_eq!(borrowed, vec!["", "a\u{00e7}\u{00e3}o", "\u{1f680}"]);

    // Out-of-range skips must exhaust the iterator, including arithmetic overflow.
    for skip in [4, usize::MAX] {
        let mut forward = v.array_iter_str().unwrap();
        assert_eq!(forward.nth(skip), None);
        assert_eq!(forward.len(), 0);
        assert_eq!(forward.next_back(), None);

        let mut backward = v.array_iter_str().unwrap();
        assert_eq!(backward.nth_back(skip), None);
        assert_eq!(backward.len(), 0);
        assert_eq!(backward.next(), None);
    }
    let mut partially_consumed = v.array_iter_str().unwrap();
    assert_eq!(partially_consumed.next(), Some("first"));
    assert_eq!(partially_consumed.nth(usize::MAX), None);
    assert_eq!(partially_consumed.next_back(), None);

    let empty = Variant::array_from_iter::<String>(std::iter::empty::<Variant>());
    let mut empty_iter = empty.array_iter_str().unwrap();
    assert_eq!(empty_iter.size_hint(), (0, Some(0)));
    assert_eq!(empty_iter.next(), None);
    assert_eq!(empty_iter.next_back(), None);
}
