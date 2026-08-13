Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
Q = Chr(34)

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
p1 = fso.GetParentFolderName(scriptDir)
p2 = fso.GetParentFolderName(p1)

rcloneBin = scriptDir & "\rclone.exe"

keyFile = p2 & "\leena-it-solutions-412315-f63f3bd287c1.json"
If Not fso.FileExists(keyFile) Then keyFile = p1 & "\leena-it-solutions-412315-f63f3bd287c1.json"
If Not fso.FileExists(keyFile) Then keyFile = scriptDir & "\leena-it-solutions-412315-f63f3bd287c1.json"

activeUserFile = p2 & "\active_user_mount.json"
If Not fso.FileExists(activeUserFile) Then activeUserFile = p1 & "\active_user_mount.json"
If Not fso.FileExists(activeUserFile) Then activeUserFile = scriptDir & "\active_user_mount.json"

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

' Configure remote with proper path quoting
cmdConfig = Q & rcloneBin & Q & " config create gcsnas googlecloudstorage service_account_file " & Q & keyFile & Q & " bucket_policy_only true"
WshShell.Run cmdConfig, 0, True

remotePath = "gcsnas:sv-school"
readOnlyFlag = ""

If fso.FileExists(activeUserFile) Then
    Set f = fso.OpenTextFile(activeUserFile, 1)
    content = f.ReadAll()
    f.Close()

    If InStr(content, """folder_path"":") > 0 Then
        subPath = Split(Split(content, """folder_path"": """)(1), """")(0)
        subPath = Replace(subPath, "/", "")
        If subPath <> "" Then
            WshShell.Run Q & rcloneBin & Q & " touch gcsnas:sv-school/" & subPath & "/.keep", 0, True
            WshShell.Run Q & rcloneBin & Q & " touch gcsnas:sv-school/.sys/chats/.keep", 0, True
            remotePath = "gcsnas:sv-school/" & subPath
        End If
    End If

    If InStr(content, """permission"": ""Read-Only""") > 0 Then
        readOnlyFlag = "--read-only"
    End If
End If

' 1. Primary Attempt: Native WinFSP Rclone Mount (Completely hidden process using ShowWindow = 0)
cmdMount = Q & rcloneBin & Q & " mount " & remotePath & " " & driveLetter & " --vfs-cache-mode full --vfs-cache-max-size 25G --vfs-cache-max-age 72h --vfs-write-back 1s --dir-cache-time 9999h --vfs-read-chunk-size 64M --vfs-read-chunk-size-limit 1G --vfs-fast-fingerprint --attr-timeout 9999h --contimeout 60s --timeout 60s --low-level-retries 10 --retries 10 --gcs-bucket-policy-only --rc --rc-no-auth --rc-addr 127.0.0.1:5572 --no-modtime --log-level NOTICE " & readOnlyFlag

Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
Set objStartup = objWMIService.Get("Win32_ProcessStartup")
Set objConfig = objStartup.SpawnInstance_
objConfig.ShowWindow = 0 ' SW_HIDE (Completely Hidden Window)

Set objProcess = objWMIService.Get("Win32_Process")
errCode = objProcess.Create(cmdMount, Null, objConfig, intProcessID)

' Wait up to 10 seconds for drive letter to register in WinFSP
For i = 1 To 10
    If fso.DriveExists(driveLetter) Then Exit For
    WScript.Sleep 1000
Next

' 2. Fallback Attempt: WebDAV serve + WebClient Net Use ONLY if WinFsp primary mount failed
If Not fso.DriveExists(driveLetter) Then
    WshShell.Run "taskkill /f /im rclone.exe", 0, True
    cmdWebdav = Q & rcloneBin & Q & " serve webdav " & remotePath & " --addr 127.0.0.1:8080 --vfs-cache-mode full --vfs-cache-max-size 25G --vfs-cache-max-age 72h --vfs-write-back 1s --dir-cache-time 9999h --vfs-read-chunk-size 64M --vfs-read-chunk-size-limit 1G --vfs-fast-fingerprint --attr-timeout 9999h --contimeout 60s --timeout 60s --low-level-retries 10 --retries 10 --gcs-bucket-policy-only --rc --rc-no-auth --rc-addr 127.0.0.1:5572 --no-modtime --log-level NOTICE " & readOnlyFlag
    objProcess.Create cmdWebdav, Null, objConfig, intProcessID
    WScript.Sleep 2000
    WshShell.Run "net start WebClient", 0, True
    WshShell.Run "net use " & driveLetter & " http://127.0.0.1:8080/ /persistent:no", 0, True
End If
