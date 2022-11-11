# PowerBi-Workspace-Alm-PS-Scripts
Power Shell Scripts for supporting Power Bi Workspace Application Lifecycle Management (ALM)]

I recently wrapped up a PowerBi consulting arrangement in which PowerBi development was done on my company's tenant and then deployed to a customers tenant.  I found that it was not quite that easy, so I had to develop tools to work around the challenges.  The scripts contained in this repository is the end result of my efforts.

This repository was created to share the work I did for the benefit of the broader Power Bi Maker/Developer community.  Please forgive me as these scripts were originally created to solve a one-off problem.   Code quality and standards were not a priority.  With that said, the scripts do work and could serve as a starting point for automating similar scenerios.

The scripts are provided as is.  As time permits, I may provide more guidance and insight.

# How the scripts work

The primary intent of the scripts is to:
1)  Export the contents of a powerbi workspace located in a non-production Office365 Tenant and decompose the parts of PBIX (dataset) files after they are manully saved as PBIT (Template) files.

2)  Import the artifacts from the Exported environment into a seperate Office365 Tenant by systematically updating appropriate workspace, dataflow, and dataset ids, recomponsing the components, importing the dataflows and rdl, then reconsituting the PBIT and opening it using the power bi desktop and walking the user through applying updates and saving the changes, at which point the scripts will import the update the PBIX files reconsituted in the customer's environment.

In practice, I recommend exporting workspaces to a GIT repository that is accessible from the source and target tenant environments.

# Getting Started

Exporting a workspace.

1)  To get started, copy all the .ps1 files to the root of a local file directory dedicated to one PowerBi workspace project.
2)  In that directory, save the workspace PBIX files as PBIT files in a subfolder called PBIT.
3)  Make the following modification to the ExportWorkspace.ps1 file:  Change the $SourceWorkspaceName = "[Enter Target Workspace Name Here]" line to specify the name of the source workspace to be exported.  This is the development environment.

4)  Run the ExportWorkspace.ps1 script.  Provide credentials when asked.  Let it do its thing.

5)  In addition to exporting components and decomposing the PBIT files, the export will create a series of configuration JSON files which can be modifed to specify certain changes or rules to apply when recomposing and importing the workspace.

Importing a workspace.

1) Make the following modification to the ImportWorkspace.ps1 file:  Change the $TargetWorkspaceName = "[Enter Target Workspace Name Here]" line to specify the name of the target workspace to import/update.  This is the typically a dev workspace in the production tenant.

2)   Run the ExportWorkspace.ps1 script.  Provide credentials when asked.  Let it do its thing.  Follow the instructions to reconsitute the PBIX files very carefully.  This part of the script execution is interactive and will not continue without user input.

# Configuring the import

When the export is run, it will create a series of json files called DeployConfig.json or DeployConfig.<config>.json.

These config files are created or updated during the export and serve as a manifest for importing into the target workspace.  The config files can also be used to specific certain rules to be follow as the target workspace is updated.   Please note the following elements:


The following custom setting can be used for Dataset / Power Query parameters meant to capture a target workspace ID.

pbitfiles : [ { "mQueryParamters" : [{"useTargetWorkspaceId":  <true>}] } ]

The following custom setting can be used for Dataset / Power Query parameters meant to capture a dataflow ID.

pbitfiles : [ { "mQueryParamters" : [{"useIdOfDataflow":  "<DataFlowName>"}] } ]
	
Refesh schedules for the target environment can be set using the following config setions:
"refreshGroups": [{ "dataflows" : [],
		    "datasets: : [] }],	

# Example DeployConfig.json 

The general structure of the JSON file is found below. 

{
   "refreshGroups": [{ "dataflows" : [],
			     "datasets: : [] }],
   "paginatedReports": [],	
   "pbitFiles":  [
                      {
                          "pbitFileName":  "<filename>",
                          "pbitFileBaseName":  "<filename>",
                          "mQueryParameters":  [
                                                   {
                                                       "parameter":  "<Parameter>",
                                                       "defaultValue":  "<DefaultValue>"
                                                   },
                                                   {
                                                       "parameter":  "<Workspace Id Parameter>",
                                                       "defaultValue":  "<Dev Workspace ID>",
                                                       "useTargetWorkspaceId":  <true>
                                                   },
                                                   {
                                                       "parameter":  "<Dataflow ID Parameter>",
                                                       "defaultValue":  "<Dev Dataflow ID>",
                                                       "useIdOfDataflow":  "<DataFlowName>"
                                                   },
                                               ]
                  ],
   "dataflows": []

}




