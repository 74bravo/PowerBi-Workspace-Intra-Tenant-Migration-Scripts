$PSScriptRoot


$TargetWorkspaceName = "[Enter Target Workspace Name Here]"


$currentScriptPath = $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Path $currentScriptPath


. "$PSScriptRoot\PbiWorkspaceExportImport.ps1"
. "$PSScriptRoot\PbitPackaging.ps1"
. "$PSScriptRoot\deployconfig.ps1"


$TargetWsId = GetWorkspaceIdByName -workspacename $TargetWorkspaceName

$deployConfigFile = GetDeployConfigFileInfo -projectrootdir $projectDir

#region Schedule Refreshes 

    ScheduleRefreshes -projectdir $projectDir -workspaceid $TargetWsId

#endregion

