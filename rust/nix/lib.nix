{
  inputs ? null,
  pkgs ? "x86_64-linux",
  self ? null,
}: let
  craneLib = (inputs.crane.mkLib pkgs).overrideToolchain rustToolchain;
  rustToolchain = pkgs.rust-bin.selectLatestNightlyWith (toolchain:
    toolchain.default.override {
      targets = [
        "x86_64-unknown-linux-musl"
        # "x86_64-unknown-linux-gnu"
      ];
      extensions = [
        "rust-src"
        "rust-analyzer"
        "rust-std"
        "clippy"
        "miri"
      ];
    });
in {
  inherit craneLib rustToolchain;
  eachSystem = systems: f: let
    # Merge together the outputs for all systems.
    op = attrs: system: let
      ret = f system;
      op = attrs: key:
        attrs
        // {
          ${key} =
            (attrs.${key} or {})
            // {${system} = ret.${key};};
        };
    in
      builtins.foldl' op attrs (builtins.attrNames ret);
  in
    builtins.foldl' op {}
    (systems
      ++ # add the current system if --impure is used
      (
        if builtins ? currentSystem
        then
          if builtins.elem builtins.currentSystem systems
          then []
          else [builtins.currentSystem]
        else []
      ));
  createPackageStruct = recipe: {
    inherit recipe;
    package = craneLib.buildPackage recipe;
    cargoArtifacts = craneLib.buildDepsOnly recipe;
    audit = craneLib.cargoAudit ({inherit (inputs) advisory-db;} // recipe);
    clippy = craneLib.cargoClippy ({cargoClippyExtraArgs = "-- -D warnings -D clippy::all -D clippy::pedantic -D clippy::nursery";} // recipe);
    next-test = craneLib.cargoNextest recipe;
    fmt = craneLib.cargoFmt recipe;
    shell = craneLib.devShell {
      checks = self.checks;
      inputsFrom = [(craneLib.buildPackage recipe)];
      RUST_SRC_PATH = "${rustToolchain}/lib/rustlib/src/rust/library";
      CARGO_BUILD_TARGET = recipe.CARGO_BUILD_TARGET;
      CARGO_BUILD_RUSTFLAGS = recipe.CARGO_BUILD_RUSTFLAGS;
      packages = with pkgs; [
        cargo-audit
        cargo-bloat
        cargo-deny
        cargo-deps
        cargo-diet
        cargo-llvm-lines
        cargo-tarpaulin
        cargo-msrv
        cargo-rr
        cargo-sort
        cargo-vet
        cargo-watch
        bacon
        rustup
        rust-analyzer
        pkg-config
      ];
    };
  };
}
