' Windows Cloud NAS Silent Background Launcher
' Runs rclone mount hidden without keeping a Command Prompt window open

Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullPath)

' Auto-detect rclone.exe path
rcloneExe = "C:\rclone\rclone.exe"
If Not fso.FileExists(rcloneExe) Then
    If fso.FileExists(scriptDir & "\rclone.exe") Then
        rcloneExe = scriptDir & "\rclone.exe"
    Else
        rcloneExe = "rclone.exe"
    End If
End If

rcloneCmd = """" & rcloneExe & """ mount gcsnas:sv-school Y: --vfs-cache-mode full --vfs-cache-max-size 10G --vfs-cache-max-age 24h --vfs-write-back 1s --gcs-bucket-policy-only --no-modtime"

' Run hidden (0 = hidden window, False = don't wait)
WshShell.Run rcloneCmd, 0, False
