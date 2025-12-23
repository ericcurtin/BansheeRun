pub mod schema;

use anyhow::Result;
use rusqlite::Connection;
use std::path::Path;
use std::sync::Mutex;

use crate::models::{GpsPoint, Run, RunSummary};

/// Database wrapper for SQLite operations
pub struct Database {
    conn: Mutex<Connection>,
}

impl Database {
    /// Open or create a database at the given path
    pub fn open<P: AsRef<Path>>(path: P) -> Result<Self> {
        let conn = Connection::open(path)?;
        let db = Self {
            conn: Mutex::new(conn),
        };
        db.init_schema()?;
        Ok(db)
    }

    /// Initialize database schema
    fn init_schema(&self) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute_batch(schema::CREATE_TABLES)?;
        Ok(())
    }

    /// Save a run to the database
    pub fn save_run(&self, run: &Run) -> Result<()> {
        let conn = self.conn.lock().unwrap();

        // Insert or replace run
        conn.execute(
            "INSERT OR REPLACE INTO runs (id, name, start_time, end_time, distance_meters, duration_ms, avg_pace_sec_per_km)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            rusqlite::params![
                run.id,
                run.name,
                run.start_time.to_rfc3339(),
                run.end_time.map(|t| t.to_rfc3339()),
                run.distance_meters,
                run.duration_ms,
                run.avg_pace_sec_per_km,
            ],
        )?;

        // Delete existing points for this run
        conn.execute("DELETE FROM gps_points WHERE run_id = ?1", [&run.id])?;

        // Insert all GPS points
        for (idx, point) in run.points.iter().enumerate() {
            conn.execute(
                "INSERT INTO gps_points (run_id, point_index, lat, lon, altitude, timestamp, accuracy, speed)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
                rusqlite::params![
                    run.id,
                    idx as i64,
                    point.lat,
                    point.lon,
                    point.altitude,
                    point.timestamp.to_rfc3339(),
                    point.accuracy,
                    point.speed,
                ],
            )?;
        }

        Ok(())
    }

    /// Get a run by ID
    pub fn get_run(&self, id: &str) -> Result<Option<Run>> {
        let conn = self.conn.lock().unwrap();

        let mut stmt = conn.prepare(
            "SELECT id, name, start_time, end_time, distance_meters, duration_ms, avg_pace_sec_per_km
             FROM runs WHERE id = ?1",
        )?;

        let run = stmt.query_row([id], |row| {
            let id: String = row.get(0)?;
            let name: Option<String> = row.get(1)?;
            let start_time_str: String = row.get(2)?;
            let end_time_str: Option<String> = row.get(3)?;
            let distance_meters: f64 = row.get(4)?;
            let duration_ms: i64 = row.get(5)?;
            let avg_pace_sec_per_km: Option<f64> = row.get(6)?;

            let start_time = chrono::DateTime::parse_from_rfc3339(&start_time_str)
                .map(|dt| dt.with_timezone(&chrono::Utc))
                .unwrap_or_else(|_| chrono::Utc::now());

            let end_time = end_time_str.and_then(|s| {
                chrono::DateTime::parse_from_rfc3339(&s)
                    .map(|dt| dt.with_timezone(&chrono::Utc))
                    .ok()
            });

            Ok(Run {
                id,
                name,
                start_time,
                end_time,
                points: Vec::new(),
                distance_meters,
                duration_ms,
                avg_pace_sec_per_km,
            })
        });

        match run {
            Ok(mut run) => {
                // Load GPS points
                let mut point_stmt = conn.prepare(
                    "SELECT lat, lon, altitude, timestamp, accuracy, speed
                     FROM gps_points WHERE run_id = ?1 ORDER BY point_index",
                )?;

                let points = point_stmt.query_map([id], |row| {
                    let lat: f64 = row.get(0)?;
                    let lon: f64 = row.get(1)?;
                    let altitude: Option<f64> = row.get(2)?;
                    let timestamp_str: String = row.get(3)?;
                    let accuracy: Option<f64> = row.get(4)?;
                    let speed: Option<f64> = row.get(5)?;

                    let timestamp = chrono::DateTime::parse_from_rfc3339(&timestamp_str)
                        .map(|dt| dt.with_timezone(&chrono::Utc))
                        .unwrap_or_else(|_| chrono::Utc::now());

                    Ok(GpsPoint {
                        lat,
                        lon,
                        altitude,
                        timestamp,
                        accuracy,
                        speed,
                    })
                })?;

                run.points = points.filter_map(|p| p.ok()).collect();
                Ok(Some(run))
            }
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(e.into()),
        }
    }

    /// Get all runs (summary only, no GPS points)
    pub fn get_all_runs(&self) -> Result<Vec<RunSummary>> {
        let conn = self.conn.lock().unwrap();

        let mut stmt = conn.prepare(
            "SELECT id, name, start_time, distance_meters, duration_ms, avg_pace_sec_per_km
             FROM runs ORDER BY start_time DESC",
        )?;

        let runs = stmt.query_map([], |row| {
            let id: String = row.get(0)?;
            let name: Option<String> = row.get(1)?;
            let start_time_str: String = row.get(2)?;
            let distance_meters: f64 = row.get(3)?;
            let duration_ms: i64 = row.get(4)?;
            let avg_pace_sec_per_km: Option<f64> = row.get(5)?;

            let start_time = chrono::DateTime::parse_from_rfc3339(&start_time_str)
                .map(|dt| dt.with_timezone(&chrono::Utc))
                .unwrap_or_else(|_| chrono::Utc::now());

            Ok(RunSummary {
                id,
                name,
                start_time,
                distance_meters,
                duration_ms,
                avg_pace_sec_per_km,
            })
        })?;

        Ok(runs.filter_map(|r| r.ok()).collect())
    }

    /// Delete a run by ID
    pub fn delete_run(&self, id: &str) -> Result<bool> {
        let conn = self.conn.lock().unwrap();

        // Delete GPS points first (foreign key)
        conn.execute("DELETE FROM gps_points WHERE run_id = ?1", [id])?;

        // Delete run
        let rows = conn.execute("DELETE FROM runs WHERE id = ?1", [id])?;

        Ok(rows > 0)
    }

    /// Get run count
    pub fn run_count(&self) -> Result<i64> {
        let conn = self.conn.lock().unwrap();
        let count: i64 = conn.query_row("SELECT COUNT(*) FROM runs", [], |row| row.get(0))?;
        Ok(count)
    }

    /// Get total distance across all runs (in meters)
    pub fn total_distance(&self) -> Result<f64> {
        let conn = self.conn.lock().unwrap();
        let total: f64 = conn.query_row(
            "SELECT COALESCE(SUM(distance_meters), 0) FROM runs",
            [],
            |row| row.get(0),
        )?;
        Ok(total)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;

    #[test]
    fn test_database_crud() {
        let db = Database::open(":memory:").unwrap();

        // Create a run
        let mut run = Run::new();
        run.name = Some("Test Run".to_string());
        run.add_point(GpsPoint::new(51.5074, -0.1278, Utc::now()));
        run.add_point(GpsPoint::new(51.5075, -0.1279, Utc::now()));
        run.distance_meters = 100.0;

        // Save
        db.save_run(&run).unwrap();

        // Load
        let loaded = db.get_run(&run.id).unwrap().unwrap();
        assert_eq!(loaded.id, run.id);
        assert_eq!(loaded.name, Some("Test Run".to_string()));
        assert_eq!(loaded.points.len(), 2);

        // List
        let all = db.get_all_runs().unwrap();
        assert_eq!(all.len(), 1);

        // Delete
        assert!(db.delete_run(&run.id).unwrap());
        assert!(db.get_run(&run.id).unwrap().is_none());
    }
}
