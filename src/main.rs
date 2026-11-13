fn main() {
    println!("e2e-package {}", hex::encode(env!("CARGO_PKG_VERSION")));
}
