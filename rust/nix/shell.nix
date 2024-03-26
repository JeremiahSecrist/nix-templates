{
  pkgs,
  craneLib,
  rustToolchain,
}:
craneLib.devShell {
  # Get dependencies from the main package
  RUST_SRC_PATH = "${rustToolchain}/lib/rustlib/src/rust/library";
  CARGO_BUILD_TARGET = "x86_64-unknown-linux-musl";
  CARGO_BUILD_RUSTFLAGS = "-C target-feature=+crt-static";
  packages = with pkgs; [
    cargo
    cargo-audit
    cargo-bloat
    cargo-deny
    cargo-deps
    cargo-diet
    cargo-llvm-lines
    cargo-msrv
    cargo-rr
    cargo-sort
    cargo-vet
    cargo-watch
    clippy
    bacon
    rustc
    rustup
    rust-analyzer
    pkg-config
  ];
}
