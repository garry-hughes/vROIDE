Import-Module (Join-Path $PSScriptRoot '..' 'src' 'vroide.psm1') -Force

InModuleScope -ModuleName vroide -ScriptBlock {
    Describe "Conversion Functions" {

        BeforeAll {
            # Standard VRO action XML used across multiple tests
            $script:standardActionXml = [xml]@'
<?xml version="1.0" encoding="UTF-8"?>
<dunes-script-module name="testAction" result-type="Array/string" api-version="6.0.0" id="af224e48-8421-4f8b-b5ed-8f0de4d8c38c" version="1.2.3" allowed-operations="vef">
  <description><![CDATA[Test description line one
line two]]></description>
  <param n="param1" t="number"><![CDATA[first param]]></param>
  <param n="param2" t="string"><![CDATA[second param]]></param>
  <script encoded="false"><![CDATA[var x = 1;]]></script>
</dunes-script-module>
'@

            # Standard VroAction with plain (non-brace-wrapped) types, as produced by ConvertFrom-VroActionXml
            $script:standardVroAction = [VroAction]@{
                Id                = [guid]'af224e48-8421-4f8b-b5ed-8f0de4d8c38c'
                Name              = 'testAction'
                Description       = "Test description line one`nline two"
                Version           = '1.2.3'
                OutputType        = 'Array/string'
                AllowedOperations = 'vef'
                Script            = 'var x = 1;'
                InputParameters   = @(
                    [VroActionInput]@{ name = 'param1'; type = 'number'; description = 'first param' },
                    [VroActionInput]@{ name = 'param2'; type = 'string'; description = 'second param' }
                )
            }
        }

        Context "ConvertFrom-VroActionXml" {

            It "Populates Name from XML attribute" {
                $result = ConvertFrom-VroActionXml -InputObject $script:standardActionXml
                $result.Name | Should -Be 'testAction'
            }

            It "Populates Description from CDATA section" {
                $result = ConvertFrom-VroActionXml -InputObject $script:standardActionXml
                $result.Description | Should -Be "Test description line one`nline two"
            }

            It "Populates OutputType from result-type attribute" {
                $result = ConvertFrom-VroActionXml -InputObject $script:standardActionXml
                $result.OutputType | Should -Be 'Array/string'
            }

            It "Populates Version from version attribute" {
                $result = ConvertFrom-VroActionXml -InputObject $script:standardActionXml
                $result.Version | Should -Be '1.2.3'
            }

            It "Populates Id from id attribute" {
                $result = ConvertFrom-VroActionXml -InputObject $script:standardActionXml
                $result.Id | Should -Be 'af224e48-8421-4f8b-b5ed-8f0de4d8c38c'
            }

            It "Populates AllowedOperations from allowed-operations attribute" {
                $result = ConvertFrom-VroActionXml -InputObject $script:standardActionXml
                $result.AllowedOperations | Should -Be 'vef'
            }

            It "Populates Script from script CDATA section" {
                $result = ConvertFrom-VroActionXml -InputObject $script:standardActionXml
                $result.Script | Should -Be 'var x = 1;'
            }

            It "Populates InputParameters with correct count" {
                $result = ConvertFrom-VroActionXml -InputObject $script:standardActionXml
                $result.InputParameters.Count | Should -Be 2
            }

            It "Populates InputParameters with correct names, types and descriptions" {
                $result = ConvertFrom-VroActionXml -InputObject $script:standardActionXml
                $result.InputParameters[0].name        | Should -Be 'param1'
                $result.InputParameters[0].type        | Should -Be 'number'
                $result.InputParameters[0].description | Should -Be 'first param'
                $result.InputParameters[1].name        | Should -Be 'param2'
                $result.InputParameters[1].type        | Should -Be 'string'
                $result.InputParameters[1].description | Should -Be 'second param'
            }
        }

        Context "ConvertTo-VroActionJs" {

            BeforeAll {
                $script:jsOutput = ConvertTo-VroActionJs -InputObject $script:standardVroAction
            }

            It "Output starts with JSDoc opening comment marker" {
                $script:jsOutput | Should -Match '(?m)^/\*\*'
            }

            It "Output contains description lines in JSDoc header" {
                $script:jsOutput | Should -Match '\* Test description line one'
                $script:jsOutput | Should -Match '\* line two'
            }

            It "Output contains @param entries for each input" {
                $script:jsOutput | Should -Match '\* @param \{number\} param1 - first param'
                $script:jsOutput | Should -Match '\* @param \{string\} param2 - second param'
            }

            It "Output contains @id metadata tag" {
                $script:jsOutput | Should -Match '\* @id af224e48-8421-4f8b-b5ed-8f0de4d8c38c'
            }

            It "Output contains @version metadata tag" {
                $script:jsOutput | Should -Match '\* @version 1\.2\.3'
            }

            It "Output contains @allowedoperations metadata tag" {
                $script:jsOutput | Should -Match '\* @allowedoperations vef'
            }

            It "Output contains @return tag with output type" {
                $script:jsOutput | Should -Match '\* @return \{Array/string\}'
            }

            It "Output contains JSDoc closing comment marker" {
                $script:jsOutput | Should -Match '\*/'
            }

            It "Output contains function signature with correct name and parameters" {
                $script:jsOutput | Should -Match 'function testAction\(param1,param2\)'
            }

            It "Output contains script body with tab indentation" {
                $script:jsOutput | Should -Match "`tvar x = 1;"
            }

            It "Output ends with function closing brace and semicolon" {
                $script:jsOutput | Should -Match '};$'
            }

            It "Output uses LF-only line endings" {
                $script:jsOutput | Should -Not -Match "`r`n"
            }
        }

        Context "ConvertFrom-VroActionJs" {

            BeforeAll {
                # Build a known JS string that ConvertTo-VroActionJs would produce, then parse it
                $script:sourceAction = [VroAction]@{
                    Id                = [guid]'af224e48-8421-4f8b-b5ed-8f0de4d8c38c'
                    Name              = 'roundTripAction'
                    Description       = "Round-trip description`nsecond line"
                    Version           = '2.0.1'
                    OutputType        = 'string'
                    AllowedOperations = 'evf'
                    Script            = 'return "hello";'
                    InputParameters   = @(
                        [VroActionInput]@{ name = 'inputA'; type = 'number'; description = 'a number input' }
                    )
                }
                $script:sourceJs     = ConvertTo-VroActionJs -InputObject $script:sourceAction
                $script:parsedAction = ConvertFrom-VroActionJs -InputObject $script:sourceJs
            }

            It "Extracts correct Name" {
                $script:parsedAction.Name | Should -Be 'roundTripAction'
            }

            It "Extracts correct Description" {
                $script:parsedAction.Description | Should -Be "Round-trip description`nsecond line"
            }

            It "Extracts correct Version" {
                $script:parsedAction.Version | Should -Be '2.0.1'
            }

            It "Extracts correct Id" {
                $script:parsedAction.Id | Should -Be 'af224e48-8421-4f8b-b5ed-8f0de4d8c38c'
            }

            It "Extracts correct AllowedOperations" {
                $script:parsedAction.AllowedOperations | Should -Be 'evf'
            }

            It "Extracts OutputType (wrapped in braces as parsed from JSDoc)" {
                $script:parsedAction.OutputType | Should -Be '{string}'
            }

            It "Extracts correct InputParameters count" {
                $script:parsedAction.InputParameters.Count | Should -Be 1
            }

            It "Extracts correct InputParameter name" {
                $script:parsedAction.InputParameters[0].name | Should -Be 'inputA'
            }

            It "Extracts correct InputParameter description" {
                $script:parsedAction.InputParameters[0].description | Should -Be 'a number input'
            }

            It "Normalises CRLF line endings to LF in parsed Script" {
                $jsCRLF = $script:sourceJs -replace "`n", "`r`n"
                $result  = ConvertFrom-VroActionJs -InputObject $jsCRLF
                $result.Script | Should -Not -Match "`r`n"
            }

            It "Throws descriptive error when JSDoc header is missing" {
                $noHeader = "function myAction() {`n`treturn 1;`n};"
                { ConvertFrom-VroActionJs -InputObject $noHeader } | Should -Throw "*Could not parse JSDoc header*"
            }

            It "Throws descriptive error when function body is missing" {
                $noBody = "/**`n* @id 00000000-0000-0000-0000-000000000001`n*/"
                { ConvertFrom-VroActionJs -InputObject $noBody } | Should -Throw "*Could not parse function body*"
            }

            It "Throws descriptive error when function name is missing" {
                $anonFunc = "/**`n* @id 00000000-0000-0000-0000-000000000001`n*/`nfunction () {`n`treturn 1;`n};"
                { ConvertFrom-VroActionJs -InputObject $anonFunc } | Should -Throw "*Could not extract function name*"
            }
        }

        Context "ConvertTo-VroActionXml" {

            BeforeAll {
                $script:xmlOutput = ConvertTo-VroActionXml -InputObject $script:standardVroAction
            }

            It "Returns an XML document with dunes-script-module root element" {
                $script:xmlOutput.'dunes-script-module' | Should -Not -BeNullOrEmpty
            }

            It "Root element has correct name attribute" {
                $script:xmlOutput.'dunes-script-module'.name | Should -Be 'testAction'
            }

            It "Root element has correct result-type attribute" {
                $script:xmlOutput.'dunes-script-module'.'result-type' | Should -Be 'Array/string'
            }

            It "Root element has api-version set to 6.0.0 by default" {
                $script:xmlOutput.'dunes-script-module'.'api-version' | Should -Be '6.0.0'
            }

            It "Root element uses custom ApiVersion when specified" {
                $result = ConvertTo-VroActionXml -InputObject $script:standardVroAction -ApiVersion '7.1.0'
                $result.'dunes-script-module'.'api-version' | Should -Be '7.1.0'
            }

            It "Root element has correct id attribute" {
                $script:xmlOutput.'dunes-script-module'.id | Should -Be 'af224e48-8421-4f8b-b5ed-8f0de4d8c38c'
            }

            It "Root element has correct version attribute" {
                $script:xmlOutput.'dunes-script-module'.version | Should -Be '1.2.3'
            }

            It "Root element has correct allowed-operations attribute" {
                $script:xmlOutput.'dunes-script-module'.'allowed-operations' | Should -Be 'vef'
            }

            It "Contains description element with CDATA text" {
                $script:xmlOutput.'dunes-script-module'.description.'#cdata-section' | Should -Be "Test description line one`nline two"
            }

            It "Contains correct number of param elements" {
                $script:xmlOutput.'dunes-script-module'.param.Count | Should -Be 2
            }

            It "Param elements have correct n and t attributes" {
                $params = $script:xmlOutput.'dunes-script-module'.param
                $params[0].n | Should -Be 'param1'
                $params[0].t | Should -Be 'number'
                $params[1].n | Should -Be 'param2'
                $params[1].t | Should -Be 'string'
            }

            It "Param elements have CDATA descriptions" {
                $params = $script:xmlOutput.'dunes-script-module'.param
                $params[0].'#cdata-section' | Should -Be 'first param'
                $params[1].'#cdata-section' | Should -Be 'second param'
            }

            It "Contains script element with encoded=false attribute" {
                $script:xmlOutput.'dunes-script-module'.script.encoded | Should -Be 'false'
            }

            It "Contains script element with correct CDATA content" {
                $script:xmlOutput.'dunes-script-module'.script.'#cdata-section' | Should -Match 'var x = 1;'
            }
        }

        Context "ConvertTo-VroActionMd" {

            BeforeAll {
                $script:mdOutput = ConvertTo-VroActionMd -InputObject $script:standardVroAction
            }

            It "Output starts with H1 title containing action name" {
                $script:mdOutput | Should -Match '(?m)^# VRO Action - testAction'
            }

            It "Output contains Description H2 section" {
                $script:mdOutput | Should -Match '## Description'
            }

            It "Output contains description text" {
                $script:mdOutput | Should -Match 'Test description line one'
            }

            It "Output contains Inputs H2 section" {
                $script:mdOutput | Should -Match '## Inputs'
            }

            It "Output contains formatted input parameter entries" {
                $script:mdOutput | Should -Match '\[number\]param1 : first param'
                $script:mdOutput | Should -Match '\[string\]param2 : second param'
            }

            It "Output contains Metadata H2 section" {
                $script:mdOutput | Should -Match '## Metadata'
            }

            It "Output contains ID in metadata" {
                $script:mdOutput | Should -Match 'af224e48-8421-4f8b-b5ed-8f0de4d8c38c'
            }

            It "Output contains Version in metadata" {
                $script:mdOutput | Should -Match 'Version : 1\.2\.3'
            }

            It "Output contains Allowed Operations in metadata" {
                $script:mdOutput | Should -Match 'Allowed Operations : vef'
            }

            It "Output contains Output Type in metadata" {
                $script:mdOutput | Should -Match 'Output Type : \[Array/string\]'
            }

            It "Output contains Script H2 section" {
                $script:mdOutput | Should -Match '## Script'
            }

            It "Output wraps script in javascript code fence" {
                $script:mdOutput | Should -Match '(?m)^```javascript'
                $script:mdOutput | Should -Match '(?m)^```$'
            }

            It "Output contains script body inside code fence" {
                $script:mdOutput | Should -Match 'var x = 1;'
            }
        }

        Context "Export-VroActionFile" {

            BeforeAll {
                $script:exportTestDir = New-Item -Path (New-TemporaryFile).DirectoryName -Type Directory -Name ([System.Guid]::NewGuid().ToString())
                $script:exportXml = ConvertTo-VroActionXml -InputObject $script:standardVroAction
            }

            AfterAll {
                if (Test-Path $script:exportTestDir.FullName) {
                    Remove-Item $script:exportTestDir.FullName -Recurse -Force
                }
            }

            It "Produces a .action file in the export folder" {
                Export-VroActionFile -InputObject $script:exportXml -exportFolder $script:exportTestDir.FullName
                $actionFile = Join-Path $script:exportTestDir.FullName 'testAction.action'
                $actionFile | Should -Exist
            }

            It "action-info contains default creator www.dunes.ch" {
                $actionFile = Join-Path $script:exportTestDir.FullName 'testAction.action'
                $tmpExtract = New-Item -Path $script:exportTestDir.FullName -Name 'extract-default' -Type Directory
                Expand-Archive -Path $actionFile -DestinationPath $tmpExtract.FullName -Force
                $infoContent = Get-Content (Join-Path $tmpExtract.FullName 'action-info') -Raw
                $infoContent | Should -Match 'creator=www\.dunes\.ch'
            }

            It "action-info contains custom creator when specified" {
                $customDir = New-Item -Path $script:exportTestDir.FullName -Name 'custom-creator' -Type Directory
                Export-VroActionFile -InputObject $script:exportXml -exportFolder $customDir.FullName -Creator 'custom@example.com'
                $actionFile = Join-Path $customDir.FullName 'testAction.action'
                $tmpExtract = New-Item -Path $script:exportTestDir.FullName -Name 'extract-custom' -Type Directory
                Expand-Archive -Path $actionFile -DestinationPath $tmpExtract.FullName -Force
                $infoContent = Get-Content (Join-Path $tmpExtract.FullName 'action-info') -Raw
                $infoContent | Should -Match 'creator=custom@example\.com'
            }

            It "action-info contains a current-year timestamp" {
                $actionFile = Join-Path $script:exportTestDir.FullName 'testAction.action'
                $tmpExtract = New-Item -Path $script:exportTestDir.FullName -Name 'extract-ts' -Type Directory
                Expand-Archive -Path $actionFile -DestinationPath $tmpExtract.FullName -Force
                $infoContent = Get-Content (Join-Path $tmpExtract.FullName 'action-info') -Raw
                $currentYear = (Get-Date).Year.ToString()
                $infoContent | Should -Match $currentYear
            }

            It "action-info does not contain the old hardcoded 2019 timestamp" {
                $actionFile = Join-Path $script:exportTestDir.FullName 'testAction.action'
                $tmpExtract = New-Item -Path $script:exportTestDir.FullName -Name 'extract-ts2' -Type Directory
                Expand-Archive -Path $actionFile -DestinationPath $tmpExtract.FullName -Force
                $infoContent = Get-Content (Join-Path $tmpExtract.FullName 'action-info') -Raw
                $infoContent | Should -Not -Match '2019'
            }
        }

        Context "Edge Cases" {

            BeforeAll {
                # Action with no input parameters
                $script:noParamsActionXml = [xml]@'
<?xml version="1.0" encoding="UTF-8"?>
<dunes-script-module name="noParamsAction" result-type="string" api-version="6.0.0" id="11111111-1111-1111-1111-111111111111" version="1.0.0" allowed-operations="vef">
  <description><![CDATA[No parameters here]]></description>
  <script encoded="false"><![CDATA[return "hello";]]></script>
</dunes-script-module>
'@
                $script:noParamsVroAction = [VroAction]@{
                    Id                = [guid]'11111111-1111-1111-1111-111111111111'
                    Name              = 'noParamsAction'
                    Description       = 'No parameters here'
                    Version           = '1.0.0'
                    OutputType        = 'string'
                    AllowedOperations = 'vef'
                    Script            = 'return "hello";'
                    InputParameters   = @()
                }

                # Action with no description
                $script:noDescActionXml = [xml]@'
<?xml version="1.0" encoding="UTF-8"?>
<dunes-script-module name="noDescAction" result-type="void" api-version="6.0.0" id="22222222-2222-2222-2222-222222222222" version="0.1.0" allowed-operations="vef">
  <param n="input1" t="string"><![CDATA[a string]]></param>
  <script encoded="false"><![CDATA[System.log(input1);]]></script>
</dunes-script-module>
'@
                $script:noDescVroAction = [VroAction]@{
                    Id                = [guid]'22222222-2222-2222-2222-222222222222'
                    Name              = 'noDescAction'
                    Description       = ''
                    Version           = '0.1.0'
                    OutputType        = 'void'
                    AllowedOperations = 'vef'
                    Script            = 'System.log(input1);'
                    InputParameters   = @(
                        [VroActionInput]@{ name = 'input1'; type = 'string'; description = 'a string' }
                    )
                }

                # Action with multi-line description (3 lines)
                $script:multiLineDescActionXml = [xml]@'
<?xml version="1.0" encoding="UTF-8"?>
<dunes-script-module name="multiLineDescAction" result-type="boolean" api-version="6.0.0" id="33333333-3333-3333-3333-333333333333" version="3.2.1" allowed-operations="vef">
  <description><![CDATA[Line one
Line two
Line three]]></description>
  <script encoded="false"><![CDATA[return true;]]></script>
</dunes-script-module>
'@
                $script:multiLineDescVroAction = [VroAction]@{
                    Id                = [guid]'33333333-3333-3333-3333-333333333333'
                    Name              = 'multiLineDescAction'
                    Description       = "Line one`nLine two`nLine three"
                    Version           = '3.2.1'
                    OutputType        = 'boolean'
                    AllowedOperations = 'vef'
                    Script            = 'return true;'
                    InputParameters   = @()
                }

                # Action with special characters in description and parameter descriptions
                $script:specialCharsActionXml = [xml]@'
<?xml version="1.0" encoding="UTF-8"?>
<dunes-script-module name="specialCharsAction" result-type="string" api-version="6.0.0" id="44444444-4444-4444-4444-444444444444" version="1.0.0" allowed-operations="vef">
  <description><![CDATA[Uses <tags> & "quotes" -- special chars]]></description>
  <param n="param1" t="string"><![CDATA[value with <angle> & "quotes"]]></param>
  <script encoded="false"><![CDATA[return param1;]]></script>
</dunes-script-module>
'@
                $script:specialCharsVroAction = [VroAction]@{
                    Id                = [guid]'44444444-4444-4444-4444-444444444444'
                    Name              = 'specialCharsAction'
                    Description       = 'Uses <tags> & "quotes" -- special chars'
                    Version           = '1.0.0'
                    OutputType        = 'string'
                    AllowedOperations = 'vef'
                    Script            = 'return param1;'
                    InputParameters   = @(
                        [VroActionInput]@{ name = 'param1'; type = 'string'; description = 'value with <angle> & "quotes"' }
                    )
                }

                # Action with no script body
                $script:noScriptActionXml = [xml]@'
<?xml version="1.0" encoding="UTF-8"?>
<dunes-script-module name="noScriptAction" result-type="void" api-version="6.0.0" id="55555555-5555-5555-5555-555555555555" version="1.0.0" allowed-operations="vef">
  <description><![CDATA[An action with no script body]]></description>
  <param n="input1" t="number"><![CDATA[a number]]></param>
</dunes-script-module>
'@
                $script:noScriptVroAction = [VroAction]@{
                    Id                = [guid]'55555555-5555-5555-5555-555555555555'
                    Name              = 'noScriptAction'
                    Description       = 'An action with no script body'
                    Version           = '1.0.0'
                    OutputType        = 'void'
                    AllowedOperations = 'vef'
                    Script            = ''
                    InputParameters   = @(
                        [VroActionInput]@{ name = 'input1'; type = 'number'; description = 'a number' }
                    )
                }
            }

            Context "ConvertFrom-VroActionXml" {

                It "Returns empty InputParameters for action with no params" {
                    $result = ConvertFrom-VroActionXml -InputObject $script:noParamsActionXml
                    $result.InputParameters.Count | Should -Be 0
                }

                It "Returns empty Description for action with no description element" {
                    $result = ConvertFrom-VroActionXml -InputObject $script:noDescActionXml
                    $result.Description | Should -BeNullOrEmpty
                }

                It "Preserves all lines of a multi-line description" {
                    $result = ConvertFrom-VroActionXml -InputObject $script:multiLineDescActionXml
                    $result.Description | Should -Be "Line one`nLine two`nLine three"
                }

                It "Preserves special characters in description CDATA" {
                    $result = ConvertFrom-VroActionXml -InputObject $script:specialCharsActionXml
                    $result.Description | Should -Be 'Uses <tags> & "quotes" -- special chars'
                }

                It "Preserves special characters in input parameter description CDATA" {
                    $result = ConvertFrom-VroActionXml -InputObject $script:specialCharsActionXml
                    $result.InputParameters[0].description | Should -Be 'value with <angle> & "quotes"'
                }

                It "Returns empty Script for action with no script element" {
                    $result = ConvertFrom-VroActionXml -InputObject $script:noScriptActionXml
                    $result.Script | Should -BeNullOrEmpty
                }
            }

            Context "ConvertTo-VroActionJs" {

                It "Produces empty parameter list in function signature for action with no inputs" {
                    $result = ConvertTo-VroActionJs -InputObject $script:noParamsVroAction
                    $result | Should -Match 'function noParamsAction\(\)'
                }

                It "Omits @param entries from JSDoc for action with no inputs" {
                    $result = ConvertTo-VroActionJs -InputObject $script:noParamsVroAction
                    $result | Should -Not -Match '@param'
                }

                It "Omits description lines from JSDoc for action with no description" {
                    $result = ConvertTo-VroActionJs -InputObject $script:noDescVroAction
                    $result | Should -Match ('/\*\*' + "`n" + '\* @param')
                }

                It "Includes all lines of a multi-line description in JSDoc" {
                    $result = ConvertTo-VroActionJs -InputObject $script:multiLineDescVroAction
                    $result | Should -Match '\* Line one'
                    $result | Should -Match '\* Line two'
                    $result | Should -Match '\* Line three'
                }

                It "Preserves special characters in JSDoc description" {
                    $result = ConvertTo-VroActionJs -InputObject $script:specialCharsVroAction
                    $result | Should -Match ([regex]::Escape('Uses <tags> & "quotes" -- special chars'))
                }

                It "Produces function with empty body for action with no script" {
                    $result = ConvertTo-VroActionJs -InputObject $script:noScriptVroAction
                    $result | Should -Match ('function noScriptAction\(input1\) \{' + "`n" + '\};')
                }
            }

            Context "ConvertTo-VroActionXml" {

                It "Produces no param elements for action with no inputs" {
                    $result = ConvertTo-VroActionXml -InputObject $script:noParamsVroAction
                    $result.'dunes-script-module'.param | Should -BeNullOrEmpty
                }

                It "Produces no description element for action with no description" {
                    $result = ConvertTo-VroActionXml -InputObject $script:noDescVroAction
                    $result.'dunes-script-module'.description | Should -BeNullOrEmpty
                }

                It "Preserves multi-line description as CDATA in description element" {
                    $result = ConvertTo-VroActionXml -InputObject $script:multiLineDescVroAction
                    $result.'dunes-script-module'.description.'#cdata-section' | Should -Be "Line one`nLine two`nLine three"
                }

                It "Preserves special characters in description CDATA" {
                    $result = ConvertTo-VroActionXml -InputObject $script:specialCharsVroAction
                    $result.'dunes-script-module'.description.'#cdata-section' | Should -Be 'Uses <tags> & "quotes" -- special chars'
                }

                It "Preserves special characters in param description CDATA" {
                    $result = ConvertTo-VroActionXml -InputObject $script:specialCharsVroAction
                    $result.'dunes-script-module'.param.'#cdata-section' | Should -Be 'value with <angle> & "quotes"'
                }

                It "Produces no script element for action with no script body" {
                    $result = ConvertTo-VroActionXml -InputObject $script:noScriptVroAction
                    $result.'dunes-script-module'.script | Should -BeNullOrEmpty
                }
            }

            Context "ConvertTo-VroActionMd" {

                It "Omits Inputs section for action with no input parameters" {
                    $result = ConvertTo-VroActionMd -InputObject $script:noParamsVroAction
                    $result | Should -Not -Match '## Inputs'
                }

                It "Omits Description section for action with no description" {
                    $result = ConvertTo-VroActionMd -InputObject $script:noDescVroAction
                    $result | Should -Not -Match '## Description'
                }

                It "Includes all lines of a multi-line description in Markdown output" {
                    $result = ConvertTo-VroActionMd -InputObject $script:multiLineDescVroAction
                    $result | Should -Match 'Line one'
                    $result | Should -Match 'Line two'
                    $result | Should -Match 'Line three'
                }

                It "Preserves special characters in Markdown description" {
                    $result = ConvertTo-VroActionMd -InputObject $script:specialCharsVroAction
                    $result | Should -Match ([regex]::Escape('Uses <tags> & "quotes" -- special chars'))
                }

                It "Omits script code fence for action with no script body" {
                    $result = ConvertTo-VroActionMd -InputObject $script:noScriptVroAction
                    $result | Should -Not -Match '```javascript'
                }
            }
        }

        Context "Compare-VroActionContents" {

            BeforeAll {
                $script:compareTestDir = New-Item -Path (New-TemporaryFile).DirectoryName -Type Directory -Name ([System.Guid]::NewGuid().ToString())
            }

            AfterAll {
                if (Test-Path $script:compareTestDir.FullName) {
                    Remove-Item $script:compareTestDir.FullName -Recurse -Force
                }
            }

            It "Returns true when the same action file is compared with itself" {
                $actionFile = Join-Path $PSScriptRoot 'data' 'standardAction.action'
                $result = Compare-VroActionContents -OriginalVroActionFile $actionFile -UpdatedVroActionFile $actionFile
                $result | Should -Be $true
            }

            It "Returns false when two action files with different content are compared" {
                # Build two action XML files with different content
                $action1 = [VroAction]@{
                    Id                = [guid]::NewGuid()
                    Name              = 'actionOne'
                    Description       = 'First action'
                    Version           = '1.0.0'
                    OutputType        = 'string'
                    AllowedOperations = ''
                    Script            = "return 'one';"
                }
                $action2 = [VroAction]@{
                    Id                = [guid]::NewGuid()
                    Name              = 'actionTwo'
                    Description       = 'Second action'
                    Version           = '2.0.0'
                    OutputType        = 'string'
                    AllowedOperations = ''
                    Script            = "return 'two';"
                }

                # Create temporary source folders each containing an action-content file
                $srcDir1 = New-Item -Path $script:compareTestDir.FullName -Name 'src1' -Type Directory
                $srcDir2 = New-Item -Path $script:compareTestDir.FullName -Name 'src2' -Type Directory
                (ConvertTo-VroActionXml -InputObject $action1).Save((Join-Path $srcDir1.FullName 'action-content'))
                (ConvertTo-VroActionXml -InputObject $action2).Save((Join-Path $srcDir2.FullName 'action-content'))

                # Compress each action-content into a .action archive (VRO format)
                $actionZip1 = Join-Path $script:compareTestDir.FullName 'actionOne.action'
                $actionZip2 = Join-Path $script:compareTestDir.FullName 'actionTwo.action'
                Compress-Archive -Path (Join-Path $srcDir1.FullName 'action-content') -DestinationPath $actionZip1
                Compress-Archive -Path (Join-Path $srcDir2.FullName 'action-content') -DestinationPath $actionZip2

                $result = Compare-VroActionContents -OriginalVroActionFile $actionZip1 -UpdatedVroActionFile $actionZip2
                $result | Should -Be $false
            }
        }
    }
}
