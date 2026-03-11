# tools/

This folder contains helper scripts for day-to-day development with the vROIDE module.
None of these scripts are part of the published module itself — they are **developer
utilities** that you run locally from a PowerShell session.

---

## createNewAction.ps1

### What it does

Creates a new vRO action stub (`.js`) file inside a local vROIDE project folder.  
The generated file includes a JSDoc annotation template (inputs, output type, version,
allowed operations) and a minimal function body, matching the format expected by
`Import-VroIde`.

### When to use it

Use this script when you want to **add a brand-new action** to a module without first
exporting it from a live vRO server — for example when prototyping a new action
entirely locally.

### Prerequisites

- `$vroIdeFolder` must be set in the current PowerShell session and must point to an
  existing vROIDE project root (a folder previously created by `Export-VroIde`, or
  manually structured to match its layout).

### Usage

```powershell
# 1. Set your project root (skip if already set)
$vroIdeFolder = 'C:\Projects\MyVroProject'

# 2. Edit $moduleName and $actionName inside the script, then run:
. .\tools\createNewAction.ps1

# 3. Edit the generated stub:
#    src\<moduleName>\<actionName>.js

# 4. Push the new action to vRO:
Import-VroIde -vroIdeFolder $vroIdeFolder
```

---

## examples.ps1

### What it does

Demonstrates a complete **export → edit → import** round-trip against a live vRO
server:

1. Connect to vRO (reusing an open session if one already exists in the current shell).
2. Export all vRO actions to a local folder with `Export-VroIde`.
3. Open the exported folder in VS Code for manual editing.
4. Import the edited actions back to vRO with `Import-VroIde`.
5. Re-export to confirm the round-trip was successful.
6. Remove the temporary working folder.
7. Disconnect from the vRO server.

Credentials are read from `~/defCreds.json` when present
(format: `{ "server": "", "port": 443, "username": "", "password": "" }`);
otherwise an interactive `Get-Credential` prompt is shown.

### When to use it

Use this script as a **reference implementation** or quick sanity-check of the full
vROIDE workflow.  It is particularly useful when getting started with a new vRO
environment or verifying that the module functions correctly after a code change.

### Prerequisites

- PowerShell 6.0+
- [PowervRO](https://github.com/jakkulabs/PowervRO) module installed
- vROIDE module available (`./src/vroide.psm1`)
- VS Code (`code` command) available in `PATH` (optional — remove the `code` calls if
  not needed)

### Usage

```powershell
# Basic — let the script create a temporary IDE folder automatically:
. .\tools\examples.ps1

# Reuse an existing IDE folder:
$vroIdeFolder = 'C:\Projects\MyVroProject'
. .\tools\examples.ps1
```

---

## testExamples.ps1

### What it does

Connects to a vRO server, invokes a single action by its GUID, and prints the result
as formatted JSON.

### When to use it

Use this script to:

- **Smoke-test** a recently imported action to verify it executes without errors.
- **Inspect** the raw output of an action during development or debugging.
- Use as a **minimal template** when building more elaborate test harnesses.

### Prerequisites

- PowerShell 6.0+
- [PowervRO](https://github.com/jakkulabs/PowervRO) module installed
- Network connectivity to the target vRO server

### Usage

```powershell
# 1. Edit the -Server value and the action -Id (GUID) inside the script.
# 2. Run:
. .\tools\testExamples.ps1
```

The action GUID can be found in the JSDoc header of the exported `.js` file (the value
after `@version`) or in the vRO client under the action's **General** tab.
