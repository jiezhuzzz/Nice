#[cfg_attr(target_os = "linux", path = "linux.rs")]
#[cfg_attr(target_os = "macos", path = "macos.rs")]
mod platform;

fn main() {
    println!("{}", platform::sample());
}
