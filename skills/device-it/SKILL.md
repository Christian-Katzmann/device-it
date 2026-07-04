---
name: device-it
description: >-
  Put a local web project on a device Home Screen / launcher as a launchable,
  fullscreen, offline-capable app with its own icon and name. Use when the user
  says device-it, wants to put a local web app on a phone, iPad, tablet,
  Android device, desktop browser, or asks for the on-device sibling of app-it.
---

# device-it plugin wrapper

This wrapper exists only so Codex/Claude plugin manifests can expose the
existing root skill without moving it.

Immediately read the full source skill at `../../SKILL.md` relative to this
file, then follow it.

Codex-specific rule: always pass the user's real project directory explicitly to
`scripts/run.sh`. Codex may run shell commands from the plugin cache root, so do
not rely on `$PWD`, `.`, or the shell working directory as the project.

Use this shape:

```bash
bash /absolute/path/to/device-it/scripts/run.sh /absolute/path/to/user/project [--icon img] [--name "Name"] [--slug slug] [--driver name]
```

For hosted URL wrapping and non-project verbs, use the root skill's commands:

```bash
bash /absolute/path/to/device-it/scripts/run.sh --url https://already-hosted.app --name "Name"
bash /absolute/path/to/device-it/scripts/run.sh remove <slug>
```
