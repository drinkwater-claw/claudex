Option Explicit

Dim args, shell, command
Set args = WScript.Arguments

If args.Count < 4 Then
    WScript.Quit 2
End If

Set shell = CreateObject("WScript.Shell")

command = "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File " & Quote(args(0)) & _
    " -BridgeRoot " & Quote(args(1)) & _
    " -PollSeconds " & args(2) & _
    " -TaskTimeoutSeconds " & args(3)

shell.Run command, 0, False

Function Quote(value)
    Quote = Chr(34) & Replace(CStr(value), Chr(34), Chr(34) & Chr(34)) & Chr(34)
End Function
