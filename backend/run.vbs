Option Explicit

Dim objShell, objFSO, tempFile, file, line, parts, i
Dim pid, isRunning
Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")

' 临时文件用于存放端口检测结果
tempFile = objFSO.GetSpecialFolder(2) & "\coinscape_port_check.txt"
pid = ""
isRunning = False

' ============================================================
' 1. 检测 9876 端口是否被占用
' ============================================================
' 隐式运行 netstat，提取 9876 端口状态
objShell.Run "cmd.exe /c netstat -ano | findstr :9876 > """ & tempFile & """", 0, True

If objFSO.FileExists(tempFile) Then
    On Error Resume Next
    Set file = objFSO.OpenTextFile(tempFile, 1)
    If Err.Number = 0 Then
        Do While Not file.AtEndOfStream
            line = Trim(file.ReadLine())
            ' 检查是否包含该端口且状态为 LISTENING
            If InStr(line, ":9876 ") > 0 And InStr(line, "LISTENING") > 0 Then
                isRunning = True
                parts = Split(line, " ")
                ' 倒序查找获取 PID
                For i = UBound(parts) To 0 Step -1
                    If Trim(parts(i)) <> "" Then
                        pid = Trim(parts(i))
                        Exit For
                    End If
                Next
            End If
        Loop
        file.Close
    End If
    On Error GoTo 0
    ' 读取完毕后删除临时文件
    objFSO.DeleteFile tempFile, True
End If

' ============================================================
' 2. 根据运行状态执行“启动”或“关闭”
' ============================================================
If isRunning And pid <> "" And pid <> "0" Then
    ' --------- 执行关闭逻辑 ---------
    ' 杀掉后台进程 (0表示隐藏窗口，True表示等待执行完毕)
    objShell.Run "cmd.exe /c taskkill /F /PID " & pid, 0, True
    
    ' 弹出提示框 (vbInformation 提供图标，vbSystemModal 让窗口强制置顶)
    MsgBox "CoinScape 服务器已成功关闭！", vbInformation + vbSystemModal, "服务状态"

Else
    ' --------- 执行启动逻辑 ---------
    ' 切换到后端目录
    objShell.CurrentDirectory = "C:\Users\yxg\Desktop\coinscape\backend"
    
    ' 使用普通的 python，但完全隐藏窗口(0)，并将所有打印输出丢弃(> nul 2>&1)
    objShell.Run "cmd.exe /c python main.py > nul 2>&1", 0, False
    
    ' 弹出提示框
    MsgBox "CoinScape 服务器已在后台静默启动！" & vbCrLf & vbCrLf & "请在浏览器访问: http://localhost:9876", vbInformation + vbSystemModal, "服务状态"

End If

' ============================================================
' 3. 释放资源
' ============================================================
Set objFSO = Nothing
Set objShell = Nothing