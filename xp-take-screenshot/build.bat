@echo off
REM finding your C# compiler, csc
REM dir c:\ /s /b | find "csc.exe" 
REM
REM I have: 
REM c:\WINDOWS\Microsoft.NET\Framework\v2.0.50727\csc.exe
REM c:\WINDOWS\Microsoft.NET\Framework\v3.5\csc.exe
REM c:\WINDOWS\ServicePackFiles\i386\csc.exe

SET mycmd=c:\WINDOWS\Microsoft.NET\Framework\v2.0.50727\csc.exe
REM SET mycmd=c:\WINDOWS\Microsoft.NET\Framework\v3.5\csc.exe
echo Command is: %mycmd%

REM %mycmd% CaptureScreen.cs
REM %mycmd% TestKeybdHook.cs
REM %mycmd% InterceptKeys.cs
%mycmd% InterceptCaptureScreen.cs

