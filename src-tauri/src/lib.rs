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
mod security_tests;

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
