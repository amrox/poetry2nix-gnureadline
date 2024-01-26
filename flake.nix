{
  description = "Application packaged using poetry2nix";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, poetry2nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # see https://github.com/nix-community/poetry2nix/tree/master#api for more functions and examples.
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (poetry2nix.lib.mkPoetry2Nix { inherit pkgs; }) mkPoetryApplication defaultPoetryOverrides;

        # See https://github.com/nix-community/poetry2nix/blob/8ffbc64abe7f432882cb5d96941c39103622ae5e/docs/edgecases.md#modulenotfounderror-no-module-named-packagename
        pypkgs-build-requirements = {
          debian-parser = [ "setuptools" ];
          #gnureadline = ["ncurses"]; # this was a wild guess that dind't work
        };
        p2n-overrides = defaultPoetryOverrides.extend (self: super:
          builtins.mapAttrs
            (package: build-requirements:
              (builtins.getAttr package super).overridePythonAttrs (old: {
                buildInputs = (old.buildInputs or [ ]) ++ (builtins.map (pkg: if builtins.isString pkg then builtins.getAttr pkg super else pkg) build-requirements);
              })
            )
            pypkgs-build-requirements
        );
      in
      {
        packages = {
          mkupdate = mkPoetryApplication {
            projectDir = self;
            overrides = p2n-overrides;
          };
          default = self.packages.${system}.mkupdate;
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [ self.packages.${system}.mkupdate ];
          packages = [ pkgs.poetry ];
        };
      });
}
