# ==============================================================================
# Script: Restore-Originals.ps1
# Stellt den Urzustand im Zielverzeichnis wieder her
# ==============================================================================

# Bypassen der Ausführungssperre für diese Session
Set-ExecutionPolicy -Scope Process Bypass -Force

$targetDir = "C:\Program Files (x86)\ElarAdvanced"
$apps      = @("ElarAdvanced", "ArchivExtAdvanced", "ArchivIntAdvanced")

Write-Host "=== Stelle Originaldateien wieder her ===" -ForegroundColor Cyan

foreach ($appName in $apps) {
    $wrapperExe = Join-Path $targetDir "$appName.exe"
    $coreExe    = Join-Path $targetDir "$appName`_core.exe"

    # 1. Erzeugte Wrapper-EXE loeschen (falls vorhanden)
    if ((Test-Path $wrapperExe) -and (Test-Path $coreExe)) {
        Write-Host "-> Loesche Wrapper: $appName.exe" -ForegroundColor Yellow
        Remove-Item -Path $wrapperExe -Force
    }

    # 2. _core.dat wieder zur echten .exe umbenennen
    if (Test-Path $coreExe) {
        Write-Host "-> Benenne '$appName`_core.dat' wieder um in '$appName.exe'..." -ForegroundColor Green
        Rename-Item -Path $coreExe -NewName "$appName.exe" -Force
    } else {
        Write-Host "-> Keine '_core.dat' fuer $appName gefunden." -ForegroundColor Gray
    }
}

# 3. version.ini loeschen (optional, falls vollstaendiger Reset erwuenscht)
$iniTarget = Join-Path $targetDir "version.ini"
if (Test-Path $iniTarget) {
    Write-Host "-> Loesche version.ini..." -ForegroundColor Yellow
    Remove-Item -Path $iniTarget -Force
}

Write-Host "`nWiederherstellung abgeschlossen!" -ForegroundColor Green