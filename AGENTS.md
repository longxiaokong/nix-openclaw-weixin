# AGENTS.md

This repository is a Nix wrapper for the upstream OpenClaw Weixin plugin.

## Plugin id

Use `openclaw-weixin`.

## Runtime state

The upstream plugin uses OpenClaw state for QR login credentials and runtime
data. The wrapper declares these state directories:

- `.openclaw`
- `.openclaw/credentials`

No real credentials belong in this repository. If a deployment uses secret
management, point OpenClaw or the host environment at paths such as
`/run/agenix/...` or another machine-local secret path.

## Environment knobs

The upstream plugin honors OpenClaw-level environment overrides, including:

- `OPENCLAW_STATE_DIR`
- `CLAWDBOT_STATE_DIR`
- `OPENCLAW_OAUTH_DIR`
- `OPENCLAW_CONFIG`
- `OPENCLAW_LOG_LEVEL`

This wrapper does not require a plugin-specific auth file environment variable;
login is performed by OpenClaw QR-code authorization.

## Updating upstream

Do not copy upstream source files into this repository. Update the `upstream`
flake input and regenerate `package-lock.json` from upstream `package.json`.
The GitHub Action does this automatically.
