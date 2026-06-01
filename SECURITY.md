# Security

Claudex is a local automation tool. Treat it as a privileged workflow helper.

## Supported Use

- Use a dedicated bridge directory such as `C:\ai-bridge`.
- Review Claude output before applying it to real projects.
- Keep Codex as the final reviewer.
- Inspect logs after long unattended runs.

## Not Supported

- Running untrusted task prompts without review.
- Treating the GUI approval watcher as a security boundary.
- Exposing the bridge directory as a network share.
- Using Claudex to bypass Claude, Windows, or application permission prompts.

## Reporting Issues

Open a GitHub issue with:

- operating system version
- Claude Desktop/Cowork version if known
- PowerShell version
- sanitized logs
- reproduction steps
