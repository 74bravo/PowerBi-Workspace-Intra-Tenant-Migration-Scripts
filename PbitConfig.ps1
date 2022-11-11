Add-Type -AssemblyName System.Text.Encoding.Extensions
Add-Type -AssemblyName System.Runtime

$MyInvocation.MyCommand.Path

$currentScriptPath = $MyInvocation.MyCommand.Path


$muParamRegEx = 'shared (?<query>[#" a-zA-Z]+) = (?<value>null) meta (?<meta>\[[^\]]+\]);'
$muIsParamQueryRegEx = '\[[^\]]*(IsParameterQuery=true)[^\]]*]'
$muDefaultValueRegEx = '\[[^\]]*DefaultValue="([^"]*)"[^\]]*\]'

function SelectParametersRegEx 
{
    [OutputType([string])]
    param ()

    return 'shared (?<query>[#" a-zA-Z]+) = (?<value>null) meta (?<meta>\[[^\]]+\]);'

}

function SelectParamDefaultValueRegEx
{
    [OutputType([string])]
    param ()

    return '\[[^\]]*DefaultValue="([^"]*)"[^\]]*\]'

}


function GetPbitConfigFileInfo
{
    [OutputType([System.IO.FileInfo])]
    param (
       [ValidateNotNullOrEmpty()]
       [System.IO.DirectoryInfo] $pbitRootDir,
       [String] $configuration
    )

    $pbitConfigPath = [IO.Path]::Combine($pbitRootDir.FullName, "pbitConfig.json")

    if (![String]::IsNullOrEmpty($configuration)){

     $pbitConfigPath = [IO.Path]::Combine($pbitRootDir.FullName, "pbitConfig.$configuration.json")
    }

    return New-Object System.IO.FileInfo -ArgumentList $pbitConfigPath

}

function LoadPbitConfig
{
    [OutputType([PSCustomObject])]
    param (
       [ValidateNotNullOrEmpty()]
       [System.IO.FileInfo] $pbitconfigfile
    )  
    
    return Get-Content -Path $pbitconfigfile | ConvertFrom-Json
   
}

function GetPbitBaseName
{
    [OutputType([string])]
    param (
       [ValidateNotNullOrEmpty()]
       [System.IO.FileInfo] $pbitFile
    )  

    $extLength = $pbitFile.Extension.Length
    $nameLength = $pbitFile.Name.Length

    return $pbitFile.Name.Substring(0,$nameLength - $extLength)  
}

function GetOrCreatePbitConfig
{
    [OutputType([PSCustomObject])]
    param (
       [ValidateNotNullOrEmpty()]
       [System.IO.DirectoryInfo] $pbitrootdir,
       [String] $configuration
    )

    $pbitConfigPath = GetPbitConfigFileInfo -pbitRootDir $pbitrootdir -configuration $configuration

    $fjson = @"
        {
        "pbitFiles" : []
        }
"@

    if (Test-Path $pbitConfigPath) 
    {
         $fjson =  Get-Content -Path $pbitConfigPath 
    }

    if (!(Test-Path $pbitRootDir)) 
    {
            [System.IO.Directory]::CreateDirectory($pbitRootDir)
    }

    
    $PbitConfig = $fjson |  ConvertFrom-Json

    $pbitFilter = [IO.Path]::Combine($pbitRootDir.FullName, "*.pbit")

    $pbitFiles = Get-ChildItem -Path $pbitFilter


    foreach ($pbitfile in $pbitFiles)
    {

       # $pbitFileFullName = $pbitfile.FullName
       # $pbitFileName = $pbitfile.Name

        #"Processing $pbitFileName"

         $jsonObject = GetOrCreatePbitFileConfig -pbitFile $pbitfile -pbitConfig $PbitConfig -configuration $configuration

        #"Finsihed Processing $pbitFileName"

    }

    return $PbitConfig
    
}


function GetOrCreatePbitFileConfig
{
    [OutputType([PSCustomObject])]
    param (
       [ValidateNotNullOrEmpty()]
       [System.IO.FileInfo] $pbitFile,
       [ValidateNotNullOrEmpty()]
       [PSCustomObject] $pbitConfig,
       [String] $configuration
    )

    $pbitFileName = $pbitFile.Name
    $pbitFileBaseName = $pbitFile.BaseName

        $fjson = @"
        {
        "pbitFileName" : "$pbitFileName",
        "pbitFileBaseName" : "$pbitFileBaseName",
        "mQueryParameters" : []
        }
"@


    $pbitFileConfig = $fjson | ConvertFrom-Json

    $pbitFileConfigFound = $false

    #Override new PbitFileConfig when one is existing one is found.
    foreach ($existingFileConfig in $pbitConfig.pbitFiles)
    {
        if ($existingFileConfig.pbitFileName -eq $pbitFileName)
        {
             $pbitFileConfigFound = $true
             $pbitFileConfig =  $existingFileConfig
        }
    }

    if (!$pbitFileConfigFound) {
        $pbitConfig.pbitFiles += $pbitFileConfig
    }

    $pbitrootdir = $pbitFile.DirectoryName
    $pbitUnPackDir = [System.IO.Path]::Combine($pbitrootdir, $pbitFile.BaseName)
    $pbitSection1Path = [System.IO.Path]::Combine($pbitUnPackDir,"DataMashup\Formulas\Section1.m")






       $muContent = Get-Content -Path $pbitSection1Path

       $match = Select-String (SelectParametersRegEx) -InputObject $muContent -AllMatches

       foreach ($mth in $match.Matches)
            {

                $paramName = $mth.Groups['query'].Value
                $paramValue = $mth.Groups['value'].Value
                $paramMeta = $mth.Groups['meta'].Value

                $defaultValueMatch = Select-String (SelectParamDefaultValueRegEx) -InputObject $paramMeta  -AllMatches

                if ($defaultValueMatch.Matches.Success){

                    $paramValue = $defaultValueMatch.Matches.Groups[1].Value

                }

                GetOrCreatePbitParameterConfig -parameterName $paramName -defaultValue $paramValue -pbitFileConfig  $pbitFileConfig

            }

    return $pbitFileConfig

}

function GetOrCreatePbitParameterConfig
{
    [OutputType([PSCustomObject])]
    param (
       [ValidateNotNullOrEmpty()]
       [string] $parameterName,
       [ValidateNotNullOrEmpty()]
       [string] $defaultValue,
       [ValidateNotNullOrEmpty()]
       [PSCustomObject] $pbitFileConfig
    )

    $pbitFileName = $pbitFile.Name

    foreach ($pbitParameterConfig in $pbitFileConfig.mQueryParameters)
    {
        if ($pbitParameterConfig.parameter -eq $parameterName)
        {

            #Do some code checking for the default value....

            return $pbitParameterConfig
        }
    }

    #Create a new PbitFileConfig when one is not found.

            $fjson = @"
            {
            "parameter" : "$parameterName",
            "defaultValue" : "$defaultValue"
            }
"@

    $pbitParameterConfig = $fjson | ConvertFrom-Json

    $pbitFileConfig.mQueryParameters += $pbitParameterConfig

    return $pbitParameterConfig

}

function CreateOrUpdatePbitConfig
{
    param (
       [ValidateNotNullOrEmpty()]
       [System.IO.DirectoryInfo] $projectRootDir,
       [String] $configuration
    )


    $pbitDir = $projectRootDir.FullName + "\pbit\"




    if (!(Test-Path $projectRootDir)) 
    {
        "ProjectRootDir $projectRootDir does not exist."
        return
    }

    if (!(Test-Path $pbitDir)) 
    {
        "Project does not have a proper pbit folder.  For this project, pbit files should be stored in the following directory:  $pbitDir"
        return
    }

    $pbitConfigPath = [IO.Path]::Combine($pbitDir, "pbitConfig.json")

    if (![String]::IsNullOrEmpty($configuration)){

             $pbitConfigPath = [IO.Path]::Combine($pbitDir, "pbitConfig.$configuration.json")
    }


    $jsonPbitConfig = GetOrCreatePbitConfig -pbitRootDir $pbitDir -configuration $configuration

    $jsonPbitConfigJson = $jsonPbitConfig | ConvertTo-Json -Depth 99

    $jsonPbitConfigJson | Set-Content -Path $pbitConfigPath

    ""
    "Final JSON"

    $jsonPbitConfigJson

}


# Formats JSON in a nicer format than the built-in ConvertTo-Json does.
function Format-Json([Parameter(Mandatory, ValueFromPipeline)][String] $json) {
    $indent = 0;
    $newJson = ($json -Split "`n" | % {
        if ($_ -match '[\}\]]\s*,?\s*$') {
            # This line ends with ] or }, decrement the indentation level
            $indent--
        }
        $line = ('  ' * $indent) + $($_.TrimStart() -replace '":  (["{[])', '": $1' -replace ':  ', ': ')
        if ($_ -match '[\{\[]\s*$') {
            # This line ends with [ or {, increment the indentation level
            $indent++
        }
        $line
    }) -Join "`n"

   # $newJson =   $newJson.Replace("\u003c","<").Replace("\u003e",">")


       $escapeCharRegEx = "\\u([0-9a-z]{4})"

       $escCharMatches = Select-String $escapeCharRegEx -InputObject $newJson -AllMatches

       foreach ($escCharMatch in $escCharMatches.Matches)
            {

                $toReplaceText = $escCharMatch.Groups[0].Value
                $replaceWithText = [System.Text.RegularExpressions.Regex]::Unescape($toReplaceText)
               
                $newJson = $newJson.Replace($toReplaceText,$replaceWithText)

            }


    return $newJson
}


function SetPbitDataModelSchemaParameterDefaultValues
{
    param (
       [ValidateNotNullOrEmpty()]
       [System.IO.DirectoryInfo] $pbitunpackdir,
       [ValidateNotNullOrEmpty()]
       [System.IO.FileInfo] $pbitfile,
       [ValidateNotNullOrEmpty()]
       [PSCustomObject] $pbitConfig,
        [Guid] $targetwsid,
        [PSCustomObject[]] $dataflows
    )  

    "************************************************"
    "Setting Parameter Values in DataModelSchema.json"

    $pbitunpackdir.FullName

    $pbitDataModelSchemaPath = [System.IO.Path]::Combine($pbitunpackdir.FullName,"DataModelSchema.json")

    $pbiFileBaseName = $pbitfile.BaseName

    "Locating $pbiFileBaseName in pbitConfig"

    foreach ($pbitFileObject in $pbitConfig.pbitFiles)
    {
        if ($pbitFileObject.pbitFileBaseName -eq $pbitfile.BaseName)
        {

            "Located $pbiFileBaseName.  Now processing parameters" 

            $pbitDataModelContent = Get-Content -Path $pbitDataModelSchemaPath -Encoding Unicode

            $pbitDataModel = $pbitDataModelContent | ConvertFrom-Json
          
            foreach ($mQueryParameter in $pbitFileObject.mQueryParameters)
            {
                $parameter = $mQueryParameter.parameter

                "now processing parameter $parameter"

                $defaultValueReplacement = "`"" + $mQueryParameter.defaultValue + "`""
                
                if ($mQueryParameter.defaultValue -eq "null")
                {
                    $defaultValueReplacement = $mQueryParameter.defaultValue
                }


                ## Processing Other Properties..

                if ($mQueryParameter.useTargetWorkspaceId)
                {
                    $defaultValueReplacement = "`"" + $targetwsid + "`""
                }
                elseif (![String]::IsNullOrEmpty($mQueryParameter.useIdOfDataflow))
                {

                    $df =  $dataflows | where name -EQ $mQueryParameter.useIdOfDataflow

                    if ($df)
                    {

                        $defaultValueReplacement = "`"" + $df.objectId + "`""


                    }

                }


                $paramExpression =  select-Object -InputObject $pbitDataModel.model -ExpandProperty expressions |  where name -eq $parameter

                $paramExpression

                $paramValRegEx = "^null([\s\S]+)"

                "Param Regex = $paramValRegEx" 
               

                $replacementEx = "$defaultValueReplacement`$1"

                "param replacement = $replacementEx" 

               # $paramExpression.expression  = $paramExpression.expression -replace $paramValRegEx, $replacementEx

            }


            "Finished Processing Parameters.  Now Saving updated DataModelSchema.json ...."


            $pbitDataModelContent = $pbitDataModel | ConvertTo-Json -Depth 99  | Format-Json


            #$Saveencoding =  [Text.Encoding]::UTF8
            #$Saveencoding =  [Text.Encoding]::Default
            #$Saveencoding = [Text.Encoding]::GetEncoding(1251)
            $Saveencoding = [Text.Encoding]::Unicode
           
            $writeallBytes = $Saveencoding.GetBytes($pbitDataModelContent)

            [IO.File]::WriteAllBytes($pbitDataModelSchemaPath, $writeallBytes)

        }
    }

}

function SetPbitMashupParameterDefaultValues
{
    param (
       [ValidateNotNullOrEmpty()]
       [System.IO.DirectoryInfo] $pbitunpackdir,
       [ValidateNotNullOrEmpty()]
       [System.IO.FileInfo] $pbitfile,
       [ValidateNotNullOrEmpty()]
       [PSCustomObject] $pbitConfig,
        [Guid] $targetwsid,
        [PSCustomObject[]] $dataflows
    )  

    "************************************************"
    "Setting Parameter Values"
    $pbitunpackdir.FullName

    $pbitSection1Path = [System.IO.Path]::Combine($pbitunpackdir.FullName,"DataMashup\Formulas\Section1.m")

    $muContent = Get-Content -Path $pbitSection1Path

    $pbiFileBaseName = $pbitfile.BaseName

    "Locating $pbiFileBaseName in pbitConfig"

    foreach ($pbitFileObject in $pbitConfig.pbitFiles)
    {
        if ($pbitFileObject.pbitFileBaseName -eq  $pbitfile.BaseName)
        {


            "Located $pbiFileBaseName.  Now processing parameters" 

            foreach ($mQueryParameter in $pbitFileObject.mQueryParameters)
            {
                $parameter = $mQueryParameter.parameter

                "now processing parameter $parameter"

                $defaultValueReplacement = "`"" + $mQueryParameter.defaultValue + "`""
               
                
                if ($mQueryParameter.defaultValue -eq "null")
                {
                    $defaultValueReplacement = $mQueryParameter.defaultValue
                }

                ## Processing Other Properties..

                if ($mQueryParameter.useTargetWorkspaceId)
                {
                    $defaultValueReplacement = "`"" + $targetwsid + "`""
                }
                elseif (![String]::IsNullOrEmpty($mQueryParameter.useIdOfDataflow))
                {

                    $df =  $dataflows | where name -EQ $mQueryParameter.useIdOfDataflow

                    if ($df)
                    {

                        $defaultValueReplacement = "`"" + $df.objectId + "`""


                    }

                }


                $paramValRegEx = "(shared $parameter = )null( meta \[[^\]]+\];)"
                "Param Regex = $paramValRegEx" 
               

                $replacementEx = "`$1$defaultValueReplacement`$2"

                "param replacement = $replacementEx" 

                $muContent = $muContent -replace $paramValRegEx, $replacementEx

            }
        }
}


     "Finished Processing Parameters.  Now Saving updated Section1 ...."


     $muContent | Set-Content -Path $pbitSection1Path

}



