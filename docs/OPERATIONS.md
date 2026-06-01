# Operations

## Check Daemon Health

```powershell
Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -like '*Start-ClaudeBridgeDaemon.ps1*' } |
  Select-Object ProcessId,CommandLine
```

## Check Queue Health

```powershell
[pscustomobject]@{
  inbox   = (Get-ChildItem C:\ai-bridge\inbox -Filter '*.task.json' | Measure-Object).Count
  working = (Get-ChildItem C:\ai-bridge\working -Filter '*.task.json' | Measure-Object).Count
  outbox  = (Get-ChildItem C:\ai-bridge\outbox -Filter '*.result.json' | Measure-Object).Count
  archive = (Get-ChildItem C:\ai-bridge\archive -Filter '*.task.json' | Measure-Object).Count
  locks   = (Get-ChildItem C:\ai-bridge\locks -Force | Measure-Object).Count
}
```

## Logs

- Daemon log: `C:\ai-bridge\logs\claude-bridge-daemon.log`
- Per-task invoke log: `C:\ai-bridge\logs\invoke-<task-id>.log`
- Approval watcher log: `C:\ai-bridge\logs\claude-approval-<task-id>.log`

## Disk Cleanup

By default, cleanup removes files older than 30 days from runtime data directories only:

- `tmp`
- `logs`
- `outbox`
- `archive`

It does not touch `bin`, `docs`, `schemas`, `examples`, `inbox`, `working`, or `locks`.

Run cleanup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ai-bridge\bin\Clear-ClaudeBridgeRuntime.ps1
```

Preview cleanup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ai-bridge\bin\Clear-ClaudeBridgeRuntime.ps1 -WhatIf
```

Use a shorter retention period:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ai-bridge\bin\Clear-ClaudeBridgeRuntime.ps1 -RetentionDays 7
```

## Stop The Daemon

```powershell
Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -like '*Start-ClaudeBridgeDaemon.ps1*' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId }
```

## Remove The Scheduled Task

```powershell
Unregister-ScheduledTask -TaskName "AI Bridge Claude Daemon" -Confirm:$false
```
