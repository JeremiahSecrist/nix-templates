{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs:
    with inputs; let
      supportedSystems = ["x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin"];

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
    in
      eachSystem supportedSystems (system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [(import rust-overlay)];
        };

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
        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;
        ci-run-miri-tests = pkgs.writeShellApplication {
          name = "ci-run-miri-tests";
          runtimeInputs =  with pkgs;[
            gcc
            stdenv
            rustToolchain
            glibc
          ];
          text = ''
            pushd ./packages/hello_world
            cargo miri clean
            cargo miri setup
            cargo miri run
            popd
          '';
        };
        ci-all = pkgs.writeShellApplication {
          name = "ci-run-all";
          runtimeInputs = [
            ci-run-miri-tests
          ];
          text = ''
            ci-run-miri-tests
          '';
        };
        commonArgs = {
          strictDeps = true;
          # CARGO_BUILD_TARGET = "x86_64-unknown-linux-musl";
          # CARGO_BUILD_RUSTFLAGS = "-C target-feature=+crt-static";
          buildInputs = [];
          RUST_BACKTRACE = 1;
        };
        createPackageStruct = recipe: {
          inherit recipe;
          package = craneLib.buildPackage recipe;
          cargoArtifacts = craneLib.buildDepsOnly recipe;
          audit = craneLib.cargoAudit ({inherit advisory-db;} // recipe);
          clippy = craneLib.cargoClippy recipe;
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

        hello-world = createPackageStruct {
          src = craneLib.cleanCargoSource (craneLib.path ./packages/hello_world);
          strictDeps = true;
          CARGO_BUILD_TARGET = "x86_64-unknown-linux-musl";
          CARGO_BUILD_RUSTFLAGS = "-C target-feature=+crt-static";
          inherit (hello-world) cargoArtifacts;
        };
      in {
        checks = {
          hello-world = hello-world.package;
          hello-world-audit = hello-world.audit;
          hello-world-nxt-test = hello-world.next-test;
          hello-world-clippy = hello-world.clippy;
          hello-world-fmt = hello-world.fmt;
        };
        devShells = {
          default = hello-world.shell;
        };
        packages = {
          default = hello-world.package;
          inherit ci-all ci-run-miri-tests;
        };
        
      });
}
