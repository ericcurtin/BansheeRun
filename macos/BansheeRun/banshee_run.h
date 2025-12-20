// C FFI header for BansheeRun Rust library

#ifndef BANSHEE_RUN_H
#define BANSHEE_RUN_H

#include <stdint.h>

// ============================================================================
// Session Management
// ============================================================================

// Initialize a BansheeSession from a JSON run record.
// Returns: 0 on success, negative on error
int32_t banshee_init_session(const char* json);

// Clear the current session.
void banshee_clear_session(void);

// Check if the runner is behind the banshee.
// Returns: 1 = behind, 0 = not behind, -1 = no session
int32_t banshee_is_behind(double lat, double lon, int64_t elapsed_ms);

// Get pacing status.
// Returns: 0 = Ahead, 1 = Behind, 2 = Unknown, -1 = no session
int32_t banshee_get_pacing_status(double lat, double lon, int64_t elapsed_ms);

// Get time difference in milliseconds.
// Positive = ahead, negative = behind.
int64_t banshee_get_time_difference_ms(double lat, double lon, int64_t elapsed_ms);

// Get best run total distance in meters.
double banshee_get_best_run_distance(void);

// Get best run duration in milliseconds.
int64_t banshee_get_best_run_duration_ms(void);

// Create a RunRecord JSON from parameters.
// Returns a pointer to a C string that must be freed with banshee_free_string.
char* banshee_create_run_record_json(const char* id, const char* name, const char* coords_json, int64_t recorded_at);

// Free a string allocated by the library.
void banshee_free_string(char* s);

// ============================================================================
// Activity Management
// Activity types: 0=Run, 1=Walk, 2=Cycle
// ============================================================================

// Create an Activity JSON with the specified type.
// Returns a pointer to a JSON string that must be freed with banshee_free_string.
char* banshee_create_activity_json(const char* id, const char* name, int32_t activity_type, const char* coords_json, int64_t recorded_at);

// Get an ActivitySummary JSON from an Activity JSON (without coordinates).
// Returns a pointer to a JSON string that must be freed with banshee_free_string.
char* banshee_get_activity_summary(const char* activity_json);

// ============================================================================
// Personal Bests
// ============================================================================

// Calculate PBs from an activity JSON.
// Returns a JSON array of PersonalBest records achieved in this activity.
// Must be freed with banshee_free_string.
char* banshee_calculate_activity_pbs(const char* activity_json);

// Update PBs with a new activity.
// Takes existing PBs JSON (can be NULL) and activity JSON.
// Returns updated PBs JSON. Must be freed with banshee_free_string.
char* banshee_update_pbs(const char* existing_pbs_json, const char* activity_json);

// Get new PBs achieved in an activity.
// Takes existing PBs JSON (can be NULL) and activity JSON.
// Returns JSON array of newly achieved PBs. Must be freed with banshee_free_string.
char* banshee_get_new_pbs(const char* existing_pbs_json, const char* activity_json);

// Get all PBs for a specific activity type.
// activity_type: 0=Run, 1=Walk, 2=Cycle
// Returns a JSON array of PersonalBest records. Must be freed with banshee_free_string.
char* banshee_get_pbs_for_type(const char* pbs_json, int32_t activity_type);

// ============================================================================
// Activity Index (List)
// ============================================================================

// Sort activities in an index by date (most recent first).
// Returns sorted ActivityIndex JSON. Must be freed with banshee_free_string.
char* banshee_sort_activities_by_date(const char* index_json);

// Filter activities by type.
// activity_type: 0=Run, 1=Walk, 2=Cycle, -1=All
// Returns filtered ActivityIndex JSON. Must be freed with banshee_free_string.
char* banshee_filter_activities_by_type(const char* index_json, int32_t activity_type);

// ============================================================================
// Formatting Helpers
// ============================================================================

// Format pace for display.
// Returns a pace string like "5:30 /km". Must be freed with banshee_free_string.
char* banshee_format_pace(double distance_meters, int64_t duration_ms);

// Calculate speed in km/h.
double banshee_calculate_speed_kmh(double distance_meters, int64_t duration_ms);

// Format time duration for display.
// Returns a time string like "1:23:45" or "23:45". Must be freed with banshee_free_string.
char* banshee_format_duration(int64_t duration_ms);

// Format distance for display.
// Returns a distance string like "5.00 km" or "500 m". Must be freed with banshee_free_string.
char* banshee_format_distance(double distance_meters);

// Get the human-readable name for a PB distance.
// Returns a string like "5K" or "Half Marathon". Must be freed with banshee_free_string.
char* banshee_get_distance_name(double distance_meters);

#endif // BANSHEE_RUN_H
