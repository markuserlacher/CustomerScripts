# ==============================================================================
# Script:       Wrapper.ps1
# Description:  Wrapper zum Prüfen des Ablaufdatums vor dem Start der Anwendung.
# ==============================================================================

# 1. Pfade & Namen dynamisch ermitteln
# 1. Pfade & Namen dynamisch und robust ermitteln
try {
    # Funktioniert zuverlaessig in PS2EXE kompilierten EXEn sowie in reinen PS1 Skripten
    $wrapperPath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
} catch {
    $wrapperPath = $MyInvocation.MyCommand.Definition
}

# Anfuehrungszeichen vorsichtshalber bereinigen
$wrapperPath = $wrapperPath.Replace('"', '')

$scriptDir   = Split-Path -Parent $wrapperPath
$appName     = [System.IO.Path]::GetFileNameWithoutExtension($wrapperPath)

# Dynamische Zielpfade basierend auf dem eigenen Dateinamen
$coreExePath = Join-Path $scriptDir "$appName`_core.exe"
$iniPath     = Join-Path $scriptDir "version.ini"
# WPF Assemblies laden für saubere Windows MessageBoxen
Add-Type -AssemblyName PresentationFramework

# ------------------------------------------------------------------------------
# Hilfsfunktion: INI-Datei auslesen (ohne externe Abhängigkeiten)
# ------------------------------------------------------------------------------
function Get-IniValue ($filePath, $section, $key) {
    if (-not (Test-Path $filePath)) { return $null }
    
    $content   = Get-Content $filePath -ErrorAction SilentlyContinue
    $inSection = $false
    
    foreach ($line in $content) {
        $line = $line.Trim()
        # Kommentarzeilen ignorieren
        if ($line.StartsWith(";") -or $line.StartsWith("#")) { continue }
        
        # Sektionen prüfen
        if ($line.StartsWith("[") -and $line.EndsWith("]")) {
            $currentSection = $line.Substring(1, $line.Length - 2).Trim()
            $inSection = ($currentSection -eq $section)
        } 
        # Key-Value Paar auslesen
        elseif ($inSection -and $line -match "^$key\s*=\s*(.*)$") {
            return $matches[1].Trim()
        }
    }
    return $null
}

# ------------------------------------------------------------------------------
# MAIN LOGIC
# ------------------------------------------------------------------------------

# Step 1: Prüfen, ob die INI-Konfigurationsdatei existiert
if (-not (Test-Path $iniPath)) {
    [System.Windows.MessageBox]::Show(
        "Die Konfigurationsdatei 'version.ini' wurde im Verzeichnis nicht gefunden.`n`nStart von $appName wird abgebrochen.",
        "$appName - Konfigurationsfehler",
        'OK',
        'Error'
    )
    exit 1
}

# Step 2: Ablaufdatum aus der INI lesen & parsen
$validUntilStr = Get-IniValue $iniPath "AppInfo" "ValidUntil"

if ([string]::IsNullOrWhiteSpace($validUntilStr)) {
    [System.Windows.MessageBox]::Show(
        "In der 'version.ini' wurde kein gültiges Ablaufdatum ('ValidUntil') gefunden.",
        "$appName - Konfigurationsfehler",
        'OK',
        'Error'
    )
    exit 1
}

try {
    $validUntil = [DateTime]::Parse($validUntilStr)
}
catch {
    [System.Windows.MessageBox]::Show(
        "Das Ablaufdatum '$validUntilStr' in der 'version.ini' hat ein ungültiges Format.`n`nErwartet wird z.B. YYYY-MM-DD HH:MM:SS",
        "$appName - Datumsfehler",
        'OK',
        'Error'
    )
    exit 1
}

# Step 3: Datum vergleichen (Ablaufprüfung)
$now = Get-Date

if ($now -ge $validUntil) {
    $formattedDate = $validUntil.ToString("dd.MM.yyyy HH:mm")
    $msg = "Diese Version von $appName ist seit dem $formattedDate Uhr nicht mehr gültig.`n`n" +
           "Das Backend wurde aktualisiert. Bitte warten Sie, bis das automatische Software-Update auf Ihrem Client installiert wurde."

    [System.Windows.MessageBox]::Show(
        $msg,
        "$appName - Update erforderlich",
        'OK',
        'Warning'
    )
    exit 0
}

# Step 4: Prüfung bestanden -> Original-Anwendung (_core.dat) ausführen
if (Test-Path $coreExePath) {
    try {
        # Startet die tatsächliche EXE im selben Verzeichnis und wartet nicht darauf
        Start-Process -FilePath $coreExePath -WorkingDirectory $scriptDir
    }
    catch {
        [System.Windows.MessageBox]::Show(
            "Fehler beim Starten der Anwendungsdatei '$appName`_core.dat':`n$($_.Exception.Message)",
            "$appName - Startfehler",
            'OK',
            'Error'
        )
        exit 1
    }
} 
else {
    [System.Windows.MessageBox]::Show(
        "Die Anwendungsdatei '$appName`_core.dat' wurde nicht gefunden.`n`nBitte stellen Sie sicher, dass die Original-EXE entsprechend umbenannt wurde.",
        "$appName - Datei fehlt",
        'OK',
        'Error'
    )
    exit 1
}