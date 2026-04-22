{
  description = "emini Python project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      forAllSystems = lib.genAttrs systems;

      workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

      mkPythonSet =
        pkgs:
        let
          python = pkgs.python313;
          pythonBase = pkgs.callPackage pyproject-nix.build.packages { inherit python; };
        in
        pythonBase.overrideScope (
          lib.composeManyExtensions [
            pyproject-build-systems.overlays.default
            (workspace.mkPyprojectOverlay { sourcePreference = "wheel"; })
          ]
        );
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pythonSet = mkPythonSet pkgs;
          inherit (pkgs.callPackages pyproject-nix.build.util { }) mkApplication;
        in
        {
          venv = pythonSet.mkVirtualEnv "emini-env" workspace.deps.default;

          default = mkApplication {
            venv = self.packages.${system}.venv;
            package = pythonSet.emini;
          };
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/emini";
          meta.description = "Run emini";
        };
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pythonSet = mkPythonSet pkgs;
          editablePythonSet = pythonSet.overrideScope (
            workspace.mkEditablePyprojectOverlay {
              root = "$REPO_ROOT";
            }
          );
          virtualenv = editablePythonSet.mkVirtualEnv "emini-dev-env" workspace.deps.all;
        in
        {
          default = pkgs.mkShell {
            packages = [
              virtualenv
              pkgs.uv
            ];

            env = {
              UV_NO_SYNC = "1";
              UV_PYTHON = editablePythonSet.python.interpreter;
              UV_PYTHON_DOWNLOADS = "never";
              UV_PROJECT_ENVIRONMENT = "${virtualenv}";
            };

            shellHook = ''
              unset PYTHONPATH
              export REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
            '';
          };
        }
      );
    };
}
