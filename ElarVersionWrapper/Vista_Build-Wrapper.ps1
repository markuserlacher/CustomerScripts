# ==============================================================================
# Script:       Vista_Build-Wrapper.ps1
# Description:  Build-Skript für Vista Wrapper mit Versionsvergleich.
# ==============================================================================

Set-ExecutionPolicy -Scope Process Bypass -Force

# Konfiguration
$targetDir = "C:\Program Files (x86)\vista\VISTAClient"
$apps      = @("Vista")
$validDays = 30000  # Standard-Gültigkeit ab heute in Tagen

# Quell-Pfade (im Ordner, wo dieses Build-Skript ausgeführt wird)
$scriptLocalDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$wrapperSource  = Join-Path $scriptLocalDir "Wrapper.ps1"
$iniSource      = Join-Path $scriptLocalDir "version.ini"
$iniTarget      = Join-Path $targetDir "version.ini"

# Pruefen ob die benötigten Quelldateien im lokalen Ordner liegen
if (-not (Test-Path $wrapperSource)) {
    Write-Error "Das Wrapper-Skript '$wrapperSource' wurde im aktuellen Ordner nicht gefunden!"
    exit 1
}

if (-not (Test-Path $iniSource)) {
    Write-Error "Die Konfigurationsdatei '$iniSource' wurde im aktuellen Ordner nicht gefunden!"
    exit 1
}

# PS2EXE Modul sicherstellen
if (-not (Get-Module -ListAvailable -Name PS2EXE)) {
    Install-Module PS2EXE -Scope CurrentUser -Force
}

Add-Type -AssemblyName System.Drawing

# ------------------------------------------------------------------------------
# Hilfsfunktion: Sichere Versionsermittlung als System.Version Objekt
# ------------------------------------------------------------------------------
function Get-FileVersionObj ($filePath) {
    if (-not (Test-Path $filePath)) { return [version]"0.0.0.0" }
    $verStr = (Get-Item $filePath).VersionInfo.FileVersion
    if ([string]::IsNullOrWhiteSpace($verStr)) {
        $verStr = (Get-Item $filePath).VersionInfo.ProductVersion
    }
    try {
        $cleanVer = ($verStr -replace '[^\d\.]', '').Trim('.')
        return [version]$cleanVer
    } catch {
        return [version]"0.0.0.0"
    }
}

# ------------------------------------------------------------------------------
# STEP 1: Verarbeite Anwendungen & erkenne Updates anhand der Version
# ------------------------------------------------------------------------------
foreach ($appName in $apps) {
    Write-Host "`n=== Verarbeite: $appName ===" -ForegroundColor Cyan
    
    $origExe = Join-Path $targetDir "$appName.exe"
    $coreExe = Join-Path $targetDir "$appName`_core.exe"
    $icoFile = Join-Path $targetDir "$appName.ico"

    $origVer = Get-FileVersionObj $origExe
    $coreVer = Get-FileVersionObj $coreExe

    Write-Host "-> Version von $appName.exe      : $origVer" -ForegroundColor Gray
    Write-Host "-> Version von $appName`_core.exe : $coreVer" -ForegroundColor Gray

    # FALL 1: Ein neues Setup wurde ausgeführt! ($origExe ist neuer als $coreExe)
    if ($origVer -gt $coreVer -and $origVer -ne [version]"0.0.0.0") {
        Write-Host "-> Neues Setup erkannt! ($origVer > $coreVer). Aktualisiere Core-Datei..." -ForegroundColor Yellow
        if (Test-Path $coreExe) { Remove-Item -Path $coreExe -Force }
        Rename-Item -Path $origExe -NewName "$appName`_core.exe" -Force
    }
    # FALL 2: Erstes Setup / Keine _core.exe vorhanden
    elseif ((Test-Path $origExe) -and (-not (Test-Path $coreExe))) {
        Write-Host "-> Erstmaliges Setup: Sichere Original als _core.exe..." -ForegroundColor Yellow
        Rename-Item -Path $origExe -NewName "$appName`_core.exe" -Force
    }
    # FALL 3: Kein Update notwendig ($coreExe ist bereits die aktuelle Version)
    elseif (Test-Path $coreExe) {
        Write-Host "-> Kein Anwendungs-Update erkannt. Core-Datei ist bereits auf aktuellem Stand." -ForegroundColor Green
    }
    else {
        Write-Warning "Weder .exe noch _core.exe für $appName in '$targetDir' gefunden. Überspringe..."
        continue
    }

    # Icon aus der gesicherten _core.exe extrahieren
    if (-not (Test-Path $icoFile)) {
        Write-Host "-> Extrahiere Icon aus _core.exe..." -ForegroundColor Yellow
        $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($coreExe)
        $stream = [System.IO.File]::Create($icoFile)
        $icon.Save($stream)
        $stream.Close()
        $stream.Dispose()
        $icon.Dispose()
    }

    # Aktuelle Version für Metadaten & Wrapper sichern
    $currentCoreVer = (Get-FileVersionObj $coreExe).ToString()

    # Wrapper kompilieren
    Write-Host "-> Kompiliere Wrapper '$appName.exe'..." -ForegroundColor Green
    Invoke-PS2exe `
        -InputFile $wrapperSource `
        -OutputFile $origExe `
        -iconFile $icoFile `
        -title $appName `
        -description "$appName Starter" `
        -version $currentCoreVer `
        -noConsole

    if (Test-Path $icoFile) { Remove-Item $icoFile -Force }
}

# ------------------------------------------------------------------------------
# STEP 2: version.ini dynamisch basierend auf allen Apps schreiben
# ------------------------------------------------------------------------------
Write-Host "`n=== Aktualisiere version.ini ===" -ForegroundColor Cyan

$highestVersion = [version]"0.0.0.0"

foreach ($app in $apps) {
    $corePath = Join-Path $targetDir "$app`_core.exe"
    $appVer   = Get-FileVersionObj $corePath
    if ($appVer -gt $highestVersion) {
        $highestVersion = $appVer
    }
}

$latestAppVersion = $highestVersion.ToString()
$expirationDate   = (Get-Date).AddDays($validDays).ToString("yyyy-MM-dd 23:59:59")

Copy-Item -Path $iniSource -Destination $iniTarget -Force

$iniContent = @"
[AppInfo]
Version=$latestAppVersion
ValidUntil=$expirationDate
"@

Set-Content -Path $iniTarget -Value $iniContent -Encoding UTF8
Write-Host "-> 'version.ini' aktualisiert (Höchste Version: $latestAppVersion | Gültig bis: $expirationDate)" -ForegroundColor Green

Write-Host "`nFertig! Alle Wrapper und version.ini wurden erfolgreich erstellt." -ForegroundColor Green
