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
      errlib = import ./nix/lib.nix {}; # this errors on most lib functions
    in
      errlib.eachSystem supportedSystems (system: let
        flakeLib = import ./nix/lib.nix {inherit pkgs inputs self;};
        pkgs = import nixpkgs {
          inherit system;
          overlays = [(import rust-overlay)];
        };

        ci-run-miri-tests = pkgs.writeShellApplication {
          name = "ci-run-miri-tests";
          runtimeInputs = with pkgs; [
            gcc
            stdenv
            flakeLib.rustToolchain
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

        hello-world = flakeLib.createPackageStruct {
          src = flakeLib.craneLib.cleanCargoSource (flakeLib.craneLib.path ./packages/hello_world);
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
