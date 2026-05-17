{
  description = "Nix package for the OpenClaw Weixin plugin";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    upstream = {
      url = "github:Tencent/openclaw-weixin";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, upstream }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;

      pluginName = "openclaw-weixin";

      mkOpenClawPlugin = system:
        let
          pkgs = import nixpkgs { inherit system; };
          packageJson = builtins.fromJSON (builtins.readFile "${upstream}/package.json");
          runtimeExtraNodeModules = [
            # Used by src/media/silk-transcode.ts at runtime, but currently
            # declared upstream as a devDependency.
            "silk-wasm"
          ];
          runtimeNodeModules =
            builtins.attrNames (packageJson.dependencies or { })
            ++ runtimeExtraNodeModules;

          srcWithLock = pkgs.runCommandLocal "openclaw-weixin-src-${packageJson.version}" { } ''
            mkdir -p "$out"
            cp -R ${upstream}/. "$out/"
            chmod -R u+w "$out"
            cp ${./package-lock.json} "$out/package-lock.json"
          '';
        in
        (pkgs.buildNpmPackage.override {
          nodejs = pkgs.nodejs_22;
        }) {
          pname = pluginName;
          version = packageJson.version;

          src = srcWithLock;

          npmDeps = pkgs.importNpmLock {
            npmRoot = srcWithLock;
          };
          npmConfigHook = pkgs.importNpmLock.npmConfigHook;

          npmBuildScript = "build";

          installPhase = ''
            runHook preInstall

            mkdir -p "$out/lib/openclaw/plugins/openclaw-weixin"
            cp -R dist src index.ts package.json openclaw.plugin.json README.md README.zh_CN.md CHANGELOG.md CHANGELOG.zh_CN.md LICENSE "$out/lib/openclaw/plugins/openclaw-weixin/"
            find "$out/lib/openclaw/plugins/openclaw-weixin/src" -name "*.test.ts" -delete
            mkdir -p "$out/lib/openclaw/plugins/openclaw-weixin/node_modules"

            for module in ${pkgs.lib.escapeShellArgs runtimeNodeModules}; do
              cp -R "node_modules/$module" "$out/lib/openclaw/plugins/openclaw-weixin/node_modules/"
            done

            runHook postInstall
          '';

          meta = {
            description = packageJson.description;
            license = pkgs.lib.licenses.mit;
          };
        };
    in
    {
      packages = forAllSystems (system: {
        default = mkOpenClawPlugin system;
      });

      openclawPlugin = system: {
        name = pluginName;
        skills = [
          ./skills/openclaw-weixin
        ];
        packages = [
          self.packages.${system}.default
        ];
        plugins = [
          {
            id = pluginName;
            path = "${self.packages.${system}.default}/lib/openclaw/plugins/${pluginName}";
            enabled = true;
          }
        ];
        needs = {
          stateDirs = [
            ".openclaw"
            ".openclaw/credentials"
          ];
          requiredEnv = [ ];
        };
      };

      homeManagerModules.default = { lib, pkgs, ... }:
        let
          pluginPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
          pluginPath = "${pluginPackage}/lib/openclaw/plugins/${pluginName}";
        in
        {
          programs.openclaw.config.plugins = {
            load.paths = [
              pluginPath
            ];
            entries.${pluginName}.enabled = lib.mkDefault true;
          };
        };

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.nodejs_22
              pkgs.typescript
            ];
          };
        });
    };
}
