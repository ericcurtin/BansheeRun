//! C FFI bindings for macOS/iOS.
//!
//! These functions use standard C calling convention and can be called
//! from Swift via a bridging header.

use std::ffi::{c_char, CStr, CString};
use std::sync::Mutex;

use crate::{BansheeSession, Point, RunRecord};

static SESSION: Mutex<Option<BansheeSession>> = Mutex::new(None);

/// Initialize a BansheeSession from a JSON run record.
/// Returns: 0 on success, negative on error
#[no_mangle]
pub extern "C" fn banshee_init_session(json: *const c_char) -> i32 {
    if json.is_null() {
        return -1;
    }

    let json_str = unsafe {
        match CStr::from_ptr(json).to_str() {
            Ok(s) => s,
            Err(_) => return -1,
        }
    };

    let record: RunRecord = match RunRecord::from_json(json_str) {
        Ok(r) => r,
        Err(_) => return -2,
    };

    let session = BansheeSession::new(record.coordinates);

    if let Ok(mut guard) = SESSION.lock() {
        *guard = Some(session);
        0
    } else {
        -3
    }
}

/// Clear the current session.
#[no_mangle]
pub extern "C" fn banshee_clear_session() {
    if let Ok(mut guard) = SESSION.lock() {
        *guard = None;
    }
}

/// Check if the runner is behind the banshee.
/// Returns: 1 = behind, 0 = not behind, -1 = no session
#[no_mangle]
pub extern "C" fn banshee_is_behind(lat: f64, lon: f64, elapsed_ms: i64) -> i32 {
    if let Ok(guard) = SESSION.lock() {
        if let Some(ref session) = *guard {
            let point = Point::new(lat, lon, elapsed_ms as u64);
            if session.is_behind(&point, elapsed_ms as u64) {
                1
            } else {
                0
            }
        } else {
            -1
        }
    } else {
        -1
    }
}

/// Get pacing status.
/// Returns: 0 = Ahead, 1 = Behind, 2 = Unknown, -1 = no session
#[no_mangle]
pub extern "C" fn banshee_get_pacing_status(lat: f64, lon: f64, elapsed_ms: i64) -> i32 {
    use crate::banshee_session::PacingStatus;

    if let Ok(guard) = SESSION.lock() {
        if let Some(ref session) = *guard {
            let point = Point::new(lat, lon, elapsed_ms as u64);
            match session.get_pacing_status(&point, elapsed_ms as u64) {
                PacingStatus::Ahead => 0,
                PacingStatus::Behind => 1,
                PacingStatus::Unknown => 2,
            }
        } else {
            -1
        }
    } else {
        -1
    }
}

/// Get time difference in milliseconds.
/// Positive = ahead, negative = behind.
#[no_mangle]
pub extern "C" fn banshee_get_time_difference_ms(lat: f64, lon: f64, elapsed_ms: i64) -> i64 {
    if let Ok(guard) = SESSION.lock() {
        if let Some(ref session) = *guard {
            let point = Point::new(lat, lon, elapsed_ms as u64);
            session.get_time_difference_ms(&point, elapsed_ms as u64)
        } else {
            0
        }
    } else {
        0
    }
}

/// Get best run total distance in meters.
#[no_mangle]
pub extern "C" fn banshee_get_best_run_distance() -> f64 {
    if let Ok(guard) = SESSION.lock() {
        if let Some(ref session) = *guard {
            session.best_run_distance()
        } else {
            0.0
        }
    } else {
        0.0
    }
}

/// Get best run duration in milliseconds.
#[no_mangle]
pub extern "C" fn banshee_get_best_run_duration_ms() -> i64 {
    if let Ok(guard) = SESSION.lock() {
        if let Some(ref session) = *guard {
            session.best_run_duration_ms() as i64
        } else {
            0
        }
    } else {
        0
    }
}

/// Create a RunRecord JSON from parameters.
/// Returns a pointer to a C string that must be freed with banshee_free_string.
#[no_mangle]
pub extern "C" fn banshee_create_run_record_json(
    id: *const c_char,
    name: *const c_char,
    coords_json: *const c_char,
    recorded_at: i64,
) -> *mut c_char {
    if id.is_null() || name.is_null() || coords_json.is_null() {
        return std::ptr::null_mut();
    }

    let id_str = unsafe {
        match CStr::from_ptr(id).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => return std::ptr::null_mut(),
        }
    };

    let name_str = unsafe {
        match CStr::from_ptr(name).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => return std::ptr::null_mut(),
        }
    };

    let coords_str = unsafe {
        match CStr::from_ptr(coords_json).to_str() {
            Ok(s) => s,
            Err(_) => return std::ptr::null_mut(),
        }
    };

    let coords: Vec<Point> = match serde_json::from_str(coords_str) {
        Ok(c) => c,
        Err(_) => return std::ptr::null_mut(),
    };

    let record = RunRecord::new(id_str, name_str, coords, recorded_at as u64);

    match record.to_json() {
        Ok(json) => match CString::new(json) {
            Ok(s) => s.into_raw(),
            Err(_) => std::ptr::null_mut(),
        },
        Err(_) => std::ptr::null_mut(),
    }
}

/// Free a string allocated by the library.
#[no_mangle]
pub extern "C" fn banshee_free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe {
            drop(CString::from_raw(s));
        }
    }
}
