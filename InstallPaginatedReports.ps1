$PSScriptRoot


$TargetWorkspaceName = "[Enter Target Workspace Name Here]"

$Configuration = ""

$currentScriptPath = $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Path $currentScriptPath


. "$PSScriptRoot\PbiWorkspaceExportImport.ps1"
. "$PSScriptRoot\PbitPackaging.ps1"
. "$PSScriptRoot\deployconfig.ps1"


$TargetWsId = GetWorkspaceIdByName -workspacename $TargetWorkspaceName

$deployConfigFile = GetDeployConfigFileInfo -projectrootdir $projectDir -configuration $Configuration

#region Deploy Paginated Reports

    $rdlReportsDir = [IO.Path]::Combine($projectDir,"rdlReports\")
    $rdlDeployDir = [IO.DirectoryInfo][IO.Path]::Combine($projectDir,"deploy\rdl\")

    StagePaginatedReportsForDeployment -rdlsourcedir $rdlReportsDir -rdldeploydir $rdlDeployDir -deployconfigfile $deployConfigFile -workspaceid $TargetWsId

    RemoveAllPaginatedReports -workspaceid $TargetWsId

    ImportPowerBiWorkspacePaginatedReports -targetdir $rdlDeployDir -workspaceid $TargetWsId

#endregion


