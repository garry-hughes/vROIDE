[![CI](https://github.com/garry-hughes/vROIDE/actions/workflows/ci.yml/badge.svg)](https://github.com/garry-hughes/vROIDE/actions/workflows/ci.yml)

# vROIDE

PowerShell Module housing a set of functions designed to assist with the creation and update of VMware VRO Actions.

There are 2 master functions that import and export Actions for editing locally.

## Prerequisites

- **PowerShell 6.0+** (PowerShell Core / pwsh) — required by the module manifest
- **[PowervRO](https://github.com/jakkulabs/PowervRO)** module — used to connect to and interact with vRealize Orchestrator
- **vRO server access** — network connectivity to your vRealize Orchestrator instance with a valid account

## Quick Start

### Install the module

```powershell
# Install from the PowerShell Gallery
Install-Module -Name vroide -Scope CurrentUser

# Or import from a local clone
Import-Module ./src/vroide.psd1
```

### Connect to vRO

Use the PowervRO module to establish a connection before calling any vROIDE commands:

```powershell
Import-Module PowervRO

Connect-vROServer -Server 'vro.example.com' -Username 'admin' -Password 'P@ssw0rd'
```

### Export all actions to a local IDE folder

```powershell
# Export to a new temporary directory (path is returned)
$ideFolder = Export-VroIde
Write-Host "Actions exported to: $ideFolder"

# Or export to a specific existing directory
Export-VroIde -vroIdeFolder 'C:\Projects\MyVroProject'
```

### Edit actions locally

Open the generated `src/` folder in your favourite editor (VS Code, etc.), make changes to the `.js` files, then push them back to vRO:

```powershell
# Import all changed actions back to vRO
Import-VroIde -vroIdeFolder 'C:\Projects\MyVroProject'
```

### Example output structure

After running `Export-VroIde` the following folder structure is created, ready to be placed under version control:

```
MyVroProject/
├── docs/
│   ├── com.example.utils/
│   │   ├── httpGet.md
│   │   └── parseJson.md
│   └── com.example.network/
│       └── ping.md
├── src/
│   ├── vroActionHeaders.json
│   ├── com.example.utils/
│   │   ├── httpGet.js
│   │   └── parseJson.js
│   └── com.example.network/
│       └── ping.js
└── tests/
    ├── com.example.utils/
    │   ├── httpGet.test.js
    │   └── parseJson.test.js
    └── com.example.network/
        └── ping.test.js
```

Each `.js` file uses JSDoc annotations to carry the action metadata (inputs, output type, description, and GUID) so that it can be round-tripped back to VRO XML without loss.

## Export-VroIde

- Downloads and saves all actions to local system in a folder structure aligning with vro modules
- Extracts the XML content from each of the actions
- Converts the XML to a Javascript file with JSDOC annotation
- As an addition converts the XML to markdown format in a separate folder
- Creates the initial stub for some automated testing

## Import-VroIde

- Converts the Javascript JSDOC to VRO compatible XML.
- Compiles and saves the XML to VRO action format.
- Downloads recent copies of the VRO actions
- Expands the download actions to XML
- Does a File Hash compare of the VRO XML and the Javascript JSDOC converted XML
- If different, will upload the file to VRO.


