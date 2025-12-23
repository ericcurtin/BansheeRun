use crate::models::GpsPoint;

/// Earth's radius in meters
const EARTH_RADIUS_M: f64 = 6_371_000.0;

/// Calculate the Haversine distance between two points in meters
pub fn haversine_distance(lat1: f64, lon1: f64, lat2: f64, lon2: f64) -> f64 {
    let lat1_rad = lat1.to_radians();
    let lat2_rad = lat2.to_radians();
    let delta_lat = (lat2 - lat1).to_radians();
    let delta_lon = (lon2 - lon1).to_radians();

    let a = (delta_lat / 2.0).sin().powi(2)
        + lat1_rad.cos() * lat2_rad.cos() * (delta_lon / 2.0).sin().powi(2);

    let c = 2.0 * a.sqrt().asin();

    EARTH_RADIUS_M * c
}

/// Calculate the Haversine distance between two GPS points
pub fn haversine_distance_points(p1: &GpsPoint, p2: &GpsPoint) -> f64 {
    haversine_distance(p1.lat, p1.lon, p2.lat, p2.lon)
}

/// Calculate total distance of a GPS track in meters
pub fn total_distance(points: &[GpsPoint]) -> f64 {
    if points.len() < 2 {
        return 0.0;
    }

    points
        .windows(2)
        .map(|pair| haversine_distance_points(&pair[0], &pair[1]))
        .sum()
}

/// Calculate cumulative distances for each point
pub fn cumulative_distances(points: &[GpsPoint]) -> Vec<f64> {
    if points.is_empty() {
        return Vec::new();
    }

    let mut distances = Vec::with_capacity(points.len());
    distances.push(0.0);

    for i in 1..points.len() {
        let prev_distance = distances[i - 1];
        let segment_distance = haversine_distance_points(&points[i - 1], &points[i]);
        distances.push(prev_distance + segment_distance);
    }

    distances
}

/// Calculate bearing from point 1 to point 2 in degrees (0-360)
pub fn bearing(lat1: f64, lon1: f64, lat2: f64, lon2: f64) -> f64 {
    let lat1_rad = lat1.to_radians();
    let lat2_rad = lat2.to_radians();
    let delta_lon = (lon2 - lon1).to_radians();

    let x = delta_lon.sin() * lat2_rad.cos();
    let y = lat1_rad.cos() * lat2_rad.sin() - lat1_rad.sin() * lat2_rad.cos() * delta_lon.cos();

    let bearing_rad = x.atan2(y);
    (bearing_rad.to_degrees() + 360.0) % 360.0
}

/// Calculate a destination point given start, bearing, and distance
pub fn destination_point(lat: f64, lon: f64, bearing_deg: f64, distance_m: f64) -> (f64, f64) {
    let lat_rad = lat.to_radians();
    let lon_rad = lon.to_radians();
    let bearing_rad = bearing_deg.to_radians();
    let angular_distance = distance_m / EARTH_RADIUS_M;

    let dest_lat = (lat_rad.sin() * angular_distance.cos()
        + lat_rad.cos() * angular_distance.sin() * bearing_rad.cos())
    .asin();

    let dest_lon = lon_rad
        + (bearing_rad.sin() * angular_distance.sin() * lat_rad.cos())
            .atan2(angular_distance.cos() - lat_rad.sin() * dest_lat.sin());

    (dest_lat.to_degrees(), dest_lon.to_degrees())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_haversine_distance() {
        // London to Paris (approximately 344 km)
        let distance = haversine_distance(51.5074, -0.1278, 48.8566, 2.3522);
        assert!((distance - 343_500.0).abs() < 1000.0);
    }

    #[test]
    fn test_zero_distance() {
        let distance = haversine_distance(51.5074, -0.1278, 51.5074, -0.1278);
        assert!(distance < 0.001);
    }

    #[test]
    fn test_total_distance() {
        use chrono::Utc;

        let points = vec![
            GpsPoint::new(51.5074, -0.1278, Utc::now()),
            GpsPoint::new(51.5084, -0.1278, Utc::now()),
            GpsPoint::new(51.5094, -0.1278, Utc::now()),
        ];

        let total = total_distance(&points);
        // Should be approximately 222m (2 * 111m per 0.001 degree latitude)
        assert!(total > 200.0 && total < 250.0);
    }
}
