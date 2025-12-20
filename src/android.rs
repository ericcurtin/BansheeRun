//! JNI bindings for Android.

use jni::objects::{JClass, JDoubleArray, JString};
use jni::sys::{jdouble, jint, jlong};
use jni::JNIEnv;
use std::sync::Mutex;

use crate::{BansheeSession, Point, RunRecord};

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
