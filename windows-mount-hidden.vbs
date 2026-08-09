' Windows Cloud NAS Silent Background Launcher
' Runs windows-mount.bat hidden without keeping a Command Prompt window open

Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "cmd /c C:\rclone\windows-mount.bat", 0, False
