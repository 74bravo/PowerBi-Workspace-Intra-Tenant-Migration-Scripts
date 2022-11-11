


$dataflowParamRegEx = 'shared[\s]*(?<param>[#" a-zA-Z]+)[\s]*=[\s]*let[\s\b]+(?<id1>[#" a-zA-Z]+)[\s]*=[\s]*(?<defaultVal>[a-zA-Z0-9_]+|"[^"]+")[\s]*meta[\s]*(?<meta>\[[^\]]*IsParameterQuery[\s]*=[\s]*true[^\]]*\])[\s]*in[\s]*\k<id1>;'

function GetDeployConfigFileInfo
{
    [OutputType([System.IO.FileInfo])]
    param (
       [ValidateNotNullOrEmpty()]
       [System.IO.DirectoryInfo] $projectrootdir,
       [String] $configuration
    )


     $deployConfigPath = [IO.Path]::Combine($projectrootdir.FullName, "deployConfig.json")

    if (![String]::IsNullOrEmpty($configuration))
    {
      $deployConfigPath = [IO.Path]::Combine($projectrootdir.FullName, "deployConfig.$configuration.json")
    }

    return New-Object System.IO.FileInfo -ArgumentList $deployConfigPath

}

function GetOrCreateRdlConfig
{
    [OutputType([PSCustomObject])]
    param (
       [ValidateNotNullOrEmpty()]
       [System.IO.DirectoryInfo] $rdlrootdir,
       [ValidateNotNullOrEmpty()]
       [PSCustomObject] $deployconfig
    )

   # $pbitConfigPath = GetPbitConfigFileInfo -pbitRootDir $pbitrootdir

    $rdlFilter = [IO.Path]::Combine($rdlrootdir.FullName, "*.rdl")

    $rdlFiles = Get-ChildItem -Path $rdlFilter

    $rdlFileSettings = @()

    foreach ($rdlFile in $rdlFiles)
    {
       #TODO:  Get the acutal report element.
         $rdlObject = $deployconfig.paginatedReports | Where name -EQ $rdlFile.Name

         if(!$rdlObject)
         {
             $rdlObject =  New-Object -TypeName psobject
             $rdlObject | Add-Member -NotePropertyName "name" -NotePropertyValue $rdlFile.Name 
         }

         [xml]$rdlcontent =   Get-Content -Path $rdlFile.FullName

         $pbiDataSources = @()
         
         foreach ($rdlDatasource in $rdlcontent.Report.DataSources.GetElementsByTagName("DataSource")){

                if ($rdlDatasource.ConnectionProperties.DataProvider -eq "PBIDATASET")
                {

                    $dsObject = $rdlObject.pbiDatasets | Where name -EQ $rdlDatasource.Name

                    if (!$dsObject){

                        $dsObject =   New-Object -TypeName psobject

                        $dsObject | Add-Member -NotePropertyName "name" -NotePropertyValue $rdlDatasource.Name

                        $dsObject | Add-Member -NotePropertyName "connectionString" -NotePropertyValue $rdlDatasource.ConnectionProperties.ConnectString

                    }

                    $pbiDataSources += @($dsObject)

                }
         }

           if ($pbiDataSources.Count -gt 0)
           {
                if( $rdlObject.psobject.properties.match('pbiDatasets').Count )
                {
                    $rdlObject.pbiDatasets = $pbiDataSources 

                }
                else
                {
                       $rdlObject | Add-Member -NotePropertyName "pbiDatasets" -NotePropertyValue $pbiDataSources 
                }
            }
            else
            {
                if( $rdlObject.psobject.properties.match('pbiDatasets').Count )
                {
                    $rdlObject.psobject.properties.remove('pbiDatasets')
                }               
            }


           #$rdlObject.pbiDatasets

          $rdlFileSettings += @($rdlObject )

    }

    if( $deployconfig.psobject.properties.match('paginatedReports').Count )
    {
             $deployconfig.paginatedReports = $rdlFileSettings

    }
    else
    {
            $deployconfig | Add-Member -NotePropertyName "paginatedReports" -NotePropertyValue $rdlFileSettings
    }




   # foreach ($pbitfile in $pbitFiles)
   # {

       # $pbitFileFullName = $pbitfile.FullName
       # $pbitFileName = $pbitfile.Name

        #"Processing $pbitFileName"

    #     $jsonObject = GetOrCreatePbitFileConfig -pbitFile $pbitfile -pbitConfig $PbitConfig

        #"Finsihed Processing $pbitFileName"

    #}

    return $deployconfig
    
}

function GetOrCreateDataflowConfig
{
    [OutputType([PSCustomObject])]
    param (
       [ValidateNotNullOrEmpty()]
       [System.IO.DirectoryInfo] $dataflowrootdir,
       [ValidateNotNullOrEmpty()]
       [PSCustomObject] $deployconfig
    )

   # $pbitConfigPath = GetPbitConfigFileInfo -pbitRootDir $pbitrootdir

    $dataflowFilter = [IO.Path]::Combine($dataflowrootdir.FullName, "*.json")

    $dataflowFiles = Get-ChildItem -Path $dataflowFilter

    $dataflowFileSettings = @()

    foreach ($dataflowFile in $dataflowFiles)
    {
       #TODO:  Get the actual dataflow  element.
         $dataflowObject = $deployconfig.dataflows | Where name -EQ $dataflowFile.Name

         if(!$dataflowObject)
         {
             $dataflowObject =  New-Object -TypeName psobject
             $dataflowObject | Add-Member -NotePropertyName "name" -NotePropertyValue $dataflowFile.Name 
         }

         $dataflowJson = Get-Content -Path $dataflowFile | ConvertFrom-Json

         $dataflowDoc = $dataflowJson."pbi:mashup".document


       $match = Select-String ($dataflowParamRegEx) -InputObject $dataflowDoc -AllMatches

       $dataflowParams = @()

       foreach ($mth in $match.Matches)
            {

                $paramName = $mth.Groups['param'].Value
                $paramValue = $mth.Groups['defaultVal'].Value
                $paramMeta = $mth.Groups['meta'].Value

                #$defaultValueMatch = Select-String (SelectParamDefaultValueRegEx) -InputObject $paramMeta  -AllMatches

                #if ($defaultValueMatch.Matches.Success){

                #    $paramValue = $defaultValueMatch.Matches.Groups[1].Value

                #}

                 $dataflowParamObject = $dataflowObject.mQueryParameters | Where parameter -EQ $paramName

                 if(!$dataflowParamObject)
                 {
                     $dataflowParamObject =  New-Object -TypeName psobject
                     $dataflowParamObject | Add-Member -NotePropertyName "parameter" -NotePropertyValue $paramName
                 }


                 if (!$dataflowParamObject.defaultValue)
                 {
                     $dataflowParamObject | Add-Member -NotePropertyName "defaultValue" -NotePropertyValue $paramValue                    
                 }

                  $dataflowParams += @($dataflowParamObject )

            } 
            
            if( $dataflowObject.psobject.properties.match('mQueryParameters').Count )
            {
                        $dataflowObject.mQueryParameters = $dataflowParams

            }
            else
            {
                    $dataflowObject | Add-Member -NotePropertyName "mQueryParameters" -NotePropertyValue $dataflowParams
            }         

          
          
           #$rdlObject.pbiDatasets

          $dataflowFileSettings += @($dataflowObject )

    }

    if( $deployconfig.psobject.properties.match('dataflows').Count )
    {
             $deployconfig.dataflows = $dataflowFileSettings

    }
    else
    {
            $deployconfig | Add-Member -NotePropertyName "dataflows" -NotePropertyValue $dataflowFileSettings
    }




   # foreach ($pbitfile in $pbitFiles)
   # {

       # $pbitFileFullName = $pbitfile.FullName
       # $pbitFileName = $pbitfile.Name

        #"Processing $pbitFileName"

    #     $jsonObject = GetOrCreatePbitFileConfig -pbitFile $pbitfile -pbitConfig $PbitConfig

        #"Finsihed Processing $pbitFileName"

    #}

    return $deployconfig
    
}

function LoadDeployConfig
{
    [OutputType([PSCustomObject])]
    param (
       [ValidateNotNullOrEmpty()]
       [System.IO.FileInfo] $pbitconfigfile
    )  
    
    return Get-Content -Path $pbitconfigfile | ConvertFrom-Json
   
}

function GetOrCreateDeployConfig
{
    [OutputType([PSCustomObject])]
    param (
       [ValidateNotNullOrEmpty()]
       [System.IO.FileInfo] $deployconfigfile,
       [String] $configuration
    )


    $fjson = @"
        {
        "pbitFiles" : [],
        "paginatedReports" : [],
        "refreshGroups" : []
        }
"@

    if ($deployconfigfile.Exists) 
    {
         $fjson =  Get-Content -Path $deployconfigfile.FullName 
    }
    
    $deployConfig = $fjson |  ConvertFrom-Json


## Process Pbit Files

    
    $pbitDir = [IO.Path]::Combine($deployconfigfile.DirectoryName,"pbit/")
    $pbitObject = GetOrCreatePbitConfig -pbitrootdir $pbitDir -configuration $configuration


    if( $deployConfig.psobject.properties.match('pbitFiles').Count )
    {
           $deployConfig.pbitFiles = $pbitObject.pbitFiles

    }
    else
    {
            $deployConfig | Add-Member -NotePropertyName "pbitFiles" -NotePropertyValue $pbitObject.pbitFiles
    }

    


    $rdlDir = [IO.Path]::Combine($deployconfigfile.DirectoryName,"rdlReports/")
    $deployConfig = GetOrCreateRdlConfig -rdlrootdir $rdlDir -deployconfig $deployConfig


    $dataflowDir = [IO.Path]::Combine($deployconfigfile.DirectoryName,"dataflows/")
    $deployConfig = GetOrCreateDataflowConfig -dataflowrootdir $dataflowDir -deployconfig $deployConfig


    return $deployConfig
    
}

function CreateOrUpdateDeployConfig
{
    param (
       [ValidateNotNullOrEmpty()]
       [System.IO.DirectoryInfo] $projectrootDir,
       [String] $configuration
    )


    #$pbitDir = $projectRootDir.FullName + "\pbit\"




    if (!(Test-Path $projectrootDir)) 
    {
        "ProjectRootDir $projectrootDir does not exist."
        return
    }



    #if (!(Test-Path $pbitDir)) 
    #{
    #    "Project does not have a proper pbit folder.  For this project, pbit files should be stored in the following directory:  $pbitDir"
    #    return
    #}



    $deployConfigFile = GetDeployConfigFileInfo -projectrootDir $projectrootDir -configuration $configuration


    $deployConfigObject = GetOrCreateDeployConfig -deployconfigfile $deployConfigFile -configuration $configuration

    $deployConfigJson = $deployConfigObject | ConvertTo-Json -Depth 99

    $deployConfigJson | Set-Content -Path $deployConfigFile.FullName

    $deployConfigJson

}

function StagePaginatedReportsForDeployment
{

    param ([ValidateNotNullOrEmpty()]
    [System.IO.DirectoryInfo] $rdlsourcedir,
    [ValidateNotNullOrEmpty()]
    [System.IO.DirectoryInfo] $rdldeploydir,
    [ValidateNotNullOrEmpty()]
    [System.IO.FileInfo] $deployconfigfile,
    [ValidateNotNullOrEmpty()]
    [Guid] $workspaceid)



        if (!$rdldeploydir.Exists)
        {
            $rdldeploydir.Create()
        }

        $deployConfig = GetOrCreateDeployConfig -deployconfigfile $deployConfigFile

        $wsDataSets = GetWorkspaceDatasets -workspaceid $workspaceid

        foreach ($paginatedReport in $deployConfig.paginatedReports)
        {

           $sourceReportFile = [IO.FileInfo][IO.Path]::Combine($rdlsourcedir, $paginatedReport.name)
           $targetReportFile = [IO.FileInfo][IO.Path]::Combine($rdldeploydir, $paginatedReport.name)

           if ($sourceReportFile.Exists)
           {

                 [xml]$rdlcontent =   Get-Content -Path $sourceReportFile.FullName

                   $rdlDataSetNodes = $rdlcontent.Report.DataSources.GetElementsByTagName("DataSource")

                   foreach($pbidataset in $paginatedReport.pbiDatasets)
                   {
                        $pbidatasetNode = $rdlDataSetNodes | where Name -EQ  $pbidataset.name

                        if ($pbidatasetNode)
                        {

                            #Code to update dataset goes here....





                            $newConnectionString = $pbidataset.connectionString

                            if (![String]::IsNullOrEmpty($pbidataset.dataSetName))
                            {


                                    $pbidatasetInfo = $wsDataSets | where name -EQ $pbidataset.dataSetName

                                   $datasetId = $pbidatasetInfo.id             
                                                
                                $newConnectionString = "Data Source=pbiazure://api.powerbi.com/;Identity Provider=`"https://login.microsoftonline.com/common, https://analysis.windows.net/powerbi/api, $workspaceid`";Initial Catalog=sobe_wowvirtualserver-$datasetId;Integrated Security=ClaimsToken"


                            }


 


                            $pbidatasetNode.ConnectionProperties.ConnectString = $newConnectionString

                        }
                   }

                 $rdlcontent.Save($targetReportFile.FullName)

           }
        }



}

function StageDataflowsForDeployment
{

    param ([ValidateNotNullOrEmpty()]
    [System.IO.DirectoryInfo] $dataflowsourcedir,
    [ValidateNotNullOrEmpty()]
    [System.IO.DirectoryInfo] $dataflowdeploydir,
    [ValidateNotNullOrEmpty()]
    [System.IO.FileInfo] $deployconfigfile,
    [ValidateNotNullOrEmpty()]
    [Guid] $workspaceid)



        if (!$dataflowdeploydir.Exists)
        {
            $dataflowdeploydir.Create()
        }

        $deployConfig = GetOrCreateDeployConfig -deployconfigfile $deployConfigFile

        $wsDataSets = GetWorkspaceDatasets -workspaceid $workspaceid

        foreach ($dataflow in $deployConfig.dataflows)
        {

           $sourceDataflowFile = [IO.FileInfo][IO.Path]::Combine($dataflowsourcedir, $dataflow.name)
           $targetDataflowFile = [IO.FileInfo][IO.Path]::Combine($dataflowdeploydir, $dataflow.name)

           if ($sourceDataflowFile.Exists)
           {

                 $dataflowJsonObj = Get-Content -Path $sourceDataflowFile | ConvertFrom-Json

                 $dataflowDoc = $dataflowJsonObj."pbi:mashup".document


                 foreach ($dfParam in $dataflow.mQueryParameters)
                 {

                        $parameter = $dfParam.parameter

                        "now processing parameter $parameter"

                        $defaultValueReplacement = $dfParam.defaultValue 
               

                        ## Processing Other Properties..

                        if ($dfParam.useTargetWorkspaceId)
                        {
                            $defaultValueReplacement = "`"" + $workspaceid + "`""
                        }
                        elseif (![String]::IsNullOrEmpty($mQueryParameter.useIdOfDataflow))
                        {

                            $df =  $dataflows | where name -EQ $mQueryParameter.useIdOfDataflow

                            if ($df)
                            {

                                $defaultValueReplacement = "`"" + $df.objectId + "`""


                            }

                        }


                        $dataflowParamRegEx = 'shared[\s]*(?<param>[#" a-zA-Z]+)[\s]*=[\s]*let[\s\b]+(?<id1>[#" a-zA-Z]+)[\s]*=[\s]*(?<defaultVal>[a-zA-Z0-9_]+|"[^"]+")[\s]*meta[\s]*(?<meta>\[[^\]]*IsParameterQuery[\s]*=[\s]*true[^\]]*\])[\s]*in[\s]*\k<id1>;'


                        $paramValRegEx = "(shared $parameter = )null( meta \[[^\]]+\];)"

                        $paramValRegEx = "(shared[\s]*$parameter+[\s]*=[\s]*let[\s\b]+(?<id1>[#`" a-zA-Z]+)[\s]*=[\s]*)([a-zA-Z0-9_]+|`"[^`"]+`")([\s]*meta \[[^\]]+\][\s]*in[\s]*\k<id1>;)"


                        "Param Regex = $paramValRegEx" 

                        $replacementEx = "`$1$defaultValueReplacement`$3"

                        "param replacement = $replacementEx" 

                        $dataflowDoc = $dataflowDoc -replace $paramValRegEx, $replacementEx

                 }

                 $dataflowDoc 

                 #sAVE JSON FILE HERE...

                 $dataflowJsonObj."pbi:mashup".document = $dataflowDoc
                 
                 $dataflowJson = $dataflowJsonObj | ConvertTo-Json -Depth 99

                $dataflowJson | Set-Content -Path $targetDataflowFile
         
           
           }





        }



}