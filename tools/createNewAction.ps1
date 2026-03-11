<#
.SYNOPSIS
    Creates a new vRO action stub file in a local vROIDE project.

.DESCRIPTION
    Generates a JavaScript action file with a JSDoc annotation template inside the
    appropriate module sub-folder of an existing vROIDE project folder ($vroIdeFolder).

    Use this script when you want to add a brand-new action to a module without first
    exporting it from a live vRO server.  Simply set $moduleName and $actionName below,
    run the script, and a correctly-structured .js stub will appear in
    <vroIdeFolder>/src/<moduleName>/ ready to be edited and then pushed to vRO with
    Import-VroIde.

.PREREQUISITES
    - $vroIdeFolder must already be defined in the current PowerShell session and must
      point to a valid vROIDE project folder (one that was previously created by
      Export-VroIde, or manually structured to match its layout).

.USAGE
    1. Open a PowerShell session and set $vroIdeFolder to your project root, e.g.
           $vroIdeFolder = 'C:\Projects\MyVroProject'
    2. Edit $moduleName and $actionName in this script to match the new action.
    3. Run:
           . .\tools\createNewAction.ps1
    4. Edit the generated stub in src\<moduleName>\<actionName>.js.
    5. Push the action to vRO with Import-VroIde -vroIdeFolder $vroIdeFolder.
#>

# --- Configuration ---------------------------------------------------------------
# Set the fully-qualified vRO module name (dot-separated namespace).
$moduleName = "pso.vmware.nsxt.security"

# Set the camelCase name of the new action.
$actionName = "testMe2"
# ---------------------------------------------------------------------------------

# Build the path to the module folder inside the IDE project.
$moduleFolder = Join-Path $vroIdeFolder -ChildPath "src" -AdditionalChildPath $moduleName
$actionFile = Join-Path $moduleFolder -ChildPath "$actionName.js"

# JSDoc template for a new action.  Customise the @param lines and the function
# body before running Import-VroIde.
$actionContent = @"
/**
* @param {REST:RESTHost} restHost - why the Rest Host
* @param {string} name - why the name
* @version 0.0.0
* @allowedoperations 
* @return {string}
*/
function $actionName(restHost,name) {
`t// Comment line !!;
`treturn 'Successful Action';
};
"@

# Write the stub to disk.
$actionContent | Set-Content $actionFile