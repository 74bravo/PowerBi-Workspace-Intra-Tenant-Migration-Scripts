$PSScriptRoot


$TargetWorkspaceName = "[Enter Target Workspace Name Here]"

$Configuration = ""


$currentScriptPath = $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Path $currentScriptPath


. "$PSScriptRoot\PbiWorkspaceExportImport.ps1"
. "$PSScriptRoot\PbitPackaging.ps1"
. "$PSScriptRoot\deployconfig.ps1"


$TargetWsId = GetWorkspaceIdByName -workspacename $TargetWorkspaceName

$deployConfigFile = GetDeployConfigFileInfo -projectrootdir $projectDir


#region Deploy Datasets/Pbit
    
    $deployPBITDir = [IO.DirectoryInfo][IO.Path]::Combine($projectDir,"deploy\pbix\")

    PackProjectPbits -projectRootDir $projectDir -targetPackedDir $deployPBITDir -targetwsid  $TargetWsId

   # ImportPowerBiWorkspaceDatasets -targetdir $deployPBITDir -workspaceid $TargetWsId

   # RefreshDataSets -projectdir $projectDir -workspaceid $TargetWsId

   #RemoveDeprecatedDatasets -targetdir $deployPBITDir -workspaceid $TargetWsId


#endregion
