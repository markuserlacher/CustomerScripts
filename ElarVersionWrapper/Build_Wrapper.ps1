# ==============================================================================
# Script: Build-Wrapper.ps1
# Liest Vorlagen aus dem Skript-Ordner, kopiert version.ini und baut EXEn
# ==============================================================================

# Bypassen der Ausführungssperre für diese Session
Set-ExecutionPolicy -Scope Process Bypass -Force

# Configuration
$targetDir = "C:\Program Files (x86)\ElarAdvanced"
$apps      = @("ElarAdvanced", "ArchivExtAdvanced", "ArchivIntAdvanced")
$validDays = 30  # Standard-Gültigkeit ab heute in Tagen

# Quell-Pfade (im Ordner, wo dieses Build-Skript ausgeführt wird)
$scriptLocalDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$wrapperSource  = Join-Path $scriptLocalDir "Wrapper.ps1"
$iniSource      = Join-Path $scriptLocalDir "version.ini"

# Ziel-Pfade im Program Files Ordner
$iniTarget      = Join-Path $targetDir "version.ini"

# PS2EXE Modul sicherstellen
if (-not (Get-Module -ListAvailable -Name PS2EXE)) {
    Install-Module PS2EXE -Scope CurrentUser -Force
}

Add-Type -AssemblyName System.Drawing

# 1. Prüfen ob die benötigten Quelldateien im lokalen Ordner liegen
if (-not (Test-Path $wrapperSource)) {
    Write-Error "Das Wrapper-Skript '$wrapperSource' wurde im aktuellen Ordner nicht gefunden!"
    exit 1
}

if (-not (Test-Path $iniSource)) {
    Write-Error "Die Konfigurationsdatei '$iniSource' wurde im aktuellen Ordner nicht gefunden!"
    exit 1
}

# ------------------------------------------------------------------------------
# STEP 1: version.ini ins Zielverzeichnis kopieren & Inhalte aktualisieren
# ------------------------------------------------------------------------------
Write-Host "=== Verarbeite version.ini ===" -ForegroundColor Cyan

# Wir nehmen die Version der Hauptanwendung aus dem Zielverzeichnis
$mainExePath = Join-Path $targetDir "ElarAdvanced.exe"
if (-not (Test-Path $mainExePath)) {
    $mainExePath = Join-Path $targetDir "ElarAdvanced_core.dat"
}

$extractedVersion = "1.0.0.0"
if (Test-Path $mainExePath) {
    $fileInfo = (Get-Item $mainExePath).VersionInfo.FileVersion
    if (-not [string]::IsNullOrWhiteSpace($fileInfo)) {
        $extractedVersion = $fileInfo.Trim()
    }
}

# Ablaufdatum berechnen (Heute + $validDays um 23:59:59 Uhr)
$expirationDate = (Get-Date).AddDays($validDays).ToString("yyyy-MM-dd 23:59:59")

# 1a. version.ini ins Zielverzeichnis kopieren
Copy-Item -Path $iniSource -Destination $iniTarget -Force
Write-Host "-> 'version.ini' nach '$targetDir' kopiert." -ForegroundColor Yellow

# 1b. INI-Inhalt im Zielverzeichnis mit neuen Werten überschreiben
$iniContent = @"
[AppInfo]
Version=$extractedVersion
ValidUntil=$expirationDate
"@

Set-Content -Path $iniTarget -Value $iniContent -Encoding UTF8
Write-Host "-> 'version.ini' aktualisiert (Version: $extractedVersion | Gültig bis: $expirationDate)" -ForegroundColor Green

# ------------------------------------------------------------------------------
# STEP 2: Icon extrahieren, Original umbenennen & Wrapper kompilieren
# ------------------------------------------------------------------------------
foreach ($appName in $apps) {
    Write-Host "`n=== Verarbeite: $appName ===" -ForegroundColor Cyan
    
    $origExe = Join-Path $targetDir "$appName.exe"
    $coreExe = Join-Path $targetDir "$appName`_core.exe" 
    $icoFile = Join-Path $targetDir "$appName.ico"

    # Original sichern und Icon extrahieren (falls noch nicht geschehen)
    if (Test-Path $origExe) {
        Write-Host "-> Extrahiere Icon..." -ForegroundColor Yellow
        $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($origExe)
        $stream = [System.IO.File]::Create($icoFile)
        $icon.Save($stream)
        $stream.Close()
        $stream.Dispose()
        $icon.Dispose()

	Write-Host "-> Benenne Original um in '$appName`_core.exe'..." -ForegroundColor Yellow
    	Rename-Item -Path $origExe -NewName "$appName`_core.exe" -Force
    }
    elseif (-not (Test-Path $coreExe)) {
        Write-Warning "Weder $appName.exe noch $appName`_core.dat in '$targetDir' gefunden. Überspringe..."
        continue
    }

    # Wrapper kompilieren (nutzt das lokale Wrapper-Skript als Quelle)
    Write-Host "-> Kompiliere Wrapper '$appName.exe'..." -ForegroundColor Green
    
    Invoke-PS2exe `
        -InputFile $wrapperSource `
        -OutputFile $origExe `
        -iconFile $icoFile `
        -title $appName `
        -description "$appName Starter" `
        -noConsole

    # Temporäres ICO-File im Zielverzeichnis aufräumen
    if (Test-Path $icoFile) { Remove-Item $icoFile -Force }
}

Write-Host "`nFertig! Alle Wrapper und version.ini wurden erfolgreich im Zielverzeichnis erstellt." -ForegroundColor Green