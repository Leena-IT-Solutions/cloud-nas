Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
rcloneBin = scriptDir & "\rclone.exe"
keyFile = scriptDir & "\leena-it-solutions-412315-f63f3bd287c1.json"
activeUserFile = scriptDir & "\active_user_mount.json"

' Function to find first unused drive letter (resolves Virtual Machine shared drive collisions)
Function GetFreeDriveLetter()
    Dim letters, i, drv
    letters = Array("Z", "Y", "X", "W", "V", "U", "T", "S", "R", "Q", "P", "O", "N", "M")
    For i = 0 To UBound(letters)
        drv = letters(i) & ":"
        If Not fso.DriveExists(drv) Then
            GetFreeDriveLetter = drv
            Exit Function
        End If
    Next
    GetFreeDriveLetter = "Z:"
End Function

driveLetter = GetFreeDriveLetter()

' Terminate existing rclone processes & clean drive letter if bound
WshShell.Run "taskkill /f /im rclone.exe", 0, True
WshShell.Run "net use " & driveLetter & " /delete /yes", 0, True

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

' 1. Primary Attempt: Rclone Mount with Network Mode (Works inside Virtual Machines & physical PCs)
cmdMount = """" & rcloneBin & """ mount " & remotePath & " " & driveLetter & " --network-mode --vfs-cache-mode full --vfs-cache-max-size 10G --vfs-cache-max-age 24h --vfs-write-back 1s --dir-cache-time 10s --attr-timeout 1s --gcs-bucket-policy-only --rc --rc-no-auth --rc-addr 127.0.0.1:5572 --no-modtime --log-level NOTICE " & readOnlyFlag
WshShell.Run cmdMount, 0, False

WScript.Sleep 2500

' 2. Fallback Attempt: WebDAV serve + WebClient Net Use if drive letter is not yet active
If Not fso.DriveExists(driveLetter) Then
    WshShell.Run "taskkill /f /im rclone.exe", 0, True
    cmdWebdav = """" & rcloneBin & """ serve webdav " & remotePath & " --addr 127.0.0.1:8080 --vfs-cache-mode full --vfs-cache-max-size 10G --vfs-cache-max-age 24h --vfs-write-back 1s --dir-cache-time 10s --attr-timeout 1s --gcs-bucket-policy-only --rc --rc-no-auth --rc-addr 127.0.0.1:5572 --no-modtime --log-level NOTICE " & readOnlyFlag
    WshShell.Run cmdWebdav, 0, False
    WScript.Sleep 2000
    WshShell.Run "net start WebClient", 0, True
    WshShell.Run "net use " & driveLetter & " http://127.0.0.1:8080/ /persistent:no", 0, True
    WshShell.Run "net use " & driveLetter & " \\127.0.0.1@8080\DavWWWRoot /persistent:no", 0, True
End If
