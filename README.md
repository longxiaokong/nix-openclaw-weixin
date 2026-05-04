# nix-openclaw-weixin

这是上游 OpenClaw Weixin 通道插件的 Nix wrapper。

这个仓库不再保存上游源码。插件包会从 flake input
`github:Tencent/openclaw-weixin` 构建；本仓库只保存 Nix 契约、
`package-lock.json`、自动更新流程和少量 wrapper 文档。

## 插件信息

- 插件 id / channel id：`openclaw-weixin`
- 上游 npm 包：`@tencent-weixin/openclaw-weixin`
- 作用：为 OpenClaw 提供 Weixin 通道，包括二维码登录、消息处理和媒体处理。

## Nix 契约

这个 flake 导出：

- `packages.${system}.default`：构建好的 OpenClaw Weixin 插件包。
- `openclawPlugin`：nix-openclaw 使用的插件契约，包含 `name`、`skills`、
  `packages` 和 `needs`。这个输出是 `system: { ... }` 形式，适合纯 flake 求值。
- `homeManagerModules.default`：为 nix-openclaw 追加 native plugin 的
  `plugins.load.paths`，并默认启用 `plugins.entries.openclaw-weixin.enabled`。

`openclawPlugin.name` 是 `openclaw-weixin`，和上游 channel id 保持一致。

## 在 nix-openclaw 中启用

这个插件是 OpenClaw native channel plugin，不只是 skills/CLI 工具。因此除了让
Nix 构建插件包，还需要让 OpenClaw Gateway 加载插件目录并启用
`openclaw-weixin` entry。

### 方式一：导入本仓库的 module

推荐把这个仓库加入你的顶层 `flake inputs`，让它由你的 `flake.lock` 锁定：

```nix
{
  inputs.nix-openclaw-weixin.url = "github:OWNER/nix-openclaw-weixin";
}
```

然后导入本仓库提供的 Home Manager module：

```nix
{
  imports = [
    inputs.nix-openclaw.homeManagerModules.default
    inputs.nix-openclaw-weixin.homeManagerModules.default
  ];

  programs.openclaw = {
    enable = true;
  };
}
```

这个 module 会自动追加 `plugins.load.paths`，并默认启用
`plugins.entries.openclaw-weixin.enabled`。配置是合并式的，不会清空你已有的
`plugins.load.paths`；启用项使用 `mkDefault true`，如果你显式写 `false`，你的配置
会优先。

### 方式二：手动配置 customPlugins、load 和 enable

如果你不导入本仓库的 module，就需要自己处理三件事：

- `customPlugins.source` 必须是可锁定的来源。在 NixOS/Home Manager 的 flake
  纯求值里，裸 `github:OWNER/nix-openclaw-weixin` 通常不够，需要放进顶层
  `flake inputs`，或者写成带 `rev` 和 `narHash` 的 source。
- `plugins.load.paths` 需要指向构建结果中的 native plugin 目录。
- `plugins.entries.openclaw-weixin.enabled` 需要设为 `true`。

示例：

```nix
{ pkgs, inputs, ... }:

{
  programs.openclaw = {
    enable = true;

    customPlugins = [
      {
        source = "github:OWNER/nix-openclaw-weixin?rev=COMMIT&narHash=sha256-...";
      }
    ];

    config.plugins = {
      load.paths = [
        "${inputs.nix-openclaw-weixin.packages.${pkgs.stdenv.hostPlatform.system}.default}/lib/openclaw/plugins/openclaw-weixin"
      ];
      entries.openclaw-weixin.enabled = true;
    };
  };
}
```

如果你自己配置了 `plugins.allow` 白名单，需要把 `openclaw-weixin` 也加入 allow
list；`plugins.deny` 仍然会优先生效。

## 更新方式

GitHub Action 会自动更新 flake inputs，并根据最新上游 `package.json` 重新生成
`package-lock.json`，然后构建插件包并检查 `openclawPlugin` 输出。

本地也可以手动执行同样的刷新流程：

```sh
nix flake update nixpkgs upstream
upstream_path="$(nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.upstream.outPath')"
workdir="$(mktemp -d)"
cp "$upstream_path/package.json" "$workdir/package.json"
cd "$workdir"
npm install --package-lock-only --ignore-scripts
cp package-lock.json /path/to/nix-openclaw-weixin/package-lock.json
```

然后验证：

```sh
nix build .#default
nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).openclawPlugin.name'
```
