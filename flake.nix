{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
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

        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          targets = ["x86_64-unknown-linux-musl"];
        };

        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

        hello-world = craneLib.buildPackage {
          src = craneLib.cleanCargoSource (craneLib.path ./packages/hello_world);
          strictDeps = true;

          CARGO_BUILD_TARGET = "x86_64-unknown-linux-musl";
          CARGO_BUILD_RUSTFLAGS = "-C target-feature=+crt-static";
        };
      in {
        checks = {
          inherit hello-world;
        };

        packages.default = hello-world;
      });
}
