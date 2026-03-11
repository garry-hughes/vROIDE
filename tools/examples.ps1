<#
.SYNOPSIS
    End-to-end example of the vROIDE export → edit → import workflow.

.DESCRIPTION
    This script demonstrates a full round-trip against a live vRealize Orchestrator
    server using the vROIDE module:

      1. Connect to vRO (reusing an existing connection if one is already present).
      2. Export all vRO actions to a local folder with Export-VroIde.
      3. Open the exported folder in VS Code for manual editing.
      4. Import the (edited) actions back to vRO with Import-VroIde.
      5. Re-export to verify the upload was applied correctly.
      6. Clean up the temporary working folder.
      7. Disconnect from the vRO server.

    The script will attempt to load default credentials from ~/defCreds.json
    (format: { "server": "", "port": 443, "username": "", "password": "" }).
    If that file is absent you will be prompted for credentials interactively.

.PREREQUISITES
    - PowerShell 6.0+
    - PowervRO module installed (Install-Module PowervRO)
    - vROIDE module imported (Import-Module ./src/vroide.psm1)

.USAGE
    # Basic — let the script create a new temporary IDE folder:
        . .\tools\examples.ps1

    # Reuse an existing IDE folder:
        $vroIdeFolder = 'C:\Projects\MyVroProject'
        . .\tools\examples.ps1
#>

# Load the vROIDE module from the local source tree.
Import-Module ./src/vroide.psm1 -Force

# --- Connection ------------------------------------------------------------------
# Reuse an existing $vROConnection if one is already open in the session.
if (!$vROConnection){
    if (!$cred){
        # Try to read default credentials from ~/defCreds.json so the script can
        # run non-interactively (e.g. in a CI pipeline or automation task).
        if (Test-Path ~/defCreds.json){
            $defCreds = Get-Content -Raw -Path ~/defCreds.json | ConvertFrom-Json
            $secpasswd = ConvertTo-SecureString $defCreds.password -AsPlainText -Force
            $cred = New-Object System.Management.Automation.PSCredential ($defCreds.username, $secpasswd)
            $server = $defCreds.server
        }else{
            # Fall back to an interactive credential prompt.
            $cred = Get-Credential -UserName "administrator@vsphere.local"
        }
    }
    if ($server){
        Connect-vROServer -Server $server -Credential $cred -IgnoreCertRequirements -Port $defCreds.port -SslProtocol Ssl3
    }else{
        Connect-vROServer -Credential $cred -IgnoreCertRequirements -Port 443 -SslProtocol Ssl3
    }
}

# --- Export ----------------------------------------------------------------------
# Export all vRO actions to a local folder.  If $vroIdeFolder is already set in
# the session the same folder is re-used; otherwise a new temporary folder is
# created and its path is stored in $vroIdeFolder.
if ($vroIdeFolder){
    Export-VroIde -Debug -keepWorkingFolder:$false -vroIdeFolder $vroIdeFolder
}else{
    $vroIdeFolder = Export-VroIde -Debug -keepWorkingFolder:$false #-vroIdeFolder /Users/garryhughes/GIT/my-actions/
}

# Open the exported folder in VS Code for editing.
code $vroIdeFolder

# --- Import & verify -------------------------------------------------------------
# Import the (now-edited) actions back to vRO.
Import-VroIde -vroIdeFolder $vroIdeFolder #-Debug

# Re-export to confirm the round-trip was successful (diff the results in VS Code).
Export-VroIde -Debug -keepWorkingFolder:$false -vroIdeFolder $vroIdeFolder
code $vroIdeFolder

# --- Cleanup ---------------------------------------------------------------------
# Remove the temporary working folder once you are satisfied with the results.
Remove-Item $vroIdeFolder -Recurse -Force -Confirm:$false

# Close the vRO session.
Disconnect-vROServer -Confirm:$false
