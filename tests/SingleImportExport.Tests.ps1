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

            $actionHeader = $script:vroActionHeaders -as [VroAction]
            $jsPath = $actionHeader.filePath($script:vroIdeFolderSrc, "js")

            # JS file should be created by Export
            $jsPath | Should -Exist

            # JS file must use LF-only line endings — validates Issue #1 cross-platform newline fix
            $jsText = [System.IO.File]::ReadAllText($jsPath)
            $jsText | Should -Not -Match "\r\n"

            # Round-trip: JS should parse back to a VroAction with the correct properties
            $vroAction = ConvertFrom-VroActionJs -InputObject $jsText
            $vroAction.Name | Should -Be "standardAction"
            $vroAction.InputParameters.Count | Should -Be 5
        }
        It "Imports VRO Environment" {
            Import-VroIde -Debug -keepWorkingFolder:$true -vroIdeFolder $script:vroIdeFolder.FullName

            $actionHeader = $script:vroActionHeaders -as [VroAction]

            # Import pipeline should clean up the generated action file after comparison
            $actionHeader.filePath($script:vroIdeFolderSrc, "action") | Should -Not -Exist

            # Locate the working folder created by Import-VroIde (GUID-named dir directly under vroIdeFolder)
            $workingFolder = Get-ChildItem $script:vroIdeFolder -Directory |
                Where-Object { $_.Name -as [guid] } |
                Select-Object -Last 1

            # XML file must exist in the working folder — action was processed
            $xmlPath = $actionHeader.filePath($workingFolder.FullName, "xml")
            $xmlPath | Should -Exist

            # XML must be valid and contain the expected action name
            $xml = [xml](Get-Content $xmlPath -Raw)
            $xml.'dunes-script-module'.name | Should -Be 'standardAction'

            # XML must have the correct number of input parameters
            $xml.'dunes-script-module'.param.Count | Should -Be 5

            # Action was downloaded for comparison; identical files must not trigger an upload
            Should -Invoke Export-vROAction -Times 1 -Exactly -Scope It
            Should -Invoke Import-vROAction -Times 0 -Exactly -Scope It
        }
        It "ConvertFrom-VroActionJs handles CRLF input — validates Issue #1 fix" {
            $action = [VroAction]@{
                Name         = "testAction"
                Description  = "line one`nline two"
                Script       = "var x = 1;"
                OutputType   = "string"
                Version      = "1.0.0"
                AllowedOperations = "vef,evf,vf"  # VRO operation identifiers: view/edit/fetch
            }

            # Build a JS string with LF endings then inject CRLF to mimic Windows output
            $jsLF   = ConvertTo-VroActionJs -InputObject $action
            $jsCRLF = $jsLF -replace "`n", "`r`n"

            # ConvertFrom-VroActionJs normalises CRLF → LF at entry; should parse cleanly
            $result = ConvertFrom-VroActionJs -InputObject $jsCRLF
            $result.Name | Should -Be "testAction"
            $result.Script | Should -Not -Match "\r\n"
        }
        It "Compare-VroActionContents returns true for identical action files — validates Issue #2 fix" {
            $actionFile = Join-Path $PSScriptRoot 'data' 'standardAction.action'

            # Same file compared against itself must always be identical
            $result = Compare-VroActionContents -OriginalVroActionFile $actionFile -UpdatedVroActionFile $actionFile
            $result | Should -Be $true
        }

        Context "Export-VroIde input validation" {
            It "Throws when vroIdeFolder path does not exist" {
                { Export-VroIde -vroIdeFolder '/nonexistent/path/that/does/not/exist' } |
                    Should -Throw "*does not exist*"
            }

            It "Throws when vroIdeFolder path is a file, not a directory" {
                $tmpFile = New-TemporaryFile
                try {
                    { Export-VroIde -vroIdeFolder $tmpFile.FullName } |
                        Should -Throw "*is not a directory*"
                } finally {
                    Remove-Item $tmpFile.FullName -Force
                }
            }
        }

        Context "Import-VroIde input validation" {
            It "Throws when vroIdeFolder path does not exist" {
                { Import-VroIde -vroIdeFolder '/nonexistent/path/that/does/not/exist' } |
                    Should -Throw "*does not exist*"
            }

            It "Throws when vroIdeFolder path is a file, not a directory" {
                $tmpFile = New-TemporaryFile
                try {
                    { Import-VroIde -vroIdeFolder $tmpFile.FullName } |
                        Should -Throw "*is not a directory*"
                } finally {
                    Remove-Item $tmpFile.FullName -Force
                }
            }

            It "Throws when src directory does not exist inside vroIdeFolder" {
                $tmpDir = New-Item -Path (New-TemporaryFile).DirectoryName -Type Directory -Name ([System.Guid]::NewGuid().ToString())
                try {
                    { Import-VroIde -vroIdeFolder $tmpDir.FullName } |
                        Should -Throw "*does not contain a 'src' directory*"
                } finally {
                    Remove-Item $tmpDir.FullName -Recurse -Force
                }
            }

            It "Throws when vroActionHeaders.json does not exist inside src" {
                $tmpDir = New-Item -Path (New-TemporaryFile).DirectoryName -Type Directory -Name ([System.Guid]::NewGuid().ToString())
                $null = New-Item -ItemType Directory -Path (Join-Path $tmpDir.FullName 'src')
                try {
                    { Import-VroIde -vroIdeFolder $tmpDir.FullName } |
                        Should -Throw "*vroActionHeaders.json*"
                } finally {
                    Remove-Item $tmpDir.FullName -Recurse -Force
                }
            }
        }
    }
}
#