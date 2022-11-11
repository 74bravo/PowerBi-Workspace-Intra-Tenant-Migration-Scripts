$PSScriptRoot


$TargetWorkspaceName = "[Enter Target Workspace Name Here]"
$Configuration = ""


$currentScriptPath = $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Path $currentScriptPath


if (!($PbiWorkspaceExportImported)){

. "$PSScriptRoot\PbiWorkspaceExportImport.ps1"

}

 #   $lowerTargetWSN = $TargetWorkspaceName.ToLower()

# Get-PowerBIWorkspace -All -Filter "tolower(name) eq 'lab-pulse reports-deploy'" -ErrorAction Stop



#$TargetWsId = GetWorkspaceIdByName -workspacename $TargetWorkspaceName

    $rdlsearch = [IO.Path]::Combine($projectDir,"rdlReports\*.rdl")


#[IO.FileInfo]$rdlFile = "C:\repos\Mirion-Lab-Pulse\sandbox\rdlReports.rdl"


    $rdlFiles = Get-ChildItem -Path $rdlsearch


    $rdlFileSettings = @()

    foreach ($rdlFile in $rdlFiles){


         [xml]$rdlcontent =   Get-Content -Path $rdlFile.FullName

        $rdlObject =  New-Object -TypeName psobject
        $rdlObject | Add-Member -NotePropertyName "name" -NotePropertyValue $rdlFile.Name

         $pbiDataSources = @()
         
         foreach ($rdlDatasource in $rdlcontent.Report.DataSources.GetElementsByTagName("DataSource")){

                if ($rdlDatasource.ConnectionProperties.DataProvider -eq "PBIDATASET")
                {
                    $dsObject =   New-Object -TypeName psobject

                    $dsObject | Add-Member -NotePropertyName "name" -NotePropertyValue $rdlDatasource.Name

                    $dsObject | Add-Member -NotePropertyName "connectionString" -NotePropertyValue $rdlDatasource.ConnectionProperties.ConnectString

                    $pbiDataSources += @($dsObject)

                }
         }


           if ($pbiDataSources.Count -gt 0){

               
              $rdlObject | Add-Member -NotePropertyName "pbiDatasets" -NotePropertyValue $pbiDataSources 

           }

           #$rdlObject.pbiDatasets

          $rdlFileSettings += @($rdlObject )

    }

$rdlFileSettings   | ConvertTo-Json -Depth 99




 "Done"

