pub mod distance;
pub mod interpolation;
pub mod pace;

pub use distance::{haversine_distance, total_distance};
pub use interpolation::{interpolate_position, interpolate_position_at_distance};
pub use pace::{calculate_pace, calculate_splits, format_pace, Split};
