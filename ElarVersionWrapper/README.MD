# App Expiration Wrapper for Legacy Windows Applications

A lightweight, PowerShell-based toolset designed to enforce dynamic expiration checks (soft-expiration / kill-switch) for Windows desktop applications prior to execution. 

This project was built to prevent client-side access to outdated application versions when backend updates have been deployed and automated software distribution systems (such as Microsoft Intune, SCCM, or Matrix42) have not yet completed their rollout.

---

## 💡 Why This Solution? (Use Case)

In many enterprise environments, client applications are deployed locally (e.g., under `C:\Program Files (x86)\...`). When a breaking change or backend update is implemented on the server or database, launching an outdated client version frequently leads to data corruption, synchronization errors, or unexpected application behavior.

Because software distribution pipelines often roll out updates with staggered schedules, this wrapper fills the critical timing gap:
1. **Error Prevention**: Blocks application startup immediately if the expiration threshold has been reached.
2. **User Experience**: Provides a clean, native GUI dialog (WPF MessageBox) explaining the situation instead of exposing cryptic database or runtime crashes.
3. **Seamless Integration**: Preserves original application names, paths, and native icons completely transparently to the end user.

---

## 🏗️ Architecture & Workflow

The solution relies on executable swapping/hijacking within the application installation directory:

1. **Rename Original Executable**: The original `App.exe` is renamed to `App_core.exe`.
2. **Compile Wrapper**: The `Wrapper.ps1` script is compiled into a new `App.exe` incorporating the original application's embedded icon.
3. **Configuration Deployment**: A `version.ini` file dictates the target version and expiration deadline (`ValidUntil`).
4. **Execution Flow**:
   * The user launches `App.exe` as normal.
   * The wrapper runs silently in the background (no console window), parses `version.ini`, and compares the current system timestamp against `ValidUntil`.
   * **Valid**: The underlying `App_core.exe` is spawned seamlessly.
   * **Expired**: A WPF warning dialog halts execution and instructs the user to wait for the automated software update package.

```
[ User launches App.exe ]
            │
            ▼
  [ Wrapper EXE (No Console) ]
            │
     Parse version.ini
            │
     ┌──────┴──────┐
     ▼             ▼
  [ Valid ]    [ Expired ]
     │             │
Spawns App_core.exe  Displays WPF MessageBox &
                   Aborts Startup
```

---

## 🛠️ External Tools & Modules

This solution is built using native PowerShell capabilities alongside trusted external components:

* **[PS2EXE (WinPS2EXE)](https://github.com/MScholtes/TechNet-Gallery/tree/master/PS2EXE)**  
  * **Author**: Markus Scholtes
  * **Purpose**: Compiles the `Wrapper.ps1` script into a standalone Win32 executable (`.exe`) without a visible console window (`-noConsole`), while embedding extracted application icons.
* **`System.Drawing` (.NET Framework)**: Utilized during the build process to dynamically extract embedded icons directly from the original executable.
* **`PresentationFramework` (WPF)**: Powers native, clean Windows user interface dialogues (`[System.Windows.MessageBox]`).

---

## 📁 Repository Structure

```text
├── Wrapper.ps1           # Core wrapper logic (compiled into <AppName>.exe)
├── Build-Wrapper.ps1     # Automation script for building, icon extraction, and deployment
├── Restore-Originals.ps1 # Rollback utility to revert changes and restore original binaries
├── version.ini           # Configuration template defining version and expiration
└── README.md             # Project documentation
```

---

## 🚀 Setup & Usage Guide

### Prerequisites

* Windows PowerShell 5.1
* Local Administrator privileges (required for modifying paths under `C:\Program Files (x86)\...`)
* Internet connection on initial run of the build script (to automatically fetch the `PS2EXE` module from the PowerShell Gallery)

---

### 1. Configuration

Before running the build automation, adjust the environmental parameters inside `Build-Wrapper.ps1`:

```powershell
# Target directory containing the applications
$targetDir = "C:\Program Files (x86)\ElarAdvanced"

# Array of target application names (excluding the .exe extension)
$apps      = @("ElarAdvanced", "ArchivExtAdvanced", "ArchivIntAdvanced")

# Validity window in days from build execution date
$validDays = 30
```

---

### 2. Running the Build Process

Open an elevated PowerShell prompt (Run as Administrator) in the repository directory and execute:

```powershell
.\Build-Wrapper.ps1
```

**What the build script automates:**
1. Checks for and installs the `PS2EXE` module if missing.
2. Extracts the official file version from the primary executable.
3. Calculates the expiration deadline (`Current Date + $validDays` at `23:59:59`) and generates `version.ini`.
4. Extracts the native application icon from each target executable.
5. Renames `<AppName>.exe` to `<AppName>_core.exe`.
6. Compiles `Wrapper.ps1` into a new `<AppName>.exe` bundled with the extracted icon.

---

### 3. Structure of `version.ini`

The runtime configuration file resides alongside the binaries and follows this standard INI format:

```ini
[AppInfo]
Version=1.4.0
ValidUntil=2026-10-25 23:59:59
```

> **Note:** Timestamps must strictly adhere to the `YYYY-MM-DD HH:MM:SS` format.

---

### 4. Rollback & Restoration

To undo changes and restore the system to its original state prior to wrapper deployment, execute the restoration script:

```powershell
.\Restore-Originals.ps1
```

This utility performs the following actions:
* Deletes the compiled wrapper executables.
* Restores all `<AppName>_core.exe` files back to their original names (`<AppName>.exe`).
* Cleans up the `version.ini` configuration file.

---

## 🔒 Security Considerations

* This implementation acts as a **software governance and compliance mechanism** designed to support controlled software deployments.
* Because configuration files (`version.ini`) and inner binaries (`_core.exe`) reside locally on the client file system, this solution is intended to prevent accidental user launches of outdated clients rather than secure against malicious tampering by local administrators.

---

## 📜 License

Distributed under the terms of the [MIT License](LICENSE).
