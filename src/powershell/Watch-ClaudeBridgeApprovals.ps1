[CmdletBinding()]
param(
    [string] $WindowTitle = "Claude",
    [string] $TaskId = "",
    [int] $TimeoutSeconds = 120,
    [int] $PollMilliseconds = 500,
    [string] $LogPath = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $safeTask = if ([string]::IsNullOrWhiteSpace($TaskId)) { "no-task" } else { $TaskId }
    $LogPath = "C:\ai-bridge\logs\claude-approval-$safeTask-$stamp.log"
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $LogPath) | Out-Null

$python = @'
import argparse
import json
import time
from datetime import datetime, timezone

from pywinauto import Desktop

APPROVE_WORDS = [
    "allow", "approve", "run", "continue", "yes", "confirm", "execute",
    "\u5141\u8bb8", "\u6279\u51c6", "\u8fd0\u884c", "\u7ee7\u7eed",
    "\u786e\u8ba4", "\u6267\u884c", "\u540c\u610f", "\u662f",
]

DENY_WORDS = [
    "deny", "reject", "cancel", "stop", "close", "copy", "send", "new task",
    "running", "ran ", "used ", "model", "sidebar",
    "\u62d2\u7edd", "\u53d6\u6d88", "\u505c\u6b62", "\u5173\u95ed",
    "\u590d\u5236", "\u53d1\u9001", "\u65b0\u4efb\u52a1",
]

EXACT_APPROVE_WORDS = [
    "allow", "approve", "continue", "confirm", "execute",
    "allow once", "always allow", "run command", "run script",
    "\u5141\u8bb8", "\u6279\u51c6", "\u7ee7\u7eed", "\u786e\u8ba4",
    "\u6267\u884c", "\u8fd0\u884c\u547d\u4ee4", "\u8fd0\u884c\u811a\u672c",
]

def now():
    return datetime.now(timezone.utc).isoformat()

def log(path, event):
    event["at"] = now()
    with open(path, "a", encoding="utf-8") as f:
        f.write(json.dumps(event, ensure_ascii=False) + "\n")

def is_candidate(name):
    if not name:
        return False
    lowered = name.lower()
    if any(word in lowered for word in DENY_WORDS):
        return False
    stripped = lowered.strip()
    if stripped in EXACT_APPROVE_WORDS:
        return True
    return any(stripped.startswith(word + " ") for word in ("allow", "approve", "continue", "confirm", "execute"))

def visible(rect):
    return rect.right > rect.left and rect.bottom > rect.top and rect.bottom > 300

def window_contains_task_text(window, task_id):
    if not task_id:
        return True
    try:
        for item in window.descendants():
            try:
                text = item.window_text()
                if task_id in text:
                    return True
            except Exception:
                continue
    except Exception:
        return False
    return False

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--title", default="Claude")
    parser.add_argument("--task-id", default="")
    parser.add_argument("--timeout", type=float, default=120)
    parser.add_argument("--poll", type=float, default=0.5)
    parser.add_argument("--log", required=True)
    args = parser.parse_args()

    deadline = time.time() + args.timeout
    clicked = []
    log(args.log, {"event": "start", "title": args.title, "task_id": args.task_id})

    while time.time() < deadline:
        try:
            window = Desktop(backend="uia").window(title=args.title)
            if not window.exists(timeout=0.1):
                log(args.log, {"event": "window_not_found"})
                time.sleep(args.poll)
                continue

            if not window_contains_task_text(window, args.task_id):
                log(args.log, {"event": "task_text_not_visible"})
                time.sleep(args.poll)
                continue

            for control in window.descendants(control_type="Button"):
                try:
                    name = control.window_text()
                    rect = control.rectangle()
                    key = (name, rect.left, rect.top, rect.right, rect.bottom)
                    if key in clicked:
                        continue
                    if not visible(rect):
                        continue
                    if not is_candidate(name):
                        continue

                    control.click_input()
                    clicked.append(key)
                    log(args.log, {
                        "event": "clicked",
                        "name": name,
                        "rect": [rect.left, rect.top, rect.right, rect.bottom],
                    })
                    time.sleep(0.8)
                    break
                except Exception as exc:
                    log(args.log, {"event": "button_error", "error": str(exc)})
        except Exception as exc:
            log(args.log, {"event": "loop_error", "error": str(exc)})

        time.sleep(args.poll)

    log(args.log, {"event": "stop", "clicked_count": len(clicked)})
    print(json.dumps({"log_path": args.log, "clicked_count": len(clicked)}, ensure_ascii=True))

if __name__ == "__main__":
    main()
'@

$tempScript = Join-Path $env:TEMP ("watch-claude-approvals-" + [guid]::NewGuid().ToString("N") + ".py")
try {
    Set-Content -LiteralPath $tempScript -Value $python -Encoding UTF8
    $argsList = @(
        $tempScript,
        "--title", $WindowTitle,
        "--timeout", $TimeoutSeconds,
        "--poll", ($PollMilliseconds / 1000.0),
        "--log", $LogPath
    )

    if (-not [string]::IsNullOrWhiteSpace($TaskId)) {
        $argsList += @("--task-id", $TaskId)
    }

    python @argsList
}
finally {
    if (Test-Path $tempScript) {
        Remove-Item -LiteralPath $tempScript -Force
    }
}
