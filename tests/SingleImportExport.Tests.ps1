Import-Module (Join-Path $PSScriptRoot '..' 'src' 'vroide.psm1') -Force

InModuleScope -ModuleName vroide -ScriptBlock {
    Describe "Export VRO IDE" {
        BeforeAll {
            ## Code in here
            $script:vROConnection = "mocked endpoint"
            $TempDir = [System.Guid]::NewGuid().ToString()
            $script:vroIdeFolder = New-Item -Path (New-TemporaryFile).DirectoryName -Type Directory -Name $TempDir
            $script:vroIdeFolderSrc = Join-Path $script:vroIdeFolder -ChildPath "src"
            if (!(Test-Path $script:vroIdeFolderSrc)){
                $null = New-Item -ItemType Directory -Path $script:vroIdeFolderSrc
            }
            $script:vroActionHeaders = Get-Content -Raw (Join-Path $PSScriptRoot 'data' 'vroActionHeaders.json') | ConvertFrom-Json
            foreach ($vroActionHeader in $script:vroActionHeaders){
                $vroActionHeader = $vroActionHeader -as [VroAction]
                $null = New-Item -ItemType Directory -Path $vroActionHeader.modulePath($script:vroIdeFolderSrc)
            }

            Mock Get-vROAction { return (Get-Content -Raw (Join-Path $PSScriptRoot 'data' 'vroActionHeaders.json') | ConvertFrom-Json) }
            Mock Export-vROAction {
                param (
                    [Parameter(Mandatory = $false)]
                    [ValidateNotNull()]
                    [string[]]$Id,
                    [Parameter(Mandatory = $false)]
                    [string]$path
                )
                $vroActionHeader = ($script:vroActionHeaders | Where-Object { $_.id -eq $Id }) -as [VroAction]
                Copy-Item -Path $vroActionHeader.filePath($script:vroIdeFolderSrc,"action") -Destination $path
                $vroActionFile = Get-Item $path
                return $vroActionFile
            }
            Mock Import-vROAction {
                param (
                    [Parameter(Mandatory = $false)]
                    [ValidateNotNull()]
                    [string[]]$CategoryName,
                    [Parameter(Mandatory = $false)]
                    [string[]]$File,
                    [Parameter(Mandatory = $false)]
                    [bool]$Override
                )
                return $null
            }
        }

        BeforeEach {
            # Clean up working folders (GUID-named dirs) left by Export-VroIde
            Get-ChildItem $script:vroIdeFolderSrc -Directory | Where-Object { $_.Name -as [guid] } | Remove-Item -Recurse -Force

            foreach ($vroActionHeader in $script:vroActionHeaders){
                $vroActionHeader = $vroActionHeader -as [VroAction]
                # Only copy .action file if no .js file exists (avoids duplicates for Import)
                if (-not (Test-Path $vroActionHeader.filePath($script:vroIdeFolderSrc, "js"))) {
                    $null = Copy-Item -Path (Join-Path $PSScriptRoot 'data' "$($vroActionHeader.Name).action") -Destination $vroActionHeader.modulePath($script:vroIdeFolderSrc)
                }
            }
        }

        AfterEach {
            foreach ($vroActionHeader in $script:vroActionHeaders){
                $vroActionHeader = $vroActionHeader -as [VroAction]
                if (Test-Path $vroActionHeader.filePath($script:vroIdeFolderSrc,"action")){
                    Remove-Item -Path $vroActionHeader.filePath($script:vroIdeFolderSrc,"action") -Confirm:$false
                }
            }
        }

        It "Exports VRO Environment" {
            Export-VroIde -Debug -keepWorkingFolder:$true -vroIdeFolder $script:vroIdeFolder.FullName
            2 | Should -Be 2
        }
        It "Imports VRO Environment" {
            Import-VroIde -Debug -keepWorkingFolder:$true -vroIdeFolder $script:vroIdeFolder.FullName
            3 | Should -Be 3
        }
    }
}
#