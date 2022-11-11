
$PbiWorkspaceExportImported = $true

function GetWorkspaceIdByName{
    [OutputType([Guid])]
    param ([ValidateNotNullOrEmpty()]
    [string] $workspacename)

    $lowerWSN = $workspacename.ToLower()

    Write-Host "Attempting to determine ID for PBI Workspace $workspacename" -ForegroundColor Gray 

    $returnValue = [Guid]::Empty

    try
    {

      $gpbiwsResult = Get-PowerBIWorkspace -All -Filter "tolower(name) eq '$lowerWSN'" -ErrorAction Stop

       if ($gpbiwsResult)
        {

            $returnValue = $gpbiwsResult.Id

            Write-Host "SUCCESS: The ID for PBI Workspace $workspacename is $returnValue" -ForegroundColor Green 

        }
        else
        {

           Write-Warning "WARNING: Unable to locate PBI Workspace $workspacename"

        }

    }
    catch
    {
        Write-Error "Error: Unable to determine the ID for PBI Workspace $workspacename"
        
        $lastPbiError = Resolve-PowerBIError -Last

        Write-Error $lastPbiError.Message
    }
    return $returnValue

}

Function Pause {

    param ([ValidateNotNullOrEmpty()]
    [string] $message)


   # Check if running in PowerShell ISE
   If ($psISE) {
      # "ReadKey" not supported in PowerShell ISE.
      # Show MessageBox UI
      $Shell = New-Object -ComObject "WScript.Shell"
      $Button = $Shell.Popup("$message\nClick OK to continue.", 0, "Hello", 0)
      Return
   }
 
   $Ignore =
      16,  # Shift (left or right)
      17,  # Ctrl (left or right)
      18,  # Alt (left or right)
      20,  # Caps lock
      91,  # Windows key (left)
      92,  # Windows key (right)
      93,  # Menu key
      144, # Num lock
      145, # Scroll lock
      166, # Back
      167, # Forward
      168, # Refresh
      169, # Stop
      170, # Search
      171, # Favorites
      172, # Start/Home
      173, # Mute
      174, # Volume Down
      175, # Volume Up
      176, # Next Track
      177, # Previous Track
      178, # Stop Media
      179, # Play
      180, # Mail
      181, # Select Media
      182, # Application 1
      183  # Application 2
 
   Write-Host -NoNewline "$message\nPress any key to continue..."
   While ($KeyInfo.VirtualKeyCode -Eq $Null -Or $Ignore -Contains $KeyInfo.VirtualKeyCode) {
      $KeyInfo = $Host.UI.RawUI.ReadKey("NoEcho, IncludeKeyDown")
   }
}




function GetWorkspaceDataflows{
    [OutputType([PSCustomObject[]])]
    param
    ([ValidateNotNullOrEmpty()]
    [Guid] $workspaceid)

    $getDataflowUrl = "groups/$workspaceid/dataflows"

    Write-Host "Getting pre-existing dataflows in PBI Workspace" -ForegroundColor Gray

    $result = [pscustomobject]@()

    try
    {
        $getDataflowResult = Invoke-PowerBIRestMethod -Url $getDataflowUrl -Method Get -ErrorAction Stop | ConvertFrom-Json

        $result =  $getDataflowResult.value

    }
    catch
    {
        Write-Error "Error: Unable get pre-existing dataflows."
        
        $lastPbiError = Resolve-PowerBIError -Last

        Write-Error $lastPbiError.Message
    }

    return $result

}



function GetWorkspaceDatasets{
    [OutputType([PSCustomObject[]])]
    param
    ([ValidateNotNullOrEmpty()]
    [Guid] $workspaceid)

    $getDatasetUrl = "groups/$workspaceid/datasets"

    Write-Host "Getting datasets in PBI Workspace" -ForegroundColor Gray

    $result = [pscustomobject]@()

    try
    {
        $getDatasetResult = Invoke-PowerBIRestMethod -Url $getDatasetUrl -Method Get -ErrorAction Stop | ConvertFrom-Json

        $result =  $getDatasetResult.value

    }
    catch
    {
        Write-Error "Error: Unable get workspace datasets."
        
        $lastPbiError = Resolve-PowerBIError -Last

        Write-Error $lastPbiError.Message
    }

    return $result

}


function ExportPowerBiWorkspaceDataFlows
{

    param ([ValidateNotNullOrEmpty()]
    [System.IO.DirectoryInfo] $targetdir,
    [ValidateNotNullOrEmpty()]
    [Guid] $workspaceid)


        if ($targetdir.Exists)
        {
            $targetdir.Delete($true)
        }

        $targetdir.Create()


        $dataFlows = Get-PowerBiDataFlow -WorkspaceId $workspaceid


        foreach ($dataFlow in $dataFlows)
        {

            $dfFileName = [IO.Path]::Combine($targetdir.FullName, $dataFlow.Name + ".json")
            $dfTmpFileName = [IO.Path]::Combine($targetdir.FullName, $dataFlow.Name + ".tmp.json")
            $dfMashupQFileName = [IO.Path]::Combine($targetdir.FullName, $dataFlow.Name + ".m" )   

            if (Test-Path $dfTmpFileName) 
            {
                 Remove-Item -Path $dfTmpFileName
            }

            Export-PowerBIDataflow -WorkspaceId $workspaceid -Id $dataFlow.Id -OutFile $dfTmpFileName


            $apiJson = Get-Content -Path $dfTmpFileName -Raw | ConvertFrom-Json

            foreach ($entity in $apiJson.entities)
            {

                $entityProperties = $entity.PSObject.Properties

                $entityProperties.Remove('partitions')


            }

            $pbiMashup = $apiJson.'pbi:mashup'

            $pbiMashup.document | Set-Content -Path $dfMashupQFileName -Force

           # $apijson

            $apijson | ConvertTo-Json -Depth 100 | Set-Content -Path $dfFileName -Force


            if (Test-Path $dfTmpFileName) 
            {
                 Remove-Item -Path $dfTmpFileName
            }

        }

}

function RenamePbiDataFlow
{
    [OutputType([bool])]

    param (
    [ValidateNotNullOrEmpty()]
    [Guid] $workspaceid,
    [ValidateNotNullOrEmpty()]
    [Guid] $dataflowid,
    [ValidateNotNullOrEmpty()]
    [string] $oldname,
    [ValidateNotNullOrEmpty()]
    [string] $newname)


         $renameDFBody = "{`"name`": `"$newname`"}"
         $renameDFUrl = "groups/$workspaceid/dataflows/$dataflowid"

         Write-Host "Renaming dataflow $oldname to $newname" -ForegroundColor Gray

         try
         {
         Invoke-PowerBIRestMethod -Url $renameDFUrl -Method Patch -Body $renameDFBody -ErrorAction Stop

         Write-Host "$oldname has succesfully been renamed to $newname" -ForegroundColor Gray

         return $true

         }
         catch
         {

            Write-Error "Error: Unable to rename dataflow $oldname."
        
            $lastPbiError = Resolve-PowerBIError -Last

            Write-Error $lastPbiError.Message

         }

         return $false

    }

function UpdatePbiDataFlowComputeSettings
{
    [OutputType([bool])]

    param (
    [ValidateNotNullOrEmpty()]
    [Guid] $workspaceid,
    [ValidateNotNullOrEmpty()]
    [Guid] $dataflowid,
    [ValidateNotNullOrEmpty()]
    [string] $computesetting)


         $updateDFBody = "{`"computeEngineBehavior`": `"$computesetting`"}"
         $updateDFUrl = "groups/$workspaceid/dataflows/$dataflowid"

         Write-Host "Updating dataflow compute setting" -ForegroundColor Gray

         try
         {
         Invoke-PowerBIRestMethod -Url $updateDFUrl -Method Patch -Body $updateDFBody -ErrorAction Stop

         Write-Host "Dataflow enhanced compute setting has been set to $computesetting" -ForegroundColor Gray

         return $true

         }
         catch
         {

            Write-Error "Error: Unable to update dataflow compute setting."
        
            $lastPbiError = Resolve-PowerBIError -Last

            Write-Error $lastPbiError.Message

         }

         return $false

    }

function RemoveDeprecatedDataFlows
{
    param ([ValidateNotNullOrEmpty()]
    [System.IO.DirectoryInfo] $targetdir,
    [ValidateNotNullOrEmpty()]
    [Guid] $workspaceid)


    Write-Host "Removing deprecated workflows" -ForegroundColor White -BackgroundColor DarkGray


    $preExistingDataflows = GetWorkspaceDataflows -workspaceid $workspaceid
 
    $dataFlowJsonFilter = [IO.Path]::Combine($targetdir,"*.json")
    $dataFlowJsonFiles = Get-ChildItem -Path $dataFlowJsonFilter


    foreach ($preExistingDF in $preExistingDataflows)
       {
 
            $preExistingDFName = $preExistingDF.name

            $dataFlowJsonFile = $dataFlowJsonFiles | where Name -EQ "$preExistingDFName.json"

            if (!$dataFlowJsonFile)
            {
                Write-Host "Workflow $preExistingDFName is deprecated. Attempting to remove it from the workspace" -ForegroundColor Gray


                $origDataFlowId =  $preExistingDF.objectId

                $removeDFUrl = "groups/$workspaceid/dataflows/$origDataFlowId"

                try
                {       
                    Invoke-PowerBIRestMethod -Url $removeDFUrl -Method Delete -ErrorAction Stop
                    Write-Host "Workflow $preExistingDFName has been removed successfully" -ForegroundColor Green
                }
                catch
                {
                        Write-Error "Error: Unable to remove  dataflow $preExistingDFName."
                        $lastPbiError = Resolve-PowerBIError -Last
                        Write-Error $lastPbiError.Message
                }
            }

       }
       
    Write-Host "Finished removing deprecated workflows" -ForegroundColor DarkGreen -BackgroundColor Gray       

}

function RemoveDeprecatedDatasets
{
    param ([ValidateNotNullOrEmpty()]
    [System.IO.DirectoryInfo] $targetdir,
    [ValidateNotNullOrEmpty()]
    [Guid] $workspaceid)


    Write-Host "Removing deprecated datasets" -ForegroundColor White -BackgroundColor DarkGray


    $onlineDatasets = GetWorkspaceDatasets -workspaceid $workspaceid
 
    $datasetFilter = [IO.Path]::Combine($targetdir,"*.pbix")
    $datasetFiles = Get-ChildItem -Path $datasetFilter


    foreach ($onlineDs in $onlineDatasets)
       {
 
            $dsName = $onlineDs.name

            $dsFile = $datasetFiles | where Name -EQ "$dsName.pbix"

            if (!$dsFile)
            {
                Write-Host "Dataset $dsName is deprecated. Attempting to remove it from the workspace" -ForegroundColor Gray


                $origDatasetId =  $onlineDs.id

                $removeDSUrl = "groups/$workspaceid/datasets/$origDatasetId"

                try
                {       
                    Invoke-PowerBIRestMethod -Url $removeDSUrl -Method Delete -ErrorAction Stop
                    Write-Host "Dataset $dsName has been removed successfully" -ForegroundColor Green
                }
                catch
                {
                        Write-Error "Error: Unable to remove  dataset $dsName."
                        $lastPbiError = Resolve-PowerBIError -Last
                        Write-Error $lastPbiError.Message
                }
            }

       }
       
    Write-Host "Finished removing deprecated datasets" -ForegroundColor DarkGreen -BackgroundColor Gray       

}

function RefreshDataFlows
{
    param ([ValidateNotNullOrEmpty()]
    [System.IO.FileInfo] $projectdir,
    [ValidateNotNullOrEmpty()]
    [Guid] $workspaceid,
    [String] $configuration)

        Write-Host "Attempting to refresh workspace dataflows" -ForegroundColor White -BackgroundColor DarkGray

        $preExistingDataflows = GetWorkspaceDataflows -workspaceid $workspaceid

        $refreshConfigJson = [IO.Path]::Combine($projectDir, "deployConfig.json")

        if (![String]::IsNullOrEmpty($configuration)){
            $refreshConfigJson = [IO.Path]::Combine($projectDir, "deployConfig.$configuration.json")
        }

        Write-Host "Loading deployment config located at $refreshConfigJson" -ForegroundColor Gray

         $refreshConfig = Get-Content -Path $refreshConfigJson | ConvertFrom-Json

        Write-Host "Initiating Dataflow Refreshes in accordance with the specified deployConfig.json" -ForegroundColor Gray

            $refreshGrpCnt = 0

            foreach ($refreshGroup in $refreshConfig.refreshGroups)
            {

                $refreshGrpCnt ++

                Write-Host "Processing Refresh Group $refreshGrpCnt" -ForegroundColor Gray

                $groupRefreshDataFlowIds = @()
                $groupRefreshTransactions = @()
        
                foreach ($refreshDF in $refreshGroup.dataflows)
                {

                        Write-Debug $refreshDF

                        $dataFlowName = $refreshDF.name

                                
                        $dataFlow = $preExistingDataflows | where name -EQ $dataFlowName

                        Write-Debug $dataFlow

                        if ($dataFlow)
                        {

                            $dataFlowId = $dataFlow.objectId

                            if (![String]::IsNullOrEmpty($refreshDF.enhancedComputeSetting))
                            {

                               $computeSettingChanged = UpdatePbiDataFlowComputeSettings -workspaceid $workspaceid -dataflowid $dataFlowId -computesetting $refreshDF.enhancedComputeSetting

                            }

                            $refreshDFUrl = "groups/$workspaceid/dataflows/$dataFlowId/refreshes"

                            $refreshDFBody = '{notifyOption: "NoNotification"}'

                            Write-Host "Attempting to initiate a refresh for dataflow $dataFlowName." -ForegroundColor Gray 

                            try
                            {
                            
                            Invoke-PowerBIRestMethod -Url $refreshDFUrl -Method Post -Body $refreshDFBody -ErrorAction Stop

                            $groupRefreshDataFlowIds += $dataFlowId

                            }
                            catch
                            {
                                    Write-Error "Error: Unable refresh dataflow $dataFlowName."
                                    $lastPbiError = Resolve-PowerBIError -Last
                                    Write-Error $lastPbiError.Message
                            }

                        }
                        else
                        {

                            Write-Warning "Dataflow $dataFlowName not found"

                        }
 
                }

                if ($groupRefreshDataFlowIds.Count -gt 0)
                {

                Write-Host "Wait for DataFlow group $refreshGrpCnt to complete refeshing" -ForegroundColor Gray 
                
                Start-Sleep -Seconds 5
        
                foreach ($dataflowId in $groupRefreshDataFlowIds)
                {
               
                        $dfTransactionsUrl = "groups/$workspaceid/dataflows/$dataFlowId/transactions"

                         $dataFlow = $preExistingDataflows | where objectId -EQ  $dataFlowId
                         $dataFlowName = $dataFlow.name

                        Write-Host "Getting $dataFlowName Refresh Transaction  $dfTransactionsUrl" -ForegroundColor Gray

                        $dfTransactions = Invoke-PowerBIRestMethod -Url $dfTransactionsUrl -Method Get  | ConvertFrom-Json

                        $inProgressTransaction = $dfTransactions.value | where status -EQ "InProgress"

                        if ($inProgressTransaction)
                        {

                         $inProgressTransaction | Add-Member -NotePropertyName "dataflowId" -NotePropertyValue $dataflowId

                         $groupRefreshTransactions += $inProgressTransaction

                        }

                }

                $finishedTransactionIds =  @()



                Write-Debug ("GroupRefreshTranCount = " + $groupRefreshTransactions.Count)
                Write-Debug ("FinishedTransactionCount = " + $finishedTransactionIds.Count)


                Write-Host "Monitoring Refresh Progress..." -ForegroundColor Magenta -NoNewline

                while ($groupRefreshTransactions.Count -gt $finishedTransactionIds.Count)
                  {

                         Start-Sleep -Seconds 3

                         foreach ($refreshTransaction in $groupRefreshTransactions)
                         {
                                $dataFlowId = $refreshTransaction.dataflowId

                                $dfTransactionsUrl = "groups/$workspaceid/dataflows/$dataFlowId/transactions"



                                $dfTransactions = Invoke-PowerBIRestMethod -Url $dfTransactionsUrl -Method Get  | ConvertFrom-Json

                                $currentTransaction = $dfTransactions.value | where id -EQ $refreshTransaction.id 
                        
                                If ( $currentTransaction)
                                {
                                    $currentTransactionStatus = $currentTransaction.status

                                    if ($currentTransactionStatus -eq "InProgress")
                                    {
                                       Write-Host "..." -NoNewline -ForegroundColor Magenta


                                       }
                                       else

                                       {

                                         $finishedTransactionIds += $refreshTransaction.dataflowId

                                         $dataFlow = $preExistingDataflows | where objectId -EQ  $dataFlowId
                                         $dataFlowName = $dataFlow.name

                                         Write-Host ""

                                         if ($currentTransactionStatus -eq "Success")
                                         {
                                             Write-Host "SUCCESS:  $dataFlowName refresh complete" -ForegroundColor Green

                                         }
                                         else
                                         {

                                               Write-Error "ERROR: Attempt to refresh $dataFlowName ended with a status of $currentTransactionStatus"
                                         }


                                             if ($groupRefreshTransactions.Count -gt $finishedTransactionIds.Count)
                                             {

                                                Write-Host "Resuming monitoring..." -ForegroundColor Magenta -NoNewline
                                             }

                                        }
                                }
                                else
                                {

                                 $finishedTransactionIds += $refreshTransaction.dataflowId

                                Write-Error "something bad happened"

                                }

                         }

                  }

                Write-Host ""

                Write-Host "DataFlow group $refreshGrpCnt refresh attempts are complete" -ForegroundColor DarkGreen

             }
                else
                {
                Write-Host "DataFlow group $refreshGrpCnt is empty" -ForegroundColor DarkGreen
                }
            }


        Write-Host "Finished refreshing dataflows"  -ForegroundColor DarkGreen -BackgroundColor Gray


}

function TakeOverDataset
{
    [OutputType([bool])]

    param (
    [ValidateNotNullOrEmpty()]
    [Guid] $workspaceid,
    [ValidateNotNullOrEmpty()]
    [Guid] $datasetid)


         $takeoverdsUrl = "groups/$workspaceid/datasets/$datasetid/Default.TakeOver"

         Write-Host "Taking over dataset." -ForegroundColor Gray

         try
         {
         Invoke-PowerBIRestMethod -Url $takeoverdsUrl -Method Get  -ErrorAction Stop

         Write-Host "Sucessfully taken over dataset." -ForegroundColor Gray

         return $true

         }
         catch
         {

            Write-Error "Error: Unable to take over dataset."
        
            $lastPbiError = Resolve-PowerBIError -Last

            Write-Error $lastPbiError.Message

         }

         return $false

    }

function RefreshDataSets
{
    param ([ValidateNotNullOrEmpty()]
    [System.IO.FileInfo] $projectdir,
    [ValidateNotNullOrEmpty()]
    [Guid] $workspaceid,
    [String] $configuration)

        Write-Host "Attempting to refresh workspace datasets" -ForegroundColor White -BackgroundColor DarkGray

        $workspaceDatasets = GetWorkspaceDatasets -workspaceid $workspaceid

        $refreshConfigJson = [IO.Path]::Combine($projectDir, "deployConfig.json")

        if (![String]::IsNullOrEmpty($configuration)){
            $refreshConfigJson = [IO.Path]::Combine($projectDir, "deployConfig.$configuration.json")
        }

        Write-Host "Loading deployment config located at $refreshConfigJson" -ForegroundColor Gray

         $refreshConfig = Get-Content -Path $refreshConfigJson | ConvertFrom-Json

        Write-Host "Initiating Dataset Refreshes in accordance with the specified deployConfig.json" -ForegroundColor Gray

            $refreshGrpCnt = 0

            foreach ($refreshGroup in $refreshConfig.refreshGroups)
            {

                $refreshGrpCnt ++

                Write-Host "Processing Refresh Group $refreshGrpCnt" -ForegroundColor Gray

                $groupRefreshDatasetIds = @()
                $groupRefreshTransactions = @()
        
                foreach ($refreshDS in $refreshGroup.datasets)
                {

                         Write-Debug $refreshDS

                        $datasetName = $refreshDS.name

                                
                        $dataset = $workspaceDatasets | where name -EQ $datasetName


                        if ($dataset)
                        {


                            Write-Debug $dataset                                

                            $datasetId = $dataset.id



                            $refreshDSUrl = "groups/$workspaceid/datasets/$datasetId/refreshes"

                            $refreshDSBody = '{notifyOption: "NoNotification"}'

                            Write-Host "Attempting to initiate a refresh for dataset $datasetName." -ForegroundColor Gray 

                            try
                            {
                            Invoke-PowerBIRestMethod -Url $refreshDSUrl -Method Post -Body $refreshDSBody -ErrorAction Stop

                            $groupRefreshDatasetIds += $datasetId 

                            }
                            catch
                            {
                                    Write-Error "Error: Unable refresh dataset $datasetName."
                                    $lastPbiError = Resolve-PowerBIError -Last
                                    Write-Error $lastPbiError.Message
                            }
                        }
                        else
                        {

                            Write-Warning "Dataset $datasetName not found"

                        }
 
                }


                if ($groupRefreshDatasetIds.Count -gt 0)
                {

                Write-Host "Wait for Dataset group $refreshGrpCnt to complete refeshing" -ForegroundColor Gray 

                #Start-Sleep -Seconds 5

        
                foreach ($datasetId in $groupRefreshDatasetIds)
                {
               
                        $dsTransactionsUrl = "groups/$workspaceid/datasets/$datasetId/refreshes?`$top=1"

                         $dataset = $workspaceDatasets | where id -EQ  $datasetId
                         $datasetName = $dataset.name

                        Write-Host "Getting $datasetName Refresh Transaction" -ForegroundColor Gray

                        $dsTransactions = Invoke-PowerBIRestMethod -Url $dsTransactionsUrl -Method Get  | ConvertFrom-Json

                        $inProgressTransaction = $dsTransactions.value[0]

                        if ($inProgressTransaction)
                        {

                         $inProgressTransaction | Add-Member -NotePropertyName "datasetId" -NotePropertyValue $datasetId

                         $groupRefreshTransactions += $inProgressTransaction

                        }

                }

                $finishedTransactionIds =  @()



                Write-Debug ("GroupRefreshTranCount = " + $groupRefreshTransactions.Count)
                Write-Debug ("FinishedTransactionCount = " + $finishedTransactionIds.Count)


                Write-Host "Monitoring Refresh Progress..." -ForegroundColor Magenta -NoNewline

                while ($groupRefreshTransactions.Count -gt $finishedTransactionIds.Count)
                  {

                         Start-Sleep -Seconds 3

                         foreach ($refreshTransaction in $groupRefreshTransactions)
                         {
                                $datasetId = $refreshTransaction.datasetId

                                $dfTransactionsUrl = "groups/$workspaceid/datasets/$datasetId/refreshes?`$top=4"

                                $dsTransactions = Invoke-PowerBIRestMethod -Url $dfTransactionsUrl -Method Get  | ConvertFrom-Json

                                $currentTransaction = $dsTransactions.value | where id -EQ $refreshTransaction.id 
                        
                                If ( $currentTransaction)
                                {
                                    $currentTransactionStatus = $currentTransaction.status

                                    if ($currentTransactionStatus -eq "Unknown")
                                    {
                                       Write-Host "..." -NoNewline -ForegroundColor Magenta


                                       }
                                       else

                                       {

                                         $finishedTransactionIds += $refreshTransaction.datasetId

                                         $dataset = $workspaceDatasets | where id -EQ  $datasetId
                                         $datasetName = $dataset.name

                                         Write-Host ""

                                         if ($currentTransactionStatus -eq "Completed")
                                         {
                                             Write-Host "SUCCESS:  $datasetName refresh complete" -ForegroundColor Green

                                         }
                                         else
                                         {

                                               Write-Error "ERROR: Attempt to refresh $datasetName ended with a status of $currentTransactionStatus"
                                         }


                                             if ($groupRefreshTransactions.Count -gt $finishedTransactionIds.Count)
                                             {

                                                Write-Host "Resuming monitoring..." -ForegroundColor Magenta -NoNewline
                                             }

                                        }
                                }
                                else
                                {

                                 $finishedTransactionIds += $refreshTransaction.dataflowId

                                Write-Error "something bad happened"

                                }

                         }

                  }

                Write-Host ""

                Write-Host "Dataset group $refreshGrpCnt refresh attempts are complete" -ForegroundColor DarkGreen

                }
                else
                {

                Write-Host "Dataset group $refreshGrpCnt is empty" -ForegroundColor DarkGreen

                }

            }


        Write-Host "Finished refreshing datasets"  -ForegroundColor DarkGreen -BackgroundColor Gray


}

function ScheduleRefreshes
{
    param ([ValidateNotNullOrEmpty()]
    [System.IO.FileInfo] $projectdir,
    [ValidateNotNullOrEmpty()]
    [Guid] $workspaceid,
    [String] $configuration)


        Write-Host "Attempting to schedule refreshes" -ForegroundColor White -BackgroundColor DarkGray

        $refreshConfigJson = [IO.Path]::Combine($projectDir, "deployConfig.json")

        if (![String]::IsNullOrEmpty($configuration)){
            $refreshConfigJson = [IO.Path]::Combine($projectDir, "deployConfig.$configuration.json")
        }

        Write-Host "Loading deployment config located at $refreshConfigJson" -ForegroundColor Gray

        $refreshConfig = Get-Content -Path $refreshConfigJson | ConvertFrom-Json

        $wsDataFlows = GetWorkspaceDataflows -workspaceid $TargetWsId 

        Write-Host "Setting Dataflows' Scheduled Refreshes" -ForegroundColor Gray

        foreach ($dfConfig in $refreshConfig.refreshGroups.dataFlows)
        {

            $dfName = $dfConfig.name
            
            $df = $wsDataFlows | where name -EQ $dfName

            if ($df)
            {

                 Write-Host "Scheduling refresh for $dfName dataflow" -ForegroundColor Gray

                $dfId = $df.objectId


                $refreshShedValue = $dfConfig.refreshSchedule | ConvertTo-Json -Depth 99

                $requestBody = "{`"value`" : $refreshShedValue }"

                $dfrefreshSchedUrl = "groups/$workspaceid/dataflows/$dfId/refreshSchedule"

                try
                {
                Invoke-PowerBIRestMethod -Url $dfrefreshSchedUrl -Method Patch -Body $requestBody -ErrorAction Stop
                 Write-Host "SUCCESS: Refresh scheduled for $dfName dataflow" -ForegroundColor Green
                }
                catch
                {

                    Write-Error "Error: Unable schedule refresh for $dfName dataflow."
                    $lastPbiError = Resolve-PowerBIError -Last
                    Write-Error $lastPbiError.Message
                }

            }

         }


        $wsDatasets = GetWorkspaceDatasets -workspaceid $TargetWsId 

        Write-Host "Setting Datasets' Scheduled Refreshes" -ForegroundColor Gray

        foreach ($dsConfig in $refreshConfig.refreshGroups.datasets)
        {

            $dsName = $dsConfig.name
            
            $ds = $wsDatasets | where name -EQ $dsName

            if ($ds)
            {




                $dsid = $ds.id


                if ($dsConfig.refreshSchedule)
                {

                    ## Set refreshSchedule

                     Write-Host "Scheduling refresh for $dsName dataset" -ForegroundColor Gray
               

                    $refreshShedValue = $dsConfig.refreshSchedule | ConvertTo-Json -Depth 99

                    $requestBody = "{`"value`" : $refreshShedValue }"

                    $dsrefreshSchedUrl = "groups/$workspaceid/datasets/$dsid/refreshSchedule"


                    try
                    {
                    Invoke-PowerBIRestMethod -Url $dsrefreshSchedUrl -Method Patch -Body $requestBody -ErrorAction Stop
                     Write-Host "SUCCESS: Refresh scheduled for $dsName dataset" -ForegroundColor Green
                    }
                    catch
                    {

                        Write-Error "Error: Unable schedule refresh for $dsName dataset."
                        $lastPbiError = Resolve-PowerBIError -Last
                        Write-Error $lastPbiError.Message
                    }

                }

                ## Set directQueryRefreshSchedule

                if ($dsConfig.directQueryRefreshSchedule)
                {


                     Write-Host "Scheduling directQueryRefresh for $dsName dataset" -ForegroundColor Gray



                    $refreshShedValue = $dsConfig.directQueryRefreshSchedule | ConvertTo-Json -Depth 99

                    $requestBody = "{`"value`" : $refreshShedValue }"

                    $dsrefreshSchedUrl = "groups/$workspaceid/datasets/$dsid/directQueryRefreshSchedule"


                    try
                    {
                    Invoke-PowerBIRestMethod -Url $dsrefreshSchedUrl -Method Patch -Body $requestBody -ErrorAction Stop
                     Write-Host "SUCCESS: Refresh directQueryRefresh for $dsName dataset" -ForegroundColor Green
                    }
                    catch
                    {

                        Write-Error "Error: Unable schedule directQueryRefresh for $dsName dataset."
                        $lastPbiError = Resolve-PowerBIError -Last
                        Write-Error $lastPbiError.Message
                    }

                }


            }

         }


        Write-Host "Finished scheduling refreshes"  -ForegroundColor DarkGreen -BackgroundColor Gray


}

function CreateOrUpdatePbiDataFlow
{
    param ([ValidateNotNullOrEmpty()]
    [System.IO.FileInfo] $dataflowfile,
    [ValidateNotNullOrEmpty()]
    [Guid] $workspaceid,
    [PSCustomObject[]] $workflows)

    $TargetDFPath = $dataflowfile.FullName
    $TargetDFName = $dataflowfile.BaseName

    Write-Host ""

    $preExistingWorkflows = $workflows

    if (!$workflows){

         $preExistingWorkflows = GetWorkspaceDataflows -workspaceid $workspaceid

    }

    $TempDFName = [Guid]::NewGuid()

    $getOrigDataflow =   $preExistingWorkflows |  where name -eq $TargetDFName

    if ($getOrigDataflow)
    {

        $origDataFlowId =  $getOrigDataflow.objectId

         Write-Host "$TargetDFName already exists.  Starting the process to replace it by by giving it a temporary name." -ForegroundColor Gray

         if((RenamePbiDataFlow -workspaceid $workspaceid -dataflowid $origDataFlowId -oldname $TargetDFName -newname $TempDFName) )
         {
             Write-Host "$TargetDFName has been renamed and is ready to be replaced." -ForegroundColor Gray
         }
         else
         {
             Write-Error "Unable to rename workflow $TargetDFName.  The workflow will not be updated.  Please try again.  If the error continues, the workflow may need to be deleted manually before attempting to import an update." -ForegroundColor Gray
             return
         }
    }


        try
        {
        
         Write-Host "Attempting to import $TargetDFName" -ForegroundColor Gray   
        
         $newDataFlowReport = New-PowerBIReport -Path $TargetDFPath -Name "model.json" -WorkspaceId $workspaceid -ErrorAction Stop

         Write-Host "Successfully imported $TargetDFName" -ForegroundColor Gray 

        }
        catch
        {

            Write-Error "Error: Unable to import $TargetDFName.  The updated dataflow will not be imported."
        
            $lastPbiError = Resolve-PowerBIError -Last

            Write-Error $lastPbiError.Message

            if ($getOrigDataflow)
            {

                Write-Host "Restoring original $TargetDFName"

                RenamePbiDataFlow -workspaceid $workspaceid -dataflowid $origDataFlowId -oldname $TempDFName -newname $TargetDFName

            }
            return
        }




    if ($getOrigDataflow)
    {

        $origDataFlowId =  $getOrigDataflow.objectId

        $removeDFUrl = "groups/$workspaceid/dataflows/$origDataFlowId"

        Write-Host "Attempting to remove orig dataflow $dataflowName" -ForegroundColor Gray
       
        Invoke-PowerBIRestMethod -Url $removeDFUrl -Method Delete

    }


     Write-Host "SUCCESS: Dataflow $TargetDFName successfully updated." -ForegroundColor Green


}

function ImportPowerBiWorkspaceDataFlows
{
    param ([ValidateNotNullOrEmpty()]
    [System.IO.DirectoryInfo] $targetdir,
    [ValidateNotNullOrEmpty()]
    [Guid] $workspaceid)




   Write-Host "Attempting to import Workspace Dataflows" -ForegroundColor White -BackgroundColor DarkGray


    $dataFlowJsonFilter = [IO.Path]::Combine($targetdir,"*.json")
    $dataFlowJsonFiles = Get-ChildItem -Path $dataFlowJsonFilter


   $preExistingWorkflows = GetWorkspaceDataflows -workspaceid $workspaceid

    foreach ($dataFlowJsonFile in $dataFlowJsonFiles)
    {

       Write-Host "Attempting to import dataflow " + $dataFlowJsonFile.Name -ForegroundColor Gray

       CreateOrUpdatePbiDataFlow -dataflowfile $dataFlowJsonFile -workspaceid $workspaceid -workflows $preExistingWorkflows

    }

   Write-Host "Finished importing Workspace Dataflows" -ForegroundColor DarkGreen -BackgroundColor Gray
}

function ImportPowerBiWorkspaceDatasets
{
    param ([ValidateNotNullOrEmpty()]
    [System.IO.DirectoryInfo] $targetdir,
    [ValidateNotNullOrEmpty()]
    [Guid] $workspaceid)


     Write-Host  "Atempting to import Workspace Datasets."    -ForegroundColor White -BackgroundColor DarkGray

    $datasetPbixFilter = [IO.Path]::Combine($targetdir,"*.pbit")

    $datasetPbixFiles = Get-ChildItem -Path $datasetPbixFilter
 
    $startInteractiveMessage = "Now starting installation of the pbix files. Before installing the pbix files, they must be opened, updated and saved in order to be sucessfully imported.  Because of this, the next steps are interactive."

    Write-Host "Importing datasets requires user interaction.  Please follow the guidance of the pop-up windows or prompts." -BackgroundColor Magenta -ForegroundColor White


    Pause -message $startInteractiveMessage


    foreach ($datasetPbixFile in $datasetPbixFiles)
    {

        Write-Debug $datasetPbixFile.Name

        $invokeExp = $datasetPbixFile.FullName

        $targetPbixSaveAsFile = [IO.FileInfo][System.IO.Path]::Combine($datasetPbixFile.DirectoryName, $datasetPbixFile.BaseName + ".pbix")

        $targetPbixBaseName = $targetPbixSaveAsFile.BaseName

        $targetPbixDirectory = $targetPbixSaveAsFile.DirectoryName
 
        $targetPbixFullName = $targetPbixSaveAsFile.FullName 
  
        if ($targetPbixSaveAsFile.Exists)
        {
            $targetPbixSaveAsFile.Delete()
        }

        $invokeExp = "$invokeExp /env:CurrentDirectory=$targetPbixDirectory"


        Write-Host "Attempting user interaction to locally refresh $targetPbixBaseName"  -BackgroundColor Magenta -ForegroundColor White
       

        Write-Host "Running Invoking-Expression `"$invokeExp`"": 


        Invoke-Expression $invokeExp



        Set-Clipboard -Value $targetPbixFullName

        Pause -message "Launching $targetPbixBaseName next.  Please apply updates and save the file.  The file MUST BE be saved as $targetPbixFullName.  For ease of use, $targetPbixFullName has been placed in the clipboard.  Proceed only after you have saved the file in the same location from which it has been launched."

        Write-Host  "Attempting to import dataset $datasetPbixName" -ForegroundColor Gray

        try
        {
            $newPBIDataset = New-PowerBIReport -Path $targetPbixSaveAsFile.FullName -Name $targetPbixSaveAsFile.Name -ConflictAction CreateOrOverwrite -WorkspaceId $workspaceid -ErrorAction Stop
            Write-Host  "SUCCESS: Dataset $targetPbixBaseName import complete" -ForegroundColor Green
        }
        catch
        {
            Write-Error "Error: Unable to import dataset $targetPbixBaseName"
        
            $lastPbiError = Resolve-PowerBIError -Last

            Write-Error $lastPbiError.Message
        }

    }

     Write-Host "Finished importing workspace datasets." -ForegroundColor DarkGreen -BackgroundColor Gray

}

function RemoveAllPaginatedReports{
    param
    ([ValidateNotNullOrEmpty()]
    [Guid] $workspaceid)

    Write-Host  "Atempting to remove Workspace Paginated Reports."  -ForegroundColor White -BackgroundColor DarkGray
    
    $getPaginatedReportUrl = "groups/$workspaceid/reports?%24filter=reportType%20eq%20Microsoft.PowerBI.ServiceContracts.ReportType'PaginatedReport'"
   
    try
    {

    $paginatedReportResult = Invoke-PowerBIRestMethod -Url $getPaginatedReportUrl -Method Get -ErrorAction Stop | ConvertFrom-Json

    foreach ($rdlReport in  $paginatedReportResult.value)
    {

        $rdlReportName = $rdlReport.name

        if ($rdlReport.reportType  -eq "PaginatedReport")
        {

            try
            {

                 Write-Host "Attempting to remove paginated report $rdlReportName" -ForegroundColor Gray
                 Remove-PowerBIReport -Id $rdlReport.id -WorkspaceId $TargetWsId -ErrorAction Stop
                 Write-Host  "Succesfully removed paginated report $rdlReportName" -ForegroundColor Green

            }
            catch
            {
                Write-Warning "WARNING: Unable to remove paginated report $rdlReportName"

                $lastPbiError = Resolve-PowerBIError -Last

                Write-Warning $lastPbiError.Message
            }

        }

    }



    }
    Catch
    {
                Write-Warning "WARNING: Unable to identify paginated reports for the workspace $TargetWsId"

                $lastPbiError = Resolve-PowerBIError -Last
                Write-Warning $lastPbiError.Message
    }

    Write-Host  "Finsihed attempting to remove paginated reports."   -ForegroundColor DarkGreen -BackgroundColor Gray 

}

function ImportPowerBiWorkspacePaginatedReports
{
    param ([ValidateNotNullOrEmpty()]
    [System.IO.DirectoryInfo] $targetdir,
    [ValidateNotNullOrEmpty()]
    [Guid] $workspaceid)


    $rdlReportsFilter = [IO.Path]::Combine($targetdir,"*.rdl")

    $rdlReportFiles = Get-ChildItem -Path $rdlReportsFilter

    Write-Host  ("Attempting to import the workspace's Paginated Reports") -ForegroundColor White -BackgroundColor DarkGray

    foreach ($rdlReportFile in $rdlReportFiles)
    {
        Write-Host  ("Attempting to import Paginated Report " + $rdlReportFile.Name) -ForegroundColor Gray

       

        try
        {
            $newPaginatedReport = New-PowerBIReport -Path $rdlReportFile.FullName -Name $rdlReportFile.Name -WorkspaceId $workspaceid -ConflictAction Abort -ErrorAction Stop
            Write-Host  ("SUCCESS: Paginated Report " + $rdlReportFile.Name + " import complete") -ForegroundColor Green
        }
        catch
        {
            Write-Error ("Error: Unable to import Paginated Report " + $rdlReportFile.Name)
        
            $lastPbiError = Resolve-PowerBIError -Last

            Write-Error $lastPbiError.Message
        }

    }

   Write-Host  ("Finished importing the workspace's Paginated Reports")  -ForegroundColor DarkGreen -BackgroundColor Gray

}

function ExportPowerBiWorkspacePaginatedReports
{

    param ([ValidateNotNullOrEmpty()]
    [System.IO.DirectoryInfo] $targetdir,
    [ValidateNotNullOrEmpty()]
    [Guid] $workspaceid)


        if ($targetdir.Exists)
        {
            $targetdir.Delete($true)
        }

        $targetdir.Create()


        $pbiReports = Get-PowerBiReport -WorkspaceId $workspaceid -Scope Organization

        foreach ($pbiReport in $pbiReports)
        {

     
            if ($pbiReport.WebUrl.Contains('rdlreports')){

                $rptExportFileName = [IO.Path]::Combine($targetdir.FullName, $pbiReport.Name + ".rdl")

                if (Test-Path $rptExportFileName) 
                {
                     Remove-Item -Path $rptExportFileName
                }

                 Export-PowerBIReport -Id $pbiReport.Id -WorkspaceId $workspaceid -OutFile $rptExportFileName

            }

        }


}


function ExportPowerBiWorkspace
{

    param ([ValidateNotNullOrEmpty()]
    [System.IO.DirectoryInfo] $targetdir,
    [ValidateNotNullOrEmpty()]
    [Guid] $workspaceid)



        if (!$targetdir.Exists)
        {
            $targetdir.Create()
        }

        $dataFlowDir = [IO.Path]::Combine($targetdir.FullName, "dataflows\")
        ExportPowerBiWorkspaceDataFlows -workspaceid $workspaceid -targetdir $dataFlowDir


        $rdlDir =  [IO.Path]::Combine($targetdir.FullName, "rdlReports\")
        ExportPowerBiWorkspacePaginatedReports  -workspaceid $workspaceid -targetdir $rdlDir


}


function GetWorkspacePipelineStage
{
    [OutputType([PSCustomObject])]
    param (
       [ValidateNotNullOrEmpty()]
       [Guid] $workspaceid
    )

    $getPipelinesUrl = 'pipelines?$expand=stages'

    $getPipelinesResult = Invoke-PowerBIRestMethod -Url $getPipelinesUrl -Method Get | ConvertFrom-Json

                 
    foreach ($pipeline in $getPipelinesResult.value)
    {

        $pipelineId = $pipeline.id

        $getPipelineWithStagesUrl = "pipelines/$pipelineId" + "?`$expand=stages"

        $pipelineWithStages = Invoke-PowerBIRestMethod -Url $getPipelineWithStagesUrl -Method Get  | ConvertFrom-Json        


        foreach ($pipelineStage in $pipelineWithStages.stages)
        {
            try
            {
                if ([Guid]::Parse($pipelineStage.workspaceId) -eq $workspaceid)
                {

                $pipeline | Add-Member -NotePropertyName "workspaceStage" -NotePropertyValue $pipelineStage.order

                $pipeline | Add-Member -NotePropertyName "unassignUrl" -NotePropertyValue ('pipelines/' + $pipeline.id + '/stages/' + $pipelineStage.order + '/unassignWorkspace')

                $pipeline | Add-Member -NotePropertyName "assignUrl" -NotePropertyValue ('pipelines/' + $pipeline.id + '/stages/' + $pipelineStage.order + '/assignWorkspace')

                $pipeline | Add-Member -NotePropertyName "assignUrlBody" -NotePropertyValue ('{"workspaceId":"' + $workspaceid + '"}')

                $pipeline | Add-Member -NotePropertyName "artifactUrl" -NotePropertyValue ('pipelines/' + $pipeline.id + '/stages/' + $pipelineStage.order + '/artifacts')

                $pipeline | Add-Member -NotePropertyName "pilelineUrl" -NotePropertyValue ('pipelines/' + $pipeline.id)

                $pipeline | Add-Member -NotePropertyName "pilelineStagesUrl" -NotePropertyValue ('pipelines/' + $pipeline.id+ '/stages')

                $pipeline | Add-Member -NotePropertyName "pilelineOpsUrl" -NotePropertyValue ('pipelines/' + $pipeline.id + '/operations')


                  return $pipeline
                                     
                }
            }
            catch
            {
                #no issues if there is not a workspaceid property.
            }
        }
    } 
    
    return $null   

}


if (!(Get-Module -ListAvailable -Name MicrosoftPowerBIMgmt))
{

    try 
    {

         "Microsoft Power BI Management Module is required.  Attempting to install."

         Install-Module -Name MicrosoftPowerBIMgmt  -AllowClobber -Confirm:$False -Force  

    }
    catch [Exception] {
        $_.message 
        exit
    }
} 

Connect-PowerBIServiceAccount



