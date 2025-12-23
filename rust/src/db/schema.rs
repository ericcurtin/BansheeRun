/// SQL schema for BansheeRun database
pub const CREATE_TABLES: &str = r#"
-- Runs table
CREATE TABLE IF NOT EXISTS runs (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT,
    start_time TEXT NOT NULL,
    end_time TEXT,
    distance_meters REAL NOT NULL DEFAULT 0,
    duration_ms INTEGER NOT NULL DEFAULT 0,
    avg_pace_sec_per_km REAL
);

-- GPS points table
CREATE TABLE IF NOT EXISTS gps_points (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id TEXT NOT NULL,
    point_index INTEGER NOT NULL,
    lat REAL NOT NULL,
    lon REAL NOT NULL,
    altitude REAL,
    timestamp TEXT NOT NULL,
    accuracy REAL,
    speed REAL,
    FOREIGN KEY (run_id) REFERENCES runs(id) ON DELETE CASCADE
);

-- Index for faster point lookups
CREATE INDEX IF NOT EXISTS idx_gps_points_run_id ON gps_points(run_id);
CREATE INDEX IF NOT EXISTS idx_gps_points_run_index ON gps_points(run_id, point_index);

-- Settings table
CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY NOT NULL,
    value TEXT NOT NULL
);
"#;
