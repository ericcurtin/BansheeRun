/// Simple greeting function (flutter_rust_bridge template)
#[flutter_rust_bridge::frb(sync)]
pub fn greet(name: String) -> String {
    format!("Hello, {name}! Welcome to BansheeRun!")
}

/// Initialize the Rust backend
#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Initialize logging or other setup here
    flutter_rust_bridge::setup_default_user_utils();
}
