
$PSScriptRoot

$SourceWorkspaceName = "[Enter Target Workspace Name Here]"


. "$PSScriptRoot\PbiWorkspaceExportImport.ps1"
. "$PSScriptRoot\PbitPackaging.ps1"
. "$PSScriptRoot\deployconfig.ps1"


$currentScriptPath = $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Path $currentScriptPath


$wsID = GetWorkspaceIdByName -workspacename $SourceWorkspaceName

ExportPowerBiWorkspace -targetdir $projectDir -workspaceid $wsID

UnpackProjectPbits -projectRootDir $projectDir 

CreateOrUpdateDeployConfig -projectrootDir $projectDir 

CreateOrUpdatePbitConfig -projectRootDir $projectDir -configuration "sqa"

CreateOrUpdateDeployConfig -projectrootDir $projectDir  -configuration "sqa"


CreateOrUpdatePbitConfig -projectRootDir $projectDir -configuration "dev"

CreateOrUpdateDeployConfig -projectrootDir $projectDir  -configuration "dev"








