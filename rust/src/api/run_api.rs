use crate::db::Database;
use crate::geo;
use crate::models::{GpsPoint, Run, RunSummary};
use chrono::{DateTime, Utc};
use std::sync::OnceLock;

static DATABASE: OnceLock<Database> = OnceLock::new();

/// Initialize the database with the given path
pub fn init_database(db_path: String) -> Result<(), String> {
    let db = Database::open(&db_path).map_err(|e| e.to_string())?;
    DATABASE
        .set(db)
        .map_err(|_| "Database already initialized".to_string())
}

fn get_db() -> Result<&'static Database, String> {
    DATABASE
        .get()
        .ok_or_else(|| "Database not initialized".to_string())
}

/// DTO for creating a GPS point from Flutter
pub struct GpsPointDto {
    pub lat: f64,
    pub lon: f64,
    pub altitude: Option<f64>,
    pub timestamp_ms: i64,
    pub accuracy: Option<f64>,
    pub speed: Option<f64>,
}

impl From<GpsPointDto> for GpsPoint {
    fn from(dto: GpsPointDto) -> Self {
        let timestamp = DateTime::from_timestamp_millis(dto.timestamp_ms)
            .map(|dt| dt.with_timezone(&Utc))
            .unwrap_or_else(Utc::now);

        GpsPoint {
            lat: dto.lat,
            lon: dto.lon,
            altitude: dto.altitude,
            timestamp,
            accuracy: dto.accuracy,
            speed: dto.speed,
        }
    }
}

/// DTO for run data from Flutter
pub struct RunDto {
    pub id: String,
    pub name: Option<String>,
    pub start_time_ms: i64,
    pub end_time_ms: Option<i64>,
    pub points: Vec<GpsPointDto>,
    pub distance_meters: f64,
    pub duration_ms: i64,
    pub avg_pace_sec_per_km: Option<f64>,
}

impl From<RunDto> for Run {
    fn from(dto: RunDto) -> Self {
        let start_time = DateTime::from_timestamp_millis(dto.start_time_ms)
            .map(|dt| dt.with_timezone(&Utc))
            .unwrap_or_else(Utc::now);

        let end_time = dto
            .end_time_ms
            .and_then(|ms| DateTime::from_timestamp_millis(ms).map(|dt| dt.with_timezone(&Utc)));

        Run {
            id: dto.id,
            name: dto.name,
            start_time,
            end_time,
            points: dto.points.into_iter().map(|p| p.into()).collect(),
            distance_meters: dto.distance_meters,
            duration_ms: dto.duration_ms,
            avg_pace_sec_per_km: dto.avg_pace_sec_per_km,
        }
    }
}

/// DTO for returning run summary to Flutter
pub struct RunSummaryDto {
    pub id: String,
    pub name: Option<String>,
    pub start_time_ms: i64,
    pub distance_meters: f64,
    pub duration_ms: i64,
    pub avg_pace_sec_per_km: Option<f64>,
}

impl From<RunSummary> for RunSummaryDto {
    fn from(summary: RunSummary) -> Self {
        Self {
            id: summary.id,
            name: summary.name,
            start_time_ms: summary.start_time.timestamp_millis(),
            distance_meters: summary.distance_meters,
            duration_ms: summary.duration_ms,
            avg_pace_sec_per_km: summary.avg_pace_sec_per_km,
        }
    }
}

/// DTO for returning full run to Flutter
pub struct RunDetailDto {
    pub id: String,
    pub name: Option<String>,
    pub start_time_ms: i64,
    pub end_time_ms: Option<i64>,
    pub points: Vec<GpsPointDto>,
    pub distance_meters: f64,
    pub duration_ms: i64,
    pub avg_pace_sec_per_km: Option<f64>,
}

impl From<Run> for RunDetailDto {
    fn from(run: Run) -> Self {
        Self {
            id: run.id,
            name: run.name,
            start_time_ms: run.start_time.timestamp_millis(),
            end_time_ms: run.end_time.map(|t| t.timestamp_millis()),
            points: run
                .points
                .into_iter()
                .map(|p| GpsPointDto {
                    lat: p.lat,
                    lon: p.lon,
                    altitude: p.altitude,
                    timestamp_ms: p.timestamp.timestamp_millis(),
                    accuracy: p.accuracy,
                    speed: p.speed,
                })
                .collect(),
            distance_meters: run.distance_meters,
            duration_ms: run.duration_ms,
            avg_pace_sec_per_km: run.avg_pace_sec_per_km,
        }
    }
}

/// Create a new run and return its ID
pub fn create_run() -> Result<String, String> {
    let run = Run::new();
    let id = run.id.clone();
    get_db()?.save_run(&run).map_err(|e| e.to_string())?;
    Ok(id)
}

/// Save a run (creates or updates)
pub fn save_run(run_dto: RunDto) -> Result<(), String> {
    let mut run: Run = run_dto.into();

    // Recalculate distance and pace
    run.distance_meters = geo::total_distance(&run.points);
    if run.distance_meters > 0.0 && run.duration_ms > 0 {
        run.avg_pace_sec_per_km = Some(geo::calculate_pace(run.distance_meters, run.duration_ms));
    }

    get_db()?.save_run(&run).map_err(|e| e.to_string())
}

/// Get a run by ID
pub fn get_run(id: String) -> Result<Option<RunDetailDto>, String> {
    get_db()?
        .get_run(&id)
        .map(|opt| opt.map(|r| r.into()))
        .map_err(|e| e.to_string())
}

/// Get all runs (summaries only)
pub fn get_all_runs() -> Result<Vec<RunSummaryDto>, String> {
    get_db()?
        .get_all_runs()
        .map(|runs| runs.into_iter().map(|r| r.into()).collect())
        .map_err(|e| e.to_string())
}

/// Delete a run by ID
pub fn delete_run(id: String) -> Result<bool, String> {
    get_db()?.delete_run(&id).map_err(|e| e.to_string())
}

/// Get total run count
pub fn get_run_count() -> Result<i64, String> {
    get_db()?.run_count().map_err(|e| e.to_string())
}

/// Get total distance across all runs (in meters)
pub fn get_total_distance() -> Result<f64, String> {
    get_db()?.total_distance().map_err(|e| e.to_string())
}

/// Add a GPS point to a run and return updated distance
pub fn add_point_to_run(run_id: String, point: GpsPointDto) -> Result<f64, String> {
    let db = get_db()?;

    let mut run = db
        .get_run(&run_id)
        .map_err(|e| e.to_string())?
        .ok_or_else(|| "Run not found".to_string())?;

    run.add_point(point.into());
    run.distance_meters = geo::total_distance(&run.points);

    if let (Some(first), Some(last)) = (run.points.first(), run.points.last()) {
        run.duration_ms = (last.timestamp - first.timestamp).num_milliseconds();
    }

    db.save_run(&run).map_err(|e| e.to_string())?;

    Ok(run.distance_meters)
}

/// Finish a run
pub fn finish_run(run_id: String) -> Result<RunDetailDto, String> {
    let db = get_db()?;

    let mut run = db
        .get_run(&run_id)
        .map_err(|e| e.to_string())?
        .ok_or_else(|| "Run not found".to_string())?;

    run.finish();
    run.distance_meters = geo::total_distance(&run.points);

    if run.distance_meters > 0.0 && run.duration_ms > 0 {
        run.avg_pace_sec_per_km = Some(geo::calculate_pace(run.distance_meters, run.duration_ms));
    }

    db.save_run(&run).map_err(|e| e.to_string())?;

    Ok(run.into())
}
