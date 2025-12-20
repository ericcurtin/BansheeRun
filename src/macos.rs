//! C FFI bindings for macOS/iOS.
//!
//! These functions use standard C calling convention and can be called
//! from Swift via a bridging header.

use std::ffi::{c_char, CStr, CString};
use std::sync::Mutex;

use crate::{
    Activity, ActivityIndex, ActivitySummary, ActivityType, BansheeSession, PBCalculator,
    PersonalBests, Point, RunRecord,
};

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

// ============================================================================
// Activity and Personal Best FFI Functions
// ============================================================================

/// Create an Activity JSON with the specified type.
/// activity_type: 0=Run, 1=Walk, 2=Cycle
/// Returns a pointer to a JSON string that must be freed with banshee_free_string.
#[no_mangle]
pub extern "C" fn banshee_create_activity_json(
    id: *const c_char,
    name: *const c_char,
    activity_type: i32,
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

    let act_type = match ActivityType::from_int(activity_type) {
        Some(t) => t,
        None => return std::ptr::null_mut(),
    };

    let activity = Activity::new(id_str, name_str, act_type, coords, recorded_at as u64);

    match activity.to_json() {
        Ok(json) => match CString::new(json) {
            Ok(s) => s.into_raw(),
            Err(_) => std::ptr::null_mut(),
        },
        Err(_) => std::ptr::null_mut(),
    }
}

/// Get an ActivitySummary JSON from an Activity JSON (without coordinates).
/// Returns a pointer to a JSON string that must be freed with banshee_free_string.
#[no_mangle]
pub extern "C" fn banshee_get_activity_summary(activity_json: *const c_char) -> *mut c_char {
    if activity_json.is_null() {
        return std::ptr::null_mut();
    }

    let json_str = unsafe {
        match CStr::from_ptr(activity_json).to_str() {
            Ok(s) => s,
            Err(_) => return std::ptr::null_mut(),
        }
    };

    let activity: Activity = match Activity::from_json(json_str) {
        Ok(a) => a,
        Err(_) => return std::ptr::null_mut(),
    };

    let summary = activity.to_summary();

    match summary.to_json() {
        Ok(json) => match CString::new(json) {
            Ok(s) => s.into_raw(),
            Err(_) => std::ptr::null_mut(),
        },
        Err(_) => std::ptr::null_mut(),
    }
}

/// Calculate PBs from an activity JSON.
/// Returns a JSON array of PersonalBest records achieved in this activity.
/// Must be freed with banshee_free_string.
#[no_mangle]
pub extern "C" fn banshee_calculate_activity_pbs(activity_json: *const c_char) -> *mut c_char {
    if activity_json.is_null() {
        return std::ptr::null_mut();
    }

    let json_str = unsafe {
        match CStr::from_ptr(activity_json).to_str() {
            Ok(s) => s,
            Err(_) => return std::ptr::null_mut(),
        }
    };

    let activity: Activity = match Activity::from_json(json_str) {
        Ok(a) => a,
        Err(_) => return std::ptr::null_mut(),
    };

    let pbs = PBCalculator::calculate_pbs_for_activity(&activity);

    match serde_json::to_string(&pbs) {
        Ok(json) => match CString::new(json) {
            Ok(s) => s.into_raw(),
            Err(_) => std::ptr::null_mut(),
        },
        Err(_) => std::ptr::null_mut(),
    }
}

/// Update PBs with a new activity.
/// Takes existing PBs JSON and activity JSON.
/// Returns updated PBs JSON. Must be freed with banshee_free_string.
#[no_mangle]
pub extern "C" fn banshee_update_pbs(
    existing_pbs_json: *const c_char,
    activity_json: *const c_char,
) -> *mut c_char {
    if activity_json.is_null() {
        return std::ptr::null_mut();
    }

    let existing_pbs = if existing_pbs_json.is_null() {
        PersonalBests::new()
    } else {
        let pbs_str = unsafe {
            match CStr::from_ptr(existing_pbs_json).to_str() {
                Ok(s) => s,
                Err(_) => return std::ptr::null_mut(),
            }
        };
        PersonalBests::from_json(pbs_str).unwrap_or_default()
    };

    let activity_str = unsafe {
        match CStr::from_ptr(activity_json).to_str() {
            Ok(s) => s,
            Err(_) => return std::ptr::null_mut(),
        }
    };

    let activity: Activity = match Activity::from_json(activity_str) {
        Ok(a) => a,
        Err(_) => return std::ptr::null_mut(),
    };

    let (updated_pbs, _new_pbs) = PBCalculator::update_pbs(&existing_pbs, &activity);

    match updated_pbs.to_json() {
        Ok(json) => match CString::new(json) {
            Ok(s) => s.into_raw(),
            Err(_) => std::ptr::null_mut(),
        },
        Err(_) => std::ptr::null_mut(),
    }
}

/// Get new PBs achieved in an activity.
/// Takes existing PBs JSON and activity JSON.
/// Returns JSON array of newly achieved PBs. Must be freed with banshee_free_string.
#[no_mangle]
pub extern "C" fn banshee_get_new_pbs(
    existing_pbs_json: *const c_char,
    activity_json: *const c_char,
) -> *mut c_char {
    if activity_json.is_null() {
        return std::ptr::null_mut();
    }

    let existing_pbs = if existing_pbs_json.is_null() {
        PersonalBests::new()
    } else {
        let pbs_str = unsafe {
            match CStr::from_ptr(existing_pbs_json).to_str() {
                Ok(s) => s,
                Err(_) => return std::ptr::null_mut(),
            }
        };
        PersonalBests::from_json(pbs_str).unwrap_or_default()
    };

    let activity_str = unsafe {
        match CStr::from_ptr(activity_json).to_str() {
            Ok(s) => s,
            Err(_) => return std::ptr::null_mut(),
        }
    };

    let activity: Activity = match Activity::from_json(activity_str) {
        Ok(a) => a,
        Err(_) => return std::ptr::null_mut(),
    };

    let (_updated_pbs, new_pbs) = PBCalculator::update_pbs(&existing_pbs, &activity);

    match serde_json::to_string(&new_pbs) {
        Ok(json) => match CString::new(json) {
            Ok(s) => s.into_raw(),
            Err(_) => std::ptr::null_mut(),
        },
        Err(_) => std::ptr::null_mut(),
    }
}

/// Get all PBs for a specific activity type.
/// activity_type: 0=Run, 1=Walk, 2=Cycle
/// Returns a JSON array of PersonalBest records. Must be freed with banshee_free_string.
#[no_mangle]
pub extern "C" fn banshee_get_pbs_for_type(
    pbs_json: *const c_char,
    activity_type: i32,
) -> *mut c_char {
    if pbs_json.is_null() {
        return std::ptr::null_mut();
    }

    let pbs_str = unsafe {
        match CStr::from_ptr(pbs_json).to_str() {
            Ok(s) => s,
            Err(_) => return std::ptr::null_mut(),
        }
    };

    let pbs: PersonalBests = match PersonalBests::from_json(pbs_str) {
        Ok(p) => p,
        Err(_) => return std::ptr::null_mut(),
    };

    let act_type = match ActivityType::from_int(activity_type) {
        Some(t) => t,
        None => return std::ptr::null_mut(),
    };

    let filtered: Vec<_> = pbs.get_for_type(act_type);

    match serde_json::to_string(&filtered) {
        Ok(json) => match CString::new(json) {
            Ok(s) => s.into_raw(),
            Err(_) => std::ptr::null_mut(),
        },
        Err(_) => std::ptr::null_mut(),
    }
}

/// Sort activities in an index by date (most recent first).
/// Returns sorted ActivityIndex JSON. Must be freed with banshee_free_string.
#[no_mangle]
pub extern "C" fn banshee_sort_activities_by_date(index_json: *const c_char) -> *mut c_char {
    if index_json.is_null() {
        return std::ptr::null_mut();
    }

    let json_str = unsafe {
        match CStr::from_ptr(index_json).to_str() {
            Ok(s) => s,
            Err(_) => return std::ptr::null_mut(),
        }
    };

    let index: ActivityIndex = match ActivityIndex::from_json(json_str) {
        Ok(i) => i,
        Err(_) => return std::ptr::null_mut(),
    };

    let mut sorted_activities: Vec<ActivitySummary> = index.activities;
    sorted_activities.sort_by(|a, b| b.recorded_at.cmp(&a.recorded_at));

    let sorted_index = ActivityIndex {
        activities: sorted_activities,
    };

    match sorted_index.to_json() {
        Ok(json) => match CString::new(json) {
            Ok(s) => s.into_raw(),
            Err(_) => std::ptr::null_mut(),
        },
        Err(_) => std::ptr::null_mut(),
    }
}

/// Filter activities by type.
/// activity_type: 0=Run, 1=Walk, 2=Cycle, -1=All
/// Returns filtered ActivityIndex JSON. Must be freed with banshee_free_string.
#[no_mangle]
pub extern "C" fn banshee_filter_activities_by_type(
    index_json: *const c_char,
    activity_type: i32,
) -> *mut c_char {
    if index_json.is_null() {
        return std::ptr::null_mut();
    }

    let json_str = unsafe {
        match CStr::from_ptr(index_json).to_str() {
            Ok(s) => s,
            Err(_) => return std::ptr::null_mut(),
        }
    };

    let index: ActivityIndex = match ActivityIndex::from_json(json_str) {
        Ok(i) => i,
        Err(_) => return std::ptr::null_mut(),
    };

    let filtered_activities: Vec<ActivitySummary> = if activity_type < 0 {
        // -1 means all activities
        index.activities
    } else {
        match ActivityType::from_int(activity_type) {
            Some(t) => index
                .activities
                .into_iter()
                .filter(|a| a.activity_type == t)
                .collect(),
            None => return std::ptr::null_mut(),
        }
    };

    let filtered_index = ActivityIndex {
        activities: filtered_activities,
    };

    match filtered_index.to_json() {
        Ok(json) => match CString::new(json) {
            Ok(s) => s.into_raw(),
            Err(_) => std::ptr::null_mut(),
        },
        Err(_) => std::ptr::null_mut(),
    }
}

/// Format pace for display.
/// Returns a pace string like "5:30 /km". Must be freed with banshee_free_string.
#[no_mangle]
pub extern "C" fn banshee_format_pace(distance_meters: f64, duration_ms: i64) -> *mut c_char {
    let pace_str = crate::pb_calculator::format_pace(distance_meters, duration_ms as u64);

    match CString::new(pace_str) {
        Ok(s) => s.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Calculate speed in km/h.
#[no_mangle]
pub extern "C" fn banshee_calculate_speed_kmh(distance_meters: f64, duration_ms: i64) -> f64 {
    crate::pb_calculator::calculate_speed_kmh(distance_meters, duration_ms as u64)
}

/// Format time duration for display.
/// Returns a time string like "1:23:45" or "23:45". Must be freed with banshee_free_string.
#[no_mangle]
pub extern "C" fn banshee_format_duration(duration_ms: i64) -> *mut c_char {
    let total_seconds = duration_ms as u64 / 1000;
    let hours = total_seconds / 3600;
    let minutes = (total_seconds % 3600) / 60;
    let seconds = total_seconds % 60;

    let duration_str = if hours > 0 {
        format!("{}:{:02}:{:02}", hours, minutes, seconds)
    } else {
        format!("{}:{:02}", minutes, seconds)
    };

    match CString::new(duration_str) {
        Ok(s) => s.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Format distance for display.
/// Returns a distance string like "5.00 km" or "500 m". Must be freed with banshee_free_string.
#[no_mangle]
pub extern "C" fn banshee_format_distance(distance_meters: f64) -> *mut c_char {
    let distance_str = if distance_meters >= 1000.0 {
        format!("{:.2} km", distance_meters / 1000.0)
    } else {
        format!("{:.0} m", distance_meters)
    };

    match CString::new(distance_str) {
        Ok(s) => s.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Get the human-readable name for a PB distance.
/// Returns a string like "5K" or "Half Marathon". Must be freed with banshee_free_string.
#[no_mangle]
pub extern "C" fn banshee_get_distance_name(distance_meters: f64) -> *mut c_char {
    let name = ActivityType::distance_name(distance_meters);

    match CString::new(name) {
        Ok(s) => s.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}
