Class VroActionInput {
    [string] $name
    [string] $description
    [string] $type
}

Class VroAction {
    [guid] $Id
    [string] $Name
    [string] $Description
    [string] $FQN
    [String] $Version
    [VroActionInput[]] $InputParameters
    [string] $OutputType
    [string] $Href
    [System.Object[]] $Relations
    [string] $Script
    [string] $Module
    [string] $TagsGlobal
    [string] $TagsUser
    [string] $AllowedOperations
    [string] modulePath ($basePath) {
        return (Join-Path -Path $basePath -ChildPath $this.FQN.Split("/")[0])
    }
    [string] filePath ($basePath, [string]$fileExtension) {
        return (Join-Path -Path $basePath -ChildPath $this.FQN.Split("/")[0] -AdditionalChildPath "$($this.Name).$fileExtension")
    }
}

function ConvertFrom-VroActionXml {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNull()]
        [xml]$InputObject
    )

    $xml = $InputObject

    # Init

    $vroAction = [VroAction]::new();

    # process xml

    $vroAction.Name = $xml.'dunes-script-module'.name
    $vroAction.Description = $xml.'dunes-script-module'.description.'#cdata-section'
    $vroAction.OutputType = $xml.'dunes-script-module'.'result-type'
    $vroAction.Script = $xml.'dunes-script-module'.script.'#cdata-section'
    $vroAction.Version = $xml.'dunes-script-module'.version

    if ($xml.'dunes-script-module'.'allowed-operations'){
        $vroAction.AllowedOperations = $xml.'dunes-script-module'.'allowed-operations'
    }

    if ($xml.'dunes-script-module'.'id' -as [guid]){
        $vroAction.Id = $xml.'dunes-script-module'.'id'
    }else{
        $vroAction.Id = $xml.'dunes-script-module'.'id'.substring(0,4) + $xml.'dunes-script-module'.'id'.substring(32,4) + $xml.'dunes-script-module'.'id'.substring(41,24)
    }

    if ($xml.'dunes-script-module'.param) {
        $inputs = @()
        foreach ($input in $xml.'dunes-script-module'.param) {
            $obj = [VroActionInput]::new()
            $obj.name = $input.n
            $obj.description = $input.'#cdata-section'
            $obj.type = $input.t
            $inputs += $obj
        }
        $vroAction.InputParameters = $inputs
    }

    return $vroAction
}

function ConvertTo-VroActionJs {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNull()]
        [VroAction]$InputObject
    )

    # being compiling JS file

    $lines = @("/**")

    # add in description if available

    if ($InputObject.Description){
        foreach ($line in $InputObject.Description.Split("`n")){
            $lines += "* " + $line
        }
    }

    # add inputs if available

    if ($InputObject.InputParameters){
        foreach ($input in $InputObject.InputParameters) {
            $lines += "* @param {" + $input.type + "} " + $input.name + " - " + $input.description
        }
    }

    # additional fields

    $lines += "* @id " + $InputObject.Id
    $lines += "* @version " + $InputObject.Version
    $lines += "* @allowedoperations " + $InputObject.AllowedOperations

    # compulsory return field

    $lines += "* @return {" + $InputObject.OutputType + "}"
    $lines += "*/"

    # add in function with inputs by name

    $lines += "function " + $InputObject.Name + "(" + (($InputObject.InputParameters.name) -join ",") + ") {"
    if ($InputObject.Script) {
        foreach ($line in $InputObject.Script.Split("`n")) {
            $lines += "`t$line"
        }
    }
    $lines += "};"

    return $lines -join "`n"
}

function Get-JsdocMatchProperties {
    param (
        [string]$Header,
        [string]$Pattern
    )
    $Header | Select-String -AllMatches -Pattern $Pattern | ForEach-Object {
        foreach ($MatchItem in $_.Matches) {
            $props = [ordered]@{}
            foreach ($group in $MatchItem.Groups) {
                # skip auto-generated numeric group indices; only keep named groups
                if (-not ($group.Name -match '^\d+$')) {
                    $props[$group.Name] = $group.Value
                }
            }
            [PSCustomObject]$props
        }
    }
}

function ConvertFrom-VroActionJs {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNull()]
        [string[]]$InputObject
    )

    # above validations including from pipeline
    # check there is header start header end function and final line

    # Init

    $vroAction = [VroAction]::new();

    # Normalise line endings to LF
    $InputObject = $InputObject -replace "\r\n", "`n" -replace "\r", "`n"

    # Regex Extractor

    $patternHeader = '(?smi)\/\*\*\r?\n(\* .*\r?\n)+(\*\/)'
    $patternDescription = "(\/\*\*\r?\n)(\* [^@\r\n]*[^@]*)(\r?\n)"
    $patternBody = "(?smi)^function .*\r?\n(.*\r?\n)*"
    $patternInputs =  "(?smi)\* @(?<jsdoctype>param) (?<type>[^}]*}) (?<name>\w+) - (?<description>[^\r\n]*)"
    $patternReturn =  "(?smi)\* @(?<jsdoctype>return) (?<type>{[^}]*})"
    $patternId = "(?smi)\* @(?<jsdoctype>id) (?<description>[^\r\n]*)"
    $patternAllowedOperations = "(?smi)\* @(?<jsdoctype>allowedoperations) (?<description>[^\r\n]*)"
    $patternVersion = "(?smi)\* @(?<jsdoctype>version) (?<description>[^\r\n]*)"

    $jsdocHeaderMatch = $InputObject | Select-String $patternHeader -AllMatches
    if (!$jsdocHeaderMatch){
        throw "ConvertFrom-VroActionJs: Could not parse JSDoc header. Input must contain a valid JSDoc block starting with '/**' and ending with '*/'."
    }

    $jsdocBodyMatch = $InputObject | Select-String -Pattern $patternBody
    if (!$jsdocBodyMatch){
        throw "ConvertFrom-VroActionJs: Could not parse function body. Input must contain a valid JavaScript function declaration (e.g. 'function name(...) { ... }')."
    }

    $jsdocBody = ($jsdocBodyMatch | ForEach-Object { $_.Matches.value }).Split("`n")
    $vroAction.Name = $jsdocBody[0].split(" ")[1].split("(")[0]
    if ([string]::IsNullOrWhiteSpace($vroAction.Name)){
        throw "ConvertFrom-VroActionJs: Could not extract function name. The function declaration must include a name (e.g. 'function myAction(...) { ... }')."
    }
    $vroAction.Script = ($jsdocBody | Select-Object -Skip 1 | Select-Object -First ($jsdocBody.count - 3) | ForEach-Object { $_ -replace "^\t","" }) -join "`n"
    $jsdocHeader = $jsdocHeaderMatch | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1] } | ForEach-Object { $_.Value }
    $jsDocDescription = $InputObject | Select-String -Pattern $patternDescription -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[2] } | ForEach-Object { $_.Value }
    $vroAction.Description = $jsDocDescription -replace "(?ms)^\* ",""

    # jsdoc comments

    $jsdocComments = @()

    $jsdocComments += Get-JsdocMatchProperties -Header $jsdocHeader -Pattern $patternInputs
    $jsdocComments += Get-JsdocMatchProperties -Header $jsdocHeader -Pattern $patternReturn
    $jsdocComments += Get-JsdocMatchProperties -Header $jsdocHeader -Pattern $patternId
    $jsdocComments += Get-JsdocMatchProperties -Header $jsdocHeader -Pattern $patternAllowedOperations
    $jsdocComments += Get-JsdocMatchProperties -Header $jsdocHeader -Pattern $patternVersion

    # Populate vroaction

    $id = $jsdocComments | Where-Object { $_.jsdoctype -eq "id" }
    
    if ($id){
        $vroAction.Id = $id.description
    }else{
        $vroAction.Id = "{$([guid]::NewGuid().Guid)}".ToUpper()
    }

    # inputs

    $inputs = @()

    foreach ($input in ($jsdocComments | Where-Object { $_.jsdoctype -eq "param" })) {
        $obj = [VroActionInput]::new()
        $obj.name = $input.name
        $obj.description = $input.description                  
        $obj.type = $input.type
        $inputs += $obj
    }
    $vroAction.InputParameters = $inputs

    # version
    $vroAction.Version = ($jsdocComments | Where-Object { $_.jsdoctype -eq "version" }).description

    # allowed operations
    $vroAction.AllowedOperations = ($jsdocComments | Where-Object { $_.jsdoctype -eq "allowedoperations" }).description

    # return type
    $vroAction.OutputType = ($jsdocComments | Where-Object { $_.jsdoctype -eq "return" }).type

    return $vroAction
}

function ConvertTo-VroActionXml {
        param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNull()]
        [VroAction]$inputObject,
        [Parameter()]
        [string]$ApiVersion = "6.0.0"
    )
    # move as many tests as possible up to the top
    # consider output type - currently this script will be null, but maybe it should be the jsdoc path

    $vroActionXml = [xml]'<?xml version="1.0" encoding="UTF-8"?>'

    $xmlElt = $vroActionXml.CreateElement("dunes-script-module")

    $att = $vroActionXml.CreateAttribute("name")
    $att.Value = $inputObject.Name
    $null = $xmlElt.Attributes.Append($att)

    $att = $vroActionXml.CreateAttribute("result-type")
    $att.Value = $inputObject.OutputType.replace("{","").replace("}","")
    $null = $xmlElt.Attributes.Append($att)

    $att = $vroActionXml.CreateAttribute("api-version")
    $att.Value = $ApiVersion
    $null = $xmlElt.Attributes.Append($att)

    $att = $vroActionXml.CreateAttribute("id")
    $att.Value = $inputObject.Id
    $null = $xmlElt.Attributes.Append($att)

    $att = $vroActionXml.CreateAttribute("version")
    $att.Value = $inputObject.Version
    $null = $xmlElt.Attributes.Append($att)

    if (!([string]::IsNullOrWhitespace($inputObject.AllowedOperations))){
        $att = $vroActionXml.CreateAttribute("allowed-operations")
        $att.Value = $inputObject.AllowedOperations
        $null = $xmlElt.Attributes.Append($att)
    }

    $null = $vroActionXml.AppendChild($xmlElt)

    $Node = $vroActionXml.'dunes-script-module'

    # Creation of a node and its text
    if ($inputObject.Description){
        $xmlElt = $vroActionXml.CreateElement("description")
        $xmlCdata = $vroActionXml.CreateCDataSection($inputObject.Description)
        $null = $xmlElt.AppendChild($xmlCdata)
        # Add the node to the document
        $null = $Node.AppendChild($xmlElt)
    }

    ## Populate Inputs from Component Plan

    foreach ($Input in $inputObject.InputParameters){

        # Creation of a node and its text
        $xmlElt = $vroActionXml.CreateElement("param")
        $xmlCdata = $vroActionXml.CreateCDataSection($Input.description)
        $null = $xmlElt.AppendChild($xmlCdata)

        # Creation of an attribute in the principal node
        $xmlAtt = $vroActionXml.CreateAttribute("n")
        $xmlAtt.value = $Input.name
        $null = $xmlElt.Attributes.Append($xmlAtt)

        # Creation of an attribute in the principal node
        $xmlAtt = $vroActionXml.CreateAttribute("t")
        $xmlAtt.value = $Input.type.trim("{").trim("}")
        $null = $xmlElt.Attributes.Append($xmlAtt)

        # Add the node to the document
        $null = $Node.AppendChild($xmlElt)
    }

    if ($inputObject.Script){
        # Creation of a node and its text
        $xmlElt = $vroActionXml.CreateElement("script")
        $xmlCdata = $vroActionXml.CreateCDataSection($inputObject.Script -join [System.Environment]::NewLine)
        $null = $xmlElt.AppendChild($xmlCdata)

        # Creation of an attribute in the principal node
        $xmlAtt = $vroActionXml.CreateAttribute("encoded")
        $xmlAtt.value = "false"
        $null = $xmlElt.Attributes.Append($xmlAtt)

        # Add the node to the document
        $null = $Node.AppendChild($xmlElt)
    }

    return $vroActionXml
}

function Export-VroActionFile {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNull()]
        [xml]$InputObject,
        [Parameter(
            ValueFromPipelineByPropertyName = $true
        )]
        [string]$exportFolder,
        [Parameter()]
        [string]$Creator = "www.dunes.ch"
    )

    # create temporary folder
    $TempDir = [System.Guid]::NewGuid().ToString()
    $tmpWorkingFolder = New-Item -Path (New-TemporaryFile).DirectoryName -Type Directory -Name $TempDir
    try {
        $compressFolder = New-Item -Path $tmpWorkingFolder.fullName -Name "$($InputObject.'dunes-script-module'.name).action" -Type Directory

        #code $tmpWorkingFolder

        # export content xml
        $InputObject.Save("$compressFolder/action-content")
        $actionContent = get-content "$compressFolder/action-content"
        $actionContent = $actionContent | ForEach-Object { $_.replace("<?xml version=`"1.0`" encoding=`"UTF-8`"?>","<?xml version='1.0' encoding='UTF-8'?>") }
        $actionContent | set-content "$compressFolder/action-content" -Encoding bigendianunicode
        $stream = [IO.File]::OpenWrite("$compressFolder/action-content")
        $stream.SetLength($stream.Length - ([System.Environment]::NewLine.Length * 2))
        $stream.Close()
        $stream.Dispose()

        # export history xml
        $actionHistory = @(
            "<?xml version='1.0' encoding='UTF-8'?>",
            "<items>",
            "</items>",
            ""
        ) -join "`n"
        $actionHistory | Set-Content "$compressFolder/action-history" -Encoding bigendianunicode

        # export info xml
        $timestamp = (Get-Date).ToUniversalTime().ToString("ddd MMM dd HH:mm:ss 'UTC' yyyy")
        $actionInfo = @(
            "#",
            "#$timestamp",
            "unicode=true",
            "owner=",
            "version=2.0",
            "type=action",
            "creator=$Creator",
            "charset=UTF-16",
            ""
        ) -join "`n"
        $actionInfo | Set-Content "$compressFolder/action-info" -Encoding utf8

        # compress the folder

        #$compressedFolder = Compress-Archive -Path $compressFolder -DestinationPath "$exportFolder/$($InputObject.'dunes-script-module'.name).action" #-Force
        $compressedFolder = [io.compression.zipfile]::CreateFromDirectory($compressFolder, "$exportFolder/$($InputObject.'dunes-script-module'.name).action")
        return $compressedFolder
    } finally {
        $tmpWorkingFolder | Remove-Item -Recurse -Force -Confirm:$false
    }
}

function ConvertTo-VroActionMd {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNull()]
        [VroAction]$InputObject
    )

    # being compiling MD file

    $lines = @("# VRO Action - " + $InputObject.Name, "")

    # add in description if available

    if ($InputObject.Description){
        $lines += "## Description"
        $lines += ""

        foreach ($line in $InputObject.Description.Split("`n")){
            $lines += $line
        }

        $lines += ""
    }

    # add inputs if available

    if ($InputObject.InputParameters){
        $lines += "## Inputs"
        $lines += ""

        if ($InputObject.InputParameters){
            foreach ($input in $InputObject.InputParameters) {
                $lines += "- [" + $input.type + "]" + $input.name + " : " + $input.description
            }
        }
        $lines += ""
    }

    # Metadata fields

    $lines += "## Metadata"
    $lines += ""

    $lines += "- ID : " + $InputObject.Id
    $lines += "- Version : " + $InputObject.Version
    $lines += "- Allowed Operations : " + $InputObject.AllowedOperations
    $lines += "- Output Type : [" + $InputObject.OutputType + "]"
    $lines += ""

    # add in function with inputs by name

    $lines += "## Script "
    $lines += ""
    if ($InputObject.Script) {
        $lines += '```javascript'
        foreach ($line in $InputObject.Script.Split("`n")) {
            $lines += $line
        }
        $lines += '```'
    }

    return $lines -join "`n"
}

function Compare-VroActionContents {
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNull()]
        [String]$OriginalVroActionFile,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNull()]
        [string]$UpdatedVroActionFile
    )

    # create temporary folder
    $TempDir = [System.Guid]::NewGuid().ToString()
    $tmpWorkingFolder = New-Item -Path (New-TemporaryFile).DirectoryName -Type Directory -Name $TempDir
    try {
        $original = New-Item -Path $tmpWorkingFolder.fullName -Name "original" -Type Directory
        $updated = New-Item -Path $tmpWorkingFolder.fullName -Name "updated" -Type Directory

        #code $tmpWorkingFolder

        Expand-Archive -Path $OriginalVroActionFile -DestinationPath $original
        Expand-Archive -Path $UpdatedVroActionFile -DestinationPath $updated

        ([xml](Get-Content $original/action-content)).Save("$original/action-content")
        ([xml](Get-Content $updated/action-content)).Save("$updated/action-content")

        $originalFileHash = Get-FileHash -Path $original/action-content
        $updatedFileHash = Get-FileHash -Path $updated/action-content
        
        # finalise
        
        Write-Debug $tmpWorkingFolder.fullName
        Write-Debug $originalFileHash.Hash
        Write-Debug $updatedFileHash.Hash

        if ($originalFileHash.Hash -eq $updatedFileHash.Hash){
            return $true
        }
        
        # attempt number : dropping the allowed operations VEF - sometimes unpredictable outputs

        $diff = Compare-Object -ReferenceObject $original/action-content -DifferenceObject $updated/action-content
        $vcfLineEndOriginal = (Get-Content "$original/action-content")[1].Split(" ")[-1].split("=")[0]

        if ( ($diff.count -eq 2) -and ( $vcfLineEndOriginal -eq "allowed-operations" ) ){
            $originalFile = Get-Content $original/action-content
            $updatedFile = Get-Content $updated/action-content

            $originalFile[1] = $updatedFile[1]

            $originalFile | set-content "$original/action-content" -Encoding bigendianunicode
            $stream = [IO.File]::OpenWrite("$original/action-content")
            $stream.SetLength($stream.Length - ([System.Environment]::NewLine.Length * 2))
            $stream.Close()
            $stream.Dispose()

            ([xml](Get-Content $original/action-content)).Save("$original/action-content")

            $originalFileHash = Get-FileHash -Path $original/action-content
            $updatedFileHash = Get-FileHash -Path $updated/action-content

            if ($originalFileHash.Hash -eq $updatedFileHash.Hash){
                return $true
            }
        }
        return $false
    } finally {
        $tmpWorkingFolder | Remove-Item -Recurse -Force -Confirm:$false
    }
}

function Export-VroIde {
    param (
        [Parameter(
            Mandatory = $false
        )]
        [string]$vroIdeFolder,
        [switch]$keepWorkingFolder
    )

    Write-Debug "### Beginng Export VRO IDE"

    if (!$vROConnection){
        throw "VRO Connection Required"
    }

    if ($vroIdeFolder){
        if (!(Test-Path $vroIdeFolder)){
            throw "vroIdeFolder '$vroIdeFolder' does not exist"
        }
        if (!(Get-Item $vroIdeFolder).PSIsContainer){
            throw "vroIdeFolder '$vroIdeFolder' is not a directory"
        }
        $vroIdeFolder = Get-Item $vroIdeFolder
    }else{
        Write-Debug "No Folder Provided Generating a Random one"
        $parent = [System.IO.Path]::GetTempPath()
        [string] $name = [System.Guid]::NewGuid()
        $vroIdeFolder = New-Item -ItemType Directory -Path (Join-Path $parent $name)
    }

    $vroIdeFolderSrc = Join-Path $vroIdeFolder -ChildPath "src"
    $vroIdeFolderDoc = Join-Path $vroIdeFolder -ChildPath "docs"
    $vroIdeFolderTst = Join-Path $vroIdeFolder -ChildPath "tests"
    if (!(Test-Path $vroIdeFolderSrc)){
        $null = New-Item -ItemType Directory -Path $vroIdeFolderSrc
    }
    if (!(Test-Path $vroIdeFolderDoc)){
        $null = New-Item -ItemType Directory -Path $vroIdeFolderDoc
    }
    if (!(Test-Path $vroIdeFolderTst)){
        $null = New-Item -ItemType Directory -Path $vroIdeFolderTst
    }

    $workingFolder = New-Item -ItemType Directory -Path $vroIdeFolderSrc -Name "$([guid]::NewGuid().Guid)".ToUpper()

    try {
        $vroActionHeaders = Get-vROAction | Where-Object { $_.FQN -notlike "com.vmware*" }

        # export vro action headers 

        $vroActionHeaders | ConvertTo-Json | set-content (Join-Path -Path $vroIdeFolderSrc -ChildPath "vroActionHeaders.json")

        # Creating Folders

        foreach ($vroActionHeader in $vroActionHeaders){
            $vroActionHeader = $vroActionHeader -as [VroAction]
            Write-Debug "Creating Folders : $($vroActionHeader.FQN)"
            if (!(Test-Path $vroActionHeader.modulePath($workingFolder))){
                $null = New-Item -ItemType Directory -Path $vroActionHeader.modulePath($workingFolder)
            }
            if (!(Test-Path $vroActionHeader.modulePath($vroIdeFolderSrc))){
                $null = New-Item -ItemType Directory -Path $vroActionHeader.modulePath($vroIdeFolderSrc)
            }
            if (!(Test-Path $vroActionHeader.modulePath($vroIdeFolderDoc))){
                $null = New-Item -ItemType Directory -Path $vroActionHeader.modulePath($vroIdeFolderDoc)
            }
            if (!(Test-Path $vroActionHeader.modulePath($vroIdeFolderTst))){
                $null = New-Item -ItemType Directory -Path $vroActionHeader.modulePath($vroIdeFolderTst)
            }
        }

        # Downloading Actions

        foreach ($vroActionHeader in $vroActionHeaders){
            $vroActionHeader = $vroActionHeader -as [VroAction]
            Write-Debug "Downloading Action : $($vroActionHeader.FQN)"
            $null = Export-vROAction -Id $vroActionHeader.Id -Path $vroActionHeader.modulePath($workingFolder)
        }

        # Expanding Actions

        foreach ($vroActionHeader in $vroActionHeaders){
            $vroActionHeader = $vroActionHeader -as [VroAction]
            Write-Debug "Expanding Action : $($vroActionHeader.FQN)"
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zipArchive = [System.IO.Compression.ZipFile]::OpenRead($vroActionHeader.filePath($workingFolder,"action"))
            try {
                $actionContentFile = $zipArchive.Entries | Where-Object { $_.FullName -eq "action-content"}
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($actionContentFile, $vroActionHeader.filePath($workingFolder,"xml"), $true)
            } finally {
                $zipArchive.Dispose()
            }
        }

        # Import XML convert to jsdoc convert save
        foreach ($vroActionHeader in $vroActionHeaders){
            $vroActionHeader = $vroActionHeader -as [VroAction]
            Write-Debug "Convert from XML to JS and Save for Action : $($vroActionHeader.FQN)"
            $vroActionXml = [xml](get-content $vroActionHeader.filePath($workingFolder,"xml"))
            $vroAction = ConvertFrom-VroActionXml -InputObject $vroActionXml
            $vroAction | ConvertTo-Json -Depth 99 | Set-Content $vroActionHeader.filePath($workingFolder,"json")
            $vroActionJs = ConvertTo-VroActionJs -InputObject $vroAction
            [System.IO.File]::WriteAllText($vroActionHeader.filePath($vroIdeFolderSrc,"js"), $vroActionJs, [System.Text.UTF8Encoding]::new($false))
        }

        foreach ($vroActionHeader in $vroActionHeaders){
            $vroActionHeader = $vroActionHeader -as [VroAction]
            Write-Debug "Convert from JSON to MD and Save for Action : $($vroActionHeader.FQN)"
            $vroAction = Get-Content $vroActionHeader.filePath($workingFolder,"json") -Raw | ConvertFrom-Json
            $vroActionMd = ConvertTo-VroActionMd -InputObject $vroAction
            [System.IO.File]::WriteAllText($vroActionHeader.filePath($vroIdeFolderDoc,"md"), $vroActionMd, [System.Text.UTF8Encoding]::new($false))
        }

        return $vroIdeFolder
    } finally {
        if ($keepWorkingFolder){
            Write-Debug "Working Folder not deleted : $($workingFolder.FullName)"        
        }else{
            $null = Remove-Item $workingFolder -Recurse -Force -Confirm:$false
        }
    }
}

function Import-VroIde {
    param (
        [Parameter(
            Mandatory = $true
        )]
        [string]$vroIdeFolder,
        [switch]$keepWorkingFolder
    )

    Write-Debug "### Beginng Import VRO IDE"

    if (!$vROConnection){
        throw "VRO Connection Required"
    }

    if (!(Test-Path $vroIdeFolder)){
        throw "vroIdeFolder '$vroIdeFolder' does not exist"
    }
    if (!(Get-Item $vroIdeFolder).PSIsContainer){
        throw "vroIdeFolder '$vroIdeFolder' is not a directory"
    }

    $vroIdeFolderSrc = Join-Path $vroIdeFolder -ChildPath "src"
    if (!(Test-Path $vroIdeFolderSrc)){
        throw "vroIdeFolder '$vroIdeFolder' does not contain a 'src' directory"
    }

    if (!(Test-Path (Join-Path $vroIdeFolderSrc -ChildPath "vroActionHeaders.json"))){
        throw "vroActionHeaders.json file required in the working folder"
    }else{
        #$vroActionHeaders = Get-Content (Join-Path -Path $vroIdeFolderSrc -ChildPath "vroActionHeaders.json") -Raw | ConvertFrom-Json
        $vroActionHeaders = @();
        $modules = Get-ChildItem $vroIdeFolderSrc -Directory
        foreach ($module in $modules){
            $actions = Get-ChildItem $module -Filter '*.js'
            foreach ($action in $actions){
                Write-Host -ForegroundColor Green $action.name
                $vroActionHeader = [VroAction]@{
                    Name = $action.basename
                    FQN = $module.name + "/" + $action.basename
                    Id = New-Guid
                }
                $vroActionJs = Get-Content $vroActionHeader.filePath($vroIdeFolderSrc,"js") -Raw
                $vroAction = ConvertFrom-VroActionJs -InputObject $vroActionJs
                $vroActionHeader.Id = $vroAction.Id
                $vroActionHeaders += $vroActionHeader
            } 
        }
    }

    $workingFolder = New-Item -ItemType Directory -Path $vroIdeFolder -Name ([guid]::NewGuid().Guid).ToUpper()

    try {
        # Creating Folders

        foreach ($vroActionHeader in $vroActionHeaders){
            $vroActionHeader = $vroActionHeader -as [VroAction]
            Write-Debug "Creating Folders : $($vroActionHeader.FQN)"
            if (!(Test-Path $vroActionHeader.modulePath($vroIdeFolderSrc))){
                $null = New-Item -ItemType Directory -Path $vroActionHeader.modulePath($vroIdeFolderSrc)
            }
            if (!(Test-Path $vroActionHeader.modulePath($workingFolder))){
                $null = New-Item -ItemType Directory -Path $vroActionHeader.modulePath($workingFolder)
            }
        }

        # Import jsodc convert to xml convert save and export to action
        foreach ($vroActionHeader in $vroActionHeaders){
            $vroActionHeader = $vroActionHeader -as [VroAction]
            Write-Debug "Convert from XML to JS and Save for Action : $($vroActionHeader.FQN)"
            $vroActionJs = Get-Content $vroActionHeader.filePath($vroIdeFolderSrc,"js") -Raw
            $vroAction = ConvertFrom-VroActionJs -InputObject $vroActionJs
            $vroAction | ConvertTo-Json -Depth 99 | Set-Content $vroActionHeader.filePath($workingFolder,"json")
            $vroActionXml = ConvertTo-VroActionXml -InputObject $vroAction
            $vroActionXml.Save($vroActionHeader.filePath($workingFolder,"xml"))
            Export-VroActionFile -InputObject $vroActionXml -exportFolder $vroActionHeader.modulePath($vroIdeFolderSrc)
        }

        # Downloading Actions

        foreach ($vroActionHeader in $vroActionHeaders){
            $vroActionHeader = $vroActionHeader -as [VroAction]
            Write-Debug "Downloading Action : $($vroActionHeader.FQN)"
            if (Get-vROAction -Id $vroActionHeader.Id -ErrorAction SilentlyContinue){
                $null = Export-vROAction -Id $vroActionHeader.Id -Path $vroActionHeader.modulePath($workingFolder)
            }
        }

        # Compare and upload on difference

        foreach ($vroActionHeader in $vroActionHeaders){
            $vroActionHeader = $vroActionHeader -as [VroAction]
            if (Test-Path $vroActionHeader.filePath($workingFolder,"action")){
                $compareResult = Compare-VroActionContents -OriginalVroActionFile $vroActionHeader.filePath($workingFolder,"action") -UpdatedVroActionFile $vroActionHeader.filePath($vroIdeFolderSrc,"action") -Debug
            }
            if ($compareResult){
                Write-Debug "Comparing $($vroActionHeader.Name) : would not be updated - file hash identical"
            }else{
                Write-Debug "Comparing $($vroActionHeader.Name) : would be updated - file hash not identical"
                Import-vROAction -CategoryName $vroActionHeader.FQN.split("/")[0] -File $vroActionHeader.filePath($vroIdeFolderSrc,"action") #-Overwrite -WhatIf
            }
            Remove-Item -Path $vroActionHeader.filePath($vroIdeFolderSrc,"action") -Confirm:$false
            $compareResult = $null
        }
    } finally {
        if ($keepWorkingFolder){
            Write-Debug "Working Folder not deleted : $($workingFolder.FullName)"        
        }else{
            $null = Remove-Item $workingFolder -Recurse -Force -Confirm:$false
        }
    }
}

function Get-vROAction {
    [CmdletBinding()]
    param (
        [string]$Id
    )
    throw "Get-vROAction requires the PowervRO module. Install it with: Install-Module -Name PowervRO"
}

function Export-vROAction {
    [CmdletBinding()]
    param (
        [string[]]$Id,
        [string]$Path
    )
    throw "Export-vROAction requires the PowervRO module. Install it with: Install-Module -Name PowervRO"
}

function Import-vROAction {
    [CmdletBinding()]
    param (
        [string[]]$CategoryName,
        [string[]]$File,
        [bool]$Override
    )
    throw "Import-vROAction requires the PowervRO module. Install it with: Install-Module -Name PowervRO"
}