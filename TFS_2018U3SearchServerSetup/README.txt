<#
.SYNOPSIS
This script will install and configure Elasticsearch and associated plugins on this machine to be used by Code Search in Azure DevOps Server. For more information read:
https://go.microsoft.com/fwlink/?LinkId=808050

**Note: This is a customized version of Elasticsearch, fine-tuned for Code Search on Azure DevOps Server.

Before you proceed, ensure you have Oracle JRE 7 Update 55 or higher, or JRE 8 Update 20 or higher installed and that JAVA_HOME variable is pointing to the Java installation directory. Read Java installation notes for more details:
https://go.microsoft.com/fwlink/?linkid=822603

.DESCRIPTION

.PARAMETER Operation
Type of install operation which needs to be performed.
Valid values are install, update, remove.
Other parameters are ignored when Operation is update or remove.
The default value of Operation is install

.PARAMETER TFSSearchInstallPath
Location where Elasticsearch is installed. (The location provided should be empty)

.PARAMETER TFSSearchIndexPath
Location on this machine where Elasticsearch indices\data will be stored.
For Code Search hardware requirements read https://www.visualstudio.com/en-us/docs/search/administration
* For maximum performance, choose a folder backed by a solid state drive (SSD).

.PARAMETER Port
Value of the port with which Elasticsearch will be configured. Valid range is 9200-9299.
Default value is 9200. 

.PARAMETER User
Value of the user with which basic authentication is configured in elasticsearch

.PARAMETER Password
Value of the password with which basic authentication is configured in elasticsearch

.PARAMETER Quiet
This switch if provided will bypass the first confirmation from user to make the script fully non interactive.

.EXAMPLE
Configure-TFSSearch.ps1 -Operation install -TFSSearchInstallPath C:\ES -TFSSearchIndexPath C:\ESDATA -User elasticuser -Password elasticPwd1 -Quiet
This will install the Elasticsearch at C:\ES and indices will be stored at C:\ESDATA
The confirmation from the user before installlation will not be asked since Quiet is true.

.EXAMPLE
Configure-TFSSearch.ps1 -Operation install -TFSSearchInstallPath C:\ES -TFSSearchIndexPath C:\ESDATA -User elasticuser -Password elasticPwd1 
This will install the Elasticsearch at C:\ES and indices will be stored at C:\ESDATA
Confirmation from the user will be asked before proceeding.

.EXAMPLE
Configure-TFSSearch.ps1 -Operation install -TFSSearchInstallPath C:\ES -TFSSearchIndexPath C:\ESDATA -User elasticuser -Password elasticPwd1 -Port 9201 -Quiet
This will install the Elasticsearch at C:\ES and indices will be stored at C:\ESDATA.
Elasticsearch will be installed on port 9201.
Confirmation from the user will not be asked before proceeding since -Quiet is true

.EXAMPLE
Configure-TFSSearch.ps1 -TFSSearchInstallPath C:\ES -TFSSearchIndexPath C:\ESDATA -Port 9200 -User elasticuser -Password elasticPwd1  -Verbose
Verbose logging will be enabled with '-Verbose' switch. Elasticsearch will be installed at C:\ES and indices will be stored at C:\ESDATA.
Elasticsearch will use 9200 port.

.EXAMPLE
Configure-TFSSearch.ps1
This will run the script in interactive mode and will prompt for inputs.

.EXAMPLE
Configure-TFSSearch.ps1 -Operation remove
This will remove the Elasticsearch from the system. You will be prompted before deleting the indices.

.EXAMPLE
Configure-TFSSearch.ps1 -Operation update -User elasticuser -Password elasticPwd1 
This will update the Elasticsearch installed on the system. Old settings\configuration will be used after the update.

.EXAMPLE
Configure-TFSSearch.ps1 -Operation update
This will update the Elasticsearch installed on the system. Old settings\configuration and old credentials (user\password) will be used after the update.
#>