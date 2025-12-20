//! JNI bindings for Android.

use jni::objects::{JClass, JDoubleArray, JObject, JString};
use jni::sys::{jdouble, jint, jlong, jstring};
use jni::JNIEnv;
use std::sync::Mutex;

use crate::{
    Activity, ActivityIndex, ActivityType, BansheeSession, PBCalculator, PersonalBests, Point,
    RunRecord,
};

static SESSION: Mutex<Option<BansheeSession>> = Mutex::new(None);

/// Initialize a BansheeSession from a JSON run record.
#[no_mangle]
pub extern "system" fn Java_com_bansheerun_BansheeLib_initSession<'local>(
    mut env: JNIEnv<'local>,
    _class: JClass<'local>,
    json: JString<'local>,
) -> jint {
    let json_str: String = match env.get_string(&json) {
        Ok(s) => s.into(),
        Err(_) => return -1,
    };

    let record: RunRecord = match RunRecord::from_json(&json_str) {
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
pub extern "system" fn Java_com_bansheerun_BansheeLib_clearSession(_env: JNIEnv, _class: JClass) {
    if let Ok(mut guard) = SESSION.lock() {
        *guard = None;
    }
}

/// Check if the runner is behind the banshee.
/// Returns: 1 = behind, 0 = not behind, -1 = no session
#[no_mangle]
pub extern "system" fn Java_com_bansheerun_BansheeLib_isBehind(
    _env: JNIEnv,
    _class: JClass,
    lat: jdouble,
    lon: jdouble,
    elapsed_ms: jlong,
) -> jint {
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
pub extern "system" fn Java_com_bansheerun_BansheeLib_getPacingStatus(
    _env: JNIEnv,
    _class: JClass,
    lat: jdouble,
    lon: jdouble,
    elapsed_ms: jlong,
) -> jint {
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
pub extern "system" fn Java_com_bansheerun_BansheeLib_getTimeDifferenceMs(
    _env: JNIEnv,
    _class: JClass,
    lat: jdouble,
    lon: jdouble,
    elapsed_ms: jlong,
) -> jlong {
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
pub extern "system" fn Java_com_bansheerun_BansheeLib_getBestRunDistance(
    _env: JNIEnv,
    _class: JClass,
) -> jdouble {
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
pub extern "system" fn Java_com_bansheerun_BansheeLib_getBestRunDurationMs(
    _env: JNIEnv,
    _class: JClass,
) -> jlong {
    if let Ok(guard) = SESSION.lock() {
        if let Some(ref session) = *guard {
            session.best_run_duration_ms() as jlong
        } else {
            0
        }
    } else {
        0
    }
}

/// Create a RunRecord JSON from coordinates.
#[no_mangle]
pub extern "system" fn Java_com_bansheerun_BansheeLib_createRunRecordJson<'local>(
    mut env: JNIEnv<'local>,
    _class: JClass<'local>,
    id: JString<'local>,
    name: JString<'local>,
    coords_json: JString<'local>,
    recorded_at: jlong,
) -> jlong {
    let id_str: String = match env.get_string(&id) {
        Ok(s) => s.into(),
        Err(_) => return 0,
    };

    let name_str: String = match env.get_string(&name) {
        Ok(s) => s.into(),
        Err(_) => return 0,
    };

    let coords_str: String = match env.get_string(&coords_json) {
        Ok(s) => s.into(),
        Err(_) => return 0,
    };

    let coords: Vec<Point> = match serde_json::from_str(&coords_str) {
        Ok(c) => c,
        Err(_) => return 0,
    };

    let record = RunRecord::new(id_str, name_str, coords, recorded_at as u64);

    match record.to_json() {
        Ok(json) => match env.new_string(json) {
            Ok(s) => s.into_raw() as jlong,
            Err(_) => 0,
        },
        Err(_) => 0,
    }
}

/// Get banshee position at elapsed time.
/// Returns a double array [lat, lon] or empty array if no session.
#[no_mangle]
pub extern "system" fn Java_com_bansheerun_BansheeLib_getBansheePositionAtTime<'local>(
    env: JNIEnv<'local>,
    _class: JClass<'local>,
    elapsed_ms: jlong,
) -> JDoubleArray<'local> {
    let empty = || {
        env.new_double_array(0)
            .unwrap_or_else(|_| JDoubleArray::default())
    };

    if let Ok(guard) = SESSION.lock() {
        if let Some(ref session) = *guard {
            if let Some((lat, lon)) = session.get_banshee_position_at_time(elapsed_ms as u64) {
                match env.new_double_array(2) {
                    Ok(arr) => {
                        let buf = [lat, lon];
                        if env.set_double_array_region(&arr, 0, &buf).is_ok() {
                            return arr;
                        }
                        empty()
                    }
                    Err(_) => empty(),
                }
            } else {
                empty()
            }
        } else {
            empty()
        }
    } else {
        empty()
    }
}

/// Get all best run coordinates as a flattened array [lat1, lon1, lat2, lon2, ...].
#[no_mangle]
pub extern "system" fn Java_com_bansheerun_BansheeLib_getBestRunCoordinates<'local>(
    env: JNIEnv<'local>,
    _class: JClass<'local>,
) -> JDoubleArray<'local> {
    let empty = || {
        env.new_double_array(0)
            .unwrap_or_else(|_| JDoubleArray::default())
    };

    if let Ok(guard) = SESSION.lock() {
        if let Some(ref session) = *guard {
            let coords = &session.best_run_coords;
            if coords.is_empty() {
                return empty();
            }

            let size = coords.len() * 2;
            match env.new_double_array(size as i32) {
                Ok(arr) => {
                    let mut buf: Vec<f64> = Vec::with_capacity(size);
                    for point in coords {
                        buf.push(point.lat);
                        buf.push(point.lon);
                    }
                    if env.set_double_array_region(&arr, 0, &buf).is_ok() {
                        return arr;
                    }
                    empty()
                }
                Err(_) => empty(),
            }
        } else {
            empty()
        }
    } else {
        empty()
    }
}

// ============================================================================
// Activity and Personal Best JNI Functions
// ============================================================================

/// Helper to return a JNI string or null on error.
fn return_jstring<'local>(env: &mut JNIEnv<'local>, s: &str) -> jstring {
    match env.new_string(s) {
        Ok(js) => js.into_raw(),
        Err(_) => JObject::null().into_raw(),
    }
}

/// Create an Activity JSON with the specified type.
/// activity_type: 0=Run, 1=Walk, 2=Cycle
#[no_mangle]
pub extern "system" fn Java_com_bansheerun_BansheeLib_createActivityJson<'local>(
    mut env: JNIEnv<'local>,
    _class: JClass<'local>,
    id: JString<'local>,
    name: JString<'local>,
    activity_type: jint,
    coords_json: JString<'local>,
    recorded_at: jlong,
) -> jstring {
    let id_str: String = match env.get_string(&id) {
        Ok(s) => s.into(),
        Err(_) => return JObject::null().into_raw(),
    };

    let name_str: String = match env.get_string(&name) {
        Ok(s) => s.into(),
        Err(_) => return JObject::null().into_raw(),
    };

    let coords_str: String = match env.get_string(&coords_json) {
        Ok(s) => s.into(),
        Err(_) => return JObject::null().into_raw(),
    };

    let coords: Vec<Point> = match serde_json::from_str(&coords_str) {
        Ok(c) => c,
        Err(_) => return JObject::null().into_raw(),
    };

    let act_type = match ActivityType::from_int(activity_type) {
        Some(t) => t,
        None => return JObject::null().into_raw(),
    };

    let activity = Activity::new(id_str, name_str, act_type, coords, recorded_at as u64);

    match activity.to_json() {
        Ok(json) => return_jstring(&mut env, &json),
        Err(_) => JObject::null().into_raw(),
    }
}

/// Get an ActivitySummary JSON from an Activity JSON.
#[no_mangle]
pub extern "system" fn Java_com_bansheerun_BansheeLib_getActivitySummary<'local>(
    mut env: JNIEnv<'local>,
    _class: JClass<'local>,
    activity_json: JString<'local>,
) -> jstring {
    let json_str: String = match env.get_string(&activity_json) {
        Ok(s) => s.into(),
        Err(_) => return JObject::null().into_raw(),
    };

    let activity: Activity = match Activity::from_json(&json_str) {
        Ok(a) => a,
        Err(_) => return JObject::null().into_raw(),
    };

    let summary = activity.to_summary();

    match summary.to_json() {
        Ok(json) => return_jstring(&mut env, &json),
        Err(_) => JObject::null().into_raw(),
    }
}

/// Calculate PBs from an activity JSON.
#[no_mangle]
pub extern "system" fn Java_com_bansheerun_BansheeLib_calculateActivityPbs<'local>(
    mut env: JNIEnv<'local>,
    _class: JClass<'local>,
    activity_json: JString<'local>,
) -> jstring {
    let json_str: String = match env.get_string(&activity_json) {
        Ok(s) => s.into(),
        Err(_) => return JObject::null().into_raw(),
    };

    let activity: Activity = match Activity::from_json(&json_str) {
        Ok(a) => a,
        Err(_) => return JObject::null().into_raw(),
    };

    let pbs = PBCalculator::calculate_pbs_for_activity(&activity);

    match serde_json::to_string(&pbs) {
        Ok(json) => return_jstring(&mut env, &json),
        Err(_) => JObject::null().into_raw(),
    }
}

/// Update PBs with a new activity.
#[no_mangle]
pub extern "system" fn Java_com_bansheerun_BansheeLib_updatePbs<'local>(
    mut env: JNIEnv<'local>,
    _class: JClass<'local>,
    existing_pbs_json: JString<'local>,
    activity_json: JString<'local>,
) -> jstring {
    let activity_str: String = match env.get_string(&activity_json) {
        Ok(s) => s.into(),
        Err(_) => return JObject::null().into_raw(),
    };

    let existing_pbs = if existing_pbs_json.is_null() {
        PersonalBests::new()
    } else {
        match env.get_string(&existing_pbs_json) {
            Ok(s) => {
                let pbs_str: String = s.into();
                PersonalBests::from_json(&pbs_str).unwrap_or_default()
            }
            Err(_) => PersonalBests::new(),
        }
    };

    let activity: Activity = match Activity::from_json(&activity_str) {
        Ok(a) => a,
        Err(_) => return JObject::null().into_raw(),
    };

    let (updated_pbs, _) = PBCalculator::update_pbs(&existing_pbs, &activity);

    match updated_pbs.to_json() {
        Ok(json) => return_jstring(&mut env, &json),
        Err(_) => JObject::null().into_raw(),
    }
}

/// Get new PBs achieved in an activity.
#[no_mangle]
pub extern "system" fn Java_com_bansheerun_BansheeLib_getNewPbs<'local>(
    mut env: JNIEnv<'local>,
    _class: JClass<'local>,
    existing_pbs_json: JString<'local>,
    activity_json: JString<'local>,
) -> jstring {
    let activity_str: String = match env.get_string(&activity_json) {
        Ok(s) => s.into(),
        Err(_) => return JObject::null().into_raw(),
    };

    let existing_pbs = if existing_pbs_json.is_null() {
        PersonalBests::new()
    } else {
        match env.get_string(&existing_pbs_json) {
            Ok(s) => {
                let pbs_str: String = s.into();
                PersonalBests::from_json(&pbs_str).unwrap_or_default()
            }
            Err(_) => PersonalBests::new(),
        }
    };

    let activity: Activity = match Activity::from_json(&activity_str) {
        Ok(a) => a,
        Err(_) => return JObject::null().into_raw(),
    };

    let (_, new_pbs) = PBCalculator::update_pbs(&existing_pbs, &activity);

    match serde_json::to_string(&new_pbs) {
        Ok(json) => return_jstring(&mut env, &json),
        Err(_) => JObject::null().into_raw(),
    }
}

/// Get all PBs for a specific activity type.
#[no_mangle]
pub extern "system" fn Java_com_bansheerun_BansheeLib_getPbsForType<'local>(
    mut env: JNIEnv<'local>,
    _class: JClass<'local>,
    pbs_json: JString<'local>,
    activity_type: jint,
) -> jstring {
    let pbs_str: String = match env.get_string(&pbs_json) {
        Ok(s) => s.into(),
        Err(_) => return JObject::null().into_raw(),
    };

    let pbs: PersonalBests = match PersonalBests::from_json(&pbs_str) {
        Ok(p) => p,
        Err(_) => return JObject::null().into_raw(),
    };

    let act_type = match ActivityType::from_int(activity_type) {
        Some(t) => t,
        None => return JObject::null().into_raw(),
    };

    let filtered: Vec<_> = pbs.get_for_type(act_type);

    match serde_json::to_string(&filtered) {
        Ok(json) => return_jstring(&mut env, &json),
        Err(_) => JObject::null().into_raw(),
    }
}

/// Sort activities in an index by date (most recent first).
#[no_mangle]
pub extern "system" fn Java_com_bansheerun_BansheeLib_sortActivitiesByDate<'local>(
    mut env: JNIEnv<'local>,
    _class: JClass<'local>,
    index_json: JString<'local>,
) -> jstring {
    let json_str: String = match env.get_string(&index_json) {
        Ok(s) => s.into(),
        Err(_) => return JObject::null().into_raw(),
    };

    let index: ActivityIndex = match ActivityIndex::from_json(&json_str) {
        Ok(i) => i,
        Err(_) => return JObject::null().into_raw(),
    };

    let mut sorted = index.activities;
    sorted.sort_by(|a, b| b.recorded_at.cmp(&a.recorded_at));

    let sorted_index = ActivityIndex { activities: sorted };

    match sorted_index.to_json() {
        Ok(json) => return_jstring(&mut env, &json),
        Err(_) => JObject::null().into_raw(),
    }
}

/// Filter activities by type. -1 means all activities.
#[no_mangle]
pub extern "system" fn Java_com_bansheerun_BansheeLib_filterActivitiesByType<'local>(
    mut env: JNIEnv<'local>,
    _class: JClass<'local>,
    index_json: JString<'local>,
    activity_type: jint,
) -> jstring {
    let json_str: String = match env.get_string(&index_json) {
        Ok(s) => s.into(),
        Err(_) => return JObject::null().into_raw(),
    };

    let index: ActivityIndex = match ActivityIndex::from_json(&json_str) {
        Ok(i) => i,
        Err(_) => return JObject::null().into_raw(),
    };

    let filtered = if activity_type < 0 {
        index.activities
    } else {
        match ActivityType::from_int(activity_type) {
            Some(t) => index
                .activities
                .into_iter()
                .filter(|a| a.activity_type == t)
                .collect(),
            None => return JObject::null().into_raw(),
        }
    };

    let filtered_index = ActivityIndex {
        activities: filtered,
    };

    match filtered_index.to_json() {
        Ok(json) => return_jstring(&mut env, &json),
        Err(_) => JObject::null().into_raw(),
    }
}

/// Format pace for display.
#[no_mangle]
pub extern "system" fn Java_com_bansheerun_BansheeLib_formatPace<'local>(
    mut env: JNIEnv<'local>,
    _class: JClass<'local>,
    distance_meters: jdouble,
    duration_ms: jlong,
) -> jstring {
    let pace = crate::pb_calculator::format_pace(distance_meters, duration_ms as u64);
    return_jstring(&mut env, &pace)
}

/// Calculate speed in km/h.
#[no_mangle]
pub extern "system" fn Java_com_bansheerun_BansheeLib_calculateSpeedKmh(
    _env: JNIEnv,
    _class: JClass,
    distance_meters: jdouble,
    duration_ms: jlong,
) -> jdouble {
    crate::pb_calculator::calculate_speed_kmh(distance_meters, duration_ms as u64)
}

/// Format time duration for display.
#[no_mangle]
pub extern "system" fn Java_com_bansheerun_BansheeLib_formatDuration<'local>(
    mut env: JNIEnv<'local>,
    _class: JClass<'local>,
    duration_ms: jlong,
) -> jstring {
    let total_seconds = duration_ms as u64 / 1000;
    let hours = total_seconds / 3600;
    let minutes = (total_seconds % 3600) / 60;
    let seconds = total_seconds % 60;

    let duration_str = if hours > 0 {
        format!("{}:{:02}:{:02}", hours, minutes, seconds)
    } else {
        format!("{}:{:02}", minutes, seconds)
    };

    return_jstring(&mut env, &duration_str)
}

/// Format distance for display.
#[no_mangle]
pub extern "system" fn Java_com_bansheerun_BansheeLib_formatDistance<'local>(
    mut env: JNIEnv<'local>,
    _class: JClass<'local>,
    distance_meters: jdouble,
) -> jstring {
    let distance_str = if distance_meters >= 1000.0 {
        format!("{:.2} km", distance_meters / 1000.0)
    } else {
        format!("{:.0} m", distance_meters)
    };

    return_jstring(&mut env, &distance_str)
}

/// Get the human-readable name for a PB distance.
#[no_mangle]
pub extern "system" fn Java_com_bansheerun_BansheeLib_getDistanceName<'local>(
    mut env: JNIEnv<'local>,
    _class: JClass<'local>,
    distance_meters: jdouble,
) -> jstring {
    let name = ActivityType::distance_name(distance_meters);
    return_jstring(&mut env, name)
}
