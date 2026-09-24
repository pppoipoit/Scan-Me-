<#
.SYNOPSIS
    Scan Me! - Build Standalone Windows Executable (.exe)
.DESCRIPTION
    Compiles a native, lightweight Windows GUI Executable (ScanMe.exe)
    using the built-in .NET Framework C# compiler (csc.exe).
    No black console window, runs seamlessly on any Windows 10/11 machine.
#>

$projectRoot = $PSScriptRoot
$outputExe = Join-Path -Path $projectRoot -ChildPath "ScanMe.exe"
$cscPath = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

if (!(Test-Path -LiteralPath $cscPath)) {
    $cscPath = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe"
}

if (!(Test-Path -LiteralPath $cscPath)) {
    Write-Error "C# Compiler (csc.exe) not found on this system."
    exit 1
}

Write-Host "=== Building Scan Me! Standalone Executable ===" -ForegroundColor Cyan
Write-Host "Compiler: $cscPath" -ForegroundColor Gray

# Temporary C# Source File
$csSource = @"
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace ScanMeApp
{
    static class Program
    {
        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        private static extern int SetCurrentProcessExplicitAppUserModelID(string appID);

        [STAThread]
        static void Main(string[] args)
        {
            const string appUserModelId = "DRKMTTR.ScanMe.1.0";
            SetCurrentProcessExplicitAppUserModelID(appUserModelId);

            try
            {
                string baseDir = AppDomain.CurrentDomain.BaseDirectory;
                string guiScript = Path.Combine(baseDir, "src", "gui", "MainWindow.ps1");

                if (!File.Exists(guiScript))
                {
                    MessageBox.Show(
                        "Cannot find GUI controller script at:\n" + guiScript + 
                        "\n\nPlease ensure the 'src' folder is in the same directory as ScanMe.exe.",
                        "Scan Me! - Startup Error",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error
                    );
                    return;
                }

                // Launch PowerShell in hidden window mode with STA and Bypass ExecutionPolicy
                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = "powershell.exe";
                psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File \"" + guiScript + "\"";
                psi.WorkingDirectory = baseDir;
                psi.UseShellExecute = false;
                psi.CreateNoWindow = true;
                psi.WindowStyle = ProcessWindowStyle.Hidden;
                psi.EnvironmentVariables["SCANME_EXE_PATH"] = Path.Combine(baseDir, "ScanMe.exe");

                using (Process proc = Process.Start(psi))
                {
                    if (proc != null)
                    {
                        proc.WaitForExit();
                    }
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    "Failed to start Scan Me! Application:\n" + ex.Message,
                    "Scan Me! - Fatal Error",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error
                );
            }
        }
    }
}
"@

$tempCsPath = Join-Path -Path $env:TEMP -ChildPath "ScanMe_Build.cs"
[System.IO.File]::WriteAllText($tempCsPath, $csSource, [System.Text.Encoding]::UTF8)

# Compile to WinExe (No Command Prompt Window)
$icoPath = Join-Path -Path $projectRoot -ChildPath "assets\app.ico"
if (!(Test-Path -LiteralPath $icoPath)) {
    Write-Error "Canonical icon not found: $icoPath. Normalize scan me!.ico before building."
    exit 1
}

$compileArgs = @(
    "/target:winexe",
    "/optimize+",
    "/platform:anycpu"
)

if (Test-Path -LiteralPath $icoPath) {
    $compileArgs += "/win32icon:`"$icoPath`""
    Write-Host "Embedding Icon: $icoPath" -ForegroundColor Cyan
}

$compileArgs += @(
    "/out:`"$outputExe`"",
    "`"$tempCsPath`"",
    "/r:System.dll",
    "/r:System.Windows.Forms.dll"
)

$process = Start-Process -FilePath $cscPath -ArgumentList ($compileArgs -join " ") -NoNewWindow -Wait -PassThru

if (Test-Path -LiteralPath $tempCsPath) {
    Remove-Item -Path $tempCsPath -Force -ErrorAction SilentlyContinue
}

if ($process.ExitCode -eq 0 -and (Test-Path -LiteralPath $outputExe)) {
    Write-Host "`n✅ Successfully generated: $outputExe" -ForegroundColor Green
    Write-Host "You can now distribute or double-click ScanMe.exe directly!" -ForegroundColor Yellow
} else {
    Write-Error "Compilation failed with exit code $($process.ExitCode)"
}
