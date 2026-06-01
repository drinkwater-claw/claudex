[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $TaskId,

    [string] $BridgeRoot = "C:\ai-bridge",
    [string] $WindowTitle = "Claude",
    [switch] $MinimizeCodex
)

$ErrorActionPreference = "Stop"

$taskPath = Join-Path (Join-Path $BridgeRoot "inbox") "$TaskId.task.json"
$workingPath = Join-Path (Join-Path $BridgeRoot "working") "$TaskId.task.json"

if (-not (Test-Path $taskPath) -and -not (Test-Path $workingPath)) {
    throw "Task not found in inbox or working: $TaskId"
}

$workerPrompt = @"
You are the Claude-side worker in an AI file bridge. Codex is the project lead, architect, reviewer, and final decision maker. You are the execution worker.

Bridge root:
$BridgeRoot

Target task id:
$TaskId

Rules:
- Execute only this target task.
- Do not decide project direction or final acceptance. Codex will review your result.
- Keep changes and answers scoped to the task.
- If a file or command approval appears, wait for it; Codex may auto-approve bridge-related commands.
- Do not modify files outside the task scope.

Protocol:
1. Claim the task:
   powershell -NoProfile -ExecutionPolicy Bypass -File $BridgeRoot\bin\Get-AIBridgeNextTask.ps1
2. Confirm the claimed id is exactly $TaskId. If another id is claimed, complete it only if it is the only pending bridge task; otherwise explain the mismatch.
3. Read the task prompt and context files.
4. Write your answer to:
   $BridgeRoot\tmp\$TaskId.response.md
5. Complete the task:
   powershell -NoProfile -ExecutionPolicy Bypass -File $BridgeRoot\bin\Complete-AIBridgeTask.ps1 -Id $TaskId -ResponseFile $BridgeRoot\tmp\$TaskId.response.md -Summary "Claude completed bridge task $TaskId." -Status succeeded
6. If you cannot complete the task, write a response markdown explaining the blocker and complete with -Status failed.

Start now. Reply only with the actual execution outcome.
"@

for ($attempt = 1; $attempt -le 10; $attempt++) {
    try {
        Set-Clipboard -Value $workerPrompt
        break
    }
    catch {
        if ($attempt -eq 10) {
            throw
        }
        Start-Sleep -Milliseconds (150 * $attempt)
    }
}

$python = @'
import argparse
import json
import time

from pywinauto import Desktop
from pywinauto import keyboard

def center(rect):
    return (int((rect.left + rect.right) / 2), int((rect.top + rect.bottom) / 2))

def find_first(window, control_type=None, name=None, startswith=None):
    for item in window.descendants():
        try:
            info = item.element_info
            text = item.window_text() or ""
            if control_type and info.control_type != control_type:
                continue
            if name and text != name:
                continue
            if startswith and not text.startswith(startswith):
                continue
            return item
        except Exception:
            continue
    return None

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--window-title", default="Claude")
    parser.add_argument("--minimize-codex", action="store_true")
    args = parser.parse_args()

    desktop = Desktop(backend="uia")

    if args.minimize_codex:
        try:
            codex = desktop.window(title="Codex")
            if codex.exists(timeout=0.2):
                codex.minimize()
        except Exception:
            pass

    window = desktop.window(title=args.window_title)
    if not window.exists(timeout=5):
        raise RuntimeError(f"Window not found: {args.window_title}")

    window.restore()
    window.set_focus()
    time.sleep(0.4)

    input_control = find_first(window, startswith="Write a message")
    if input_control is not None:
        input_control.click_input()
    else:
        rect = window.rectangle()
        fallback_x = int(rect.left + (rect.right - rect.left) * 0.43)
        fallback_y = int(rect.bottom - 85)
        window.click_input(coords=(fallback_x - rect.left, fallback_y - rect.top))

    time.sleep(0.2)
    keyboard.send_keys("^a")
    time.sleep(0.1)
    keyboard.send_keys("^v")
    time.sleep(0.4)

    send_button = find_first(window, control_type="Button", name="Send message")
    if send_button is not None:
        send_button.click_input()
    else:
        keyboard.send_keys("{ENTER}")

    print(json.dumps({"sent": True, "window_title": args.window_title}, ensure_ascii=True))

if __name__ == "__main__":
    main()
'@

$tempScript = Join-Path $env:TEMP ("send-claude-worker-" + [guid]::NewGuid().ToString("N") + ".py")
try {
    Set-Content -LiteralPath $tempScript -Value $python -Encoding UTF8
    $argsList = @($tempScript, "--window-title", $WindowTitle)
    if ($MinimizeCodex) {
        $argsList += "--minimize-codex"
    }
    python @argsList
}
finally {
    if (Test-Path $tempScript) {
        Remove-Item -LiteralPath $tempScript -Force
    }
}
