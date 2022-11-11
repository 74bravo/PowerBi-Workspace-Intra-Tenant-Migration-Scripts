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


#region Check for participation in a pipeline. 


    Write-Host "Checking for participation in a PowerBi Pipeline" -ForegroundColor Gray

    $pipelineStage = GetWorkspacePipelineStage -workspaceid $TargetWsId

    if ($pipelineStage) {

        $pipelineName = $pipelineStage.displayName
        $pipelineStageName = $pipelineStage.workspaceStage

        Write-Host "Workspace particpates in pipeline $pipelineName as stage $pipelineStageName" -ForegroundColor Yellow

        Write-Host "Temporarily unassiging workspace from $pipelineName pipeline." -ForegroundColor Gray

        #Invoke-PowerBIRestMethod -Url $pipelineStage.unassignUrl -Method Post $TargetWsId
        try
        {
                 Invoke-PowerBIRestMethod -Url $pipelineStage.unassignUrl -Method Post -WarningAction SilentlyContinue -ErrorAction Stop
                 Write-Host "SUCCESS: Workspace removed from  $pipelineName pipeline." -ForegroundColor Green
        }
        catch
        {
            Write-Error "Error: Unable to remove Workspace from $pipelineName pipeline."
        
            lastPbiError = Resolve-PowerBIError -Last

            Write-Error $lastPbiError.Message

        }

    }
    else
    {
        Write-Host "Workspace does not participate in a PowerBi Pipeline" -ForegroundColor Gray
    }


#endregion

#region Deploy Dataflows

    $dataFlowDir = [IO.Path]::Combine($projectDir,"dataflows\")

    $dataflowDeployDir = [IO.DirectoryInfo][IO.Path]::Combine($projectDir,"deploy\dataflows\")

    StageDataflowsForDeployment -dataflowsourcedir $dataFlowDir -dataflowdeploydir $dataflowDeployDir -deployconfigfile $deployConfigFile -workspaceid $TargetWsId

    ImportPowerBiWorkspaceDataFlows -targetdir $dataflowDeployDir -workspaceid $TargetWsId 

    RemoveDeprecatedDataFlows -targetdir $dataflowDeployDir -workspaceid $TargetWsId

    RefreshDataFlows -projectdir $projectDir -workspaceid $TargetWsId -configuration $Configuration

#endregion

#region Deploy Datasets/Pbit
    
    $deployPBITDir = [IO.DirectoryInfo][IO.Path]::Combine($projectDir,"deploy\pbix\")

    PackProjectPbits -projectRootDir $projectDir -targetPackedDir $deployPBITDir -targetwsid  $TargetWsId -deployconfigfile $deployConfigFile -configuration $Configuration

    ImportPowerBiWorkspaceDatasets -targetdir $deployPBITDir -workspaceid $TargetWsId

    RefreshDataSets -projectdir $projectDir -workspaceid $TargetWsId -configuration $Configuration

    RemoveDeprecatedDatasets -targetdir $deployPBITDir -workspaceid $TargetWsId


#endregion

#region Deploy Paginated Reports

    $rdlReportsDir = [IO.Path]::Combine($projectDir,"rdlReports\")
    $rdlDeployDir = [IO.DirectoryInfo][IO.Path]::Combine($projectDir,"deploy\rdl\")

    StagePaginatedReportsForDeployment -rdlsourcedir $rdlReportsDir -rdldeploydir $rdlDeployDir -deployconfigfile $deployConfigFile -workspaceid $TargetWsId

    RemoveAllPaginatedReports -workspaceid $TargetWsId

    ImportPowerBiWorkspacePaginatedReports -targetdir $rdlDeployDir -workspaceid $TargetWsId

#endregion

#region Schedule Refreshes 

    ScheduleRefreshes -projectdir $projectDir -workspaceid $TargetWsId

#endregion

#region Adding back to pipeline

    if ($pipelineStage) {

 
        Write-Host "Reassigning workspace to $pipelineName pipeline." -ForegroundColor Gray

        #Invoke-PowerBIRestMethod -Url $pipelineStage.unassignUrl -Method Post $TargetWsId
        try
        {
                 Invoke-PowerBIRestMethod -Url $pipelineStage.assignUrl -Method Post -Body $pipelineStage.assignUrlBody -ErrorAction Stop
                 Write-Host "SUCCESS: Workspace reassigned to $pipelineName pipeline." -ForegroundColor Green
        }
        catch
        {
            Write-Error "Error: Unable to remove Workspace from $pipelineName pipeline."
        
            lastPbiError = Resolve-PowerBIError -Last

            Write-Error $lastPbiError.Message

        }


    }


#endregion