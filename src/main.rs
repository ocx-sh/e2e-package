fn main() {
    // The dispatched version when the pipeline sets it, so a candidate never shares bytes with its release.
    let version = option_env!("E2E_VERSION").unwrap_or(env!("CARGO_PKG_VERSION"));
    println!("e2e-package {}", hex::encode(version));
}
