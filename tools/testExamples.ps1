<#
.SYNOPSIS
    Invokes a specific vRO action and displays its result as JSON.

.DESCRIPTION
    A quick smoke-test / ad-hoc execution script that connects to a vRO server,
    invokes a single action by its GUID, and prints the result as formatted JSON.

    Use this script to:
      - Manually verify that a recently imported action executes correctly.
      - Inspect the raw output of an action during development or debugging.
      - Serve as a minimal template for building more elaborate test harnesses.

.PREREQUISITES
    - PowerShell 6.0+
    - PowervRO module installed (Install-Module PowervRO)
    - Network connectivity to the target vRO server.

.USAGE
    1. Replace the -Server value with your vRO server hostname or IP.
    2. Replace the -Id GUID with the GUID of the action you want to invoke.
       (The GUID appears in the JSDoc @version header of the exported .js file,
        or can be found in the vRO client under the action's General tab.)
    3. Run:
           . .\tools\testExamples.ps1
#>

# Connect to the vRO server.  Adjust the server address, port, and credentials as
# needed.  -IgnoreCertRequirements bypasses SSL validation — remove this flag in
# production environments with properly signed certificates.
Connect-vROServer -Server  vrax.greenscript.net -IgnoreCertRequirements -Port 443 -Username administrator@vsphere.local

# Invoke the target action by its GUID and capture the result.
$result = Invoke-vROAction -Id d064c04d-93a4-4290-b5bf-063ec1dbe5a2

# Display the full result object as indented JSON for easy inspection.
$result | ConvertTo-Json -Depth 99
