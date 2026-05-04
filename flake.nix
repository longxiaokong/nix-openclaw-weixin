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

      mkOpenClawPlugin = system:
        let
          pkgs = import nixpkgs { inherit system; };
          packageJson = builtins.fromJSON (builtins.readFile ./package.json);

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
          pname = "openclaw-weixin";
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
        openclawPlugin = mkOpenClawPlugin system;
      });

      openclawPlugin = system: {
        name = "openclaw-weixin";
        packages = [
          self.packages.${system}.openclawPlugin
        ];
        needs = [ ];
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
