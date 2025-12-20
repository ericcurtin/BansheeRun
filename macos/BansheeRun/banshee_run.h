// C FFI header for BansheeRun Rust library

#ifndef BANSHEE_RUN_H
#define BANSHEE_RUN_H

#include <stdint.h>

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

#endif // BANSHEE_RUN_H
