Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
rcloneBin = scriptDir & "\rclone.exe"
keyFile = scriptDir & "\leena-it-solutions-412315-f63f3bd287c1.json"

' Terminate existing rclone webdav processes & unmount Z: drive
WshShell.Run "taskkill /f /im rclone.exe", 0, True
WshShell.Run "net use Z: /delete /yes", 0, True

' Configure remote
WshShell.Run """" & rcloneBin & """ config create gcsnas googlecloudstorage service_account_file """ & keyFile & """ bucket_policy_only true", 0, True

' Start Rclone WebDAV Engine on port 8080
cmd = """" & rcloneBin & """ serve webdav gcsnas:sv-school --addr 127.0.0.1:8080 --vfs-cache-mode full --vfs-cache-max-size 10G --vfs-cache-max-age 24h --vfs-write-back 1s --dir-cache-time 10s --attr-timeout 1s --gcs-bucket-policy-only --rc --rc-no-auth --rc-addr 127.0.0.1:5572 --no-modtime"
WshShell.Run cmd, 0, False

WScript.Sleep 2000

' Mount Z: Drive natively using Windows Built-in WebDAV Client (Zero WinFsp required!)
WshShell.Run "net use Z: http://127.0.0.1:8080 /persistent:no", 0, True
