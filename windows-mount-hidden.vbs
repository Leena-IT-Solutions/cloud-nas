Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
rcloneBin = scriptDir & "\rclone.exe"
keyFile = scriptDir & "\leena-it-solutions-412315-f63f3bd287c1.json"
activeUserFile = scriptDir & "\active_user_mount.json"

' Terminate existing rclone webdav processes & unmount Z: drive
WshShell.Run "taskkill /f /im rclone.exe", 0, True
WshShell.Run "net use Z: /delete /yes", 0, True

' Configure remote
WshShell.Run """" & rcloneBin & """ config create gcsnas googlecloudstorage service_account_file """ & keyFile & """ bucket_policy_only true", 0, True

remotePath = "gcsnas:sv-school"
readOnlyFlag = ""

' Check Active User Folder Scope & Permission Level
If fso.FileExists(activeUserFile) Then
    Set f = fso.OpenTextFile(activeUserFile, 1)
    content = f.ReadAll()
    f.Close()

    ' Parse folder_path
    If InStr(content, """folder_path"":") > 0 Then
        subPath = Split(Split(content, """folder_path"": """)(1), """")(0)
        subPath = Replace(subPath, "/", "")
        If subPath <> "" Then
            WshShell.Run """" & rcloneBin & """ touch gcsnas:sv-school/" & subPath & "/.keep", 0, True
            WshShell.Run """" & rcloneBin & """ touch gcsnas:sv-school/.sys/chats/.keep", 0, True
            remotePath = "gcsnas:sv-school/" & subPath
        End If
    End If

    ' Parse permission
    If InStr(content, """permission"": ""Read-Only""") > 0 Then
        readOnlyFlag = "--read-only"
    End If
End If

' Start Rclone WebDAV Engine on port 8080 (100% Native Windows, 0 External Dependencies)
cmd = """" & rcloneBin & """ serve webdav " & remotePath & " --addr 127.0.0.1:8080 --vfs-cache-mode full --vfs-cache-max-size 10G --vfs-cache-max-age 24h --vfs-write-back 1s --dir-cache-time 10s --attr-timeout 1s --gcs-bucket-policy-only --rc --rc-no-auth --rc-addr 127.0.0.1:5572 --no-modtime " & readOnlyFlag
WshShell.Run cmd, 0, False

WScript.Sleep 2000

' Ensure WebClient service is running and mount Z: drive natively
WshShell.Run "net start WebClient", 0, True
WshShell.Run "net use Z: http://127.0.0.1:8080 /persistent:no", 0, True
