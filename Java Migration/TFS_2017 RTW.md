Below diagram explains the steps to migrate from Oracle JRE to Azul Zulu OpenJDK for TFS 2017 RTW.

![Java Migration flow](flow2.png)

## Step 1: Pause Search indexing
Go to https://github.com/Microsoft/Code-Search and find the right folder based on the TFS version you are using. In this case, go to [TFS 2017 RTW](../TFS_2017RTW). To pause all indexing, execute the script PauseSearchIndexing.ps1 on TFS server machine from Windows PowerShell with administrative privileges. You will be prompted to enter:

* The SQL server instance name where the TFS configuration database resides.
* The name of the TFS configuration database.

## Step 2: Stop and Remove Elasticsearch Service
Open Command Prompt as an administrator 

If Elasticsearch is installed on the same server as TFS (local installation), use below command to locate ES folder. For remote search installations, locate the ES installation path and change the directory accordingly.
### Change directory: 
cd "C:\Program Files\Microsoft Team Foundation Server 15.0\Search\ES\elasticsearch-1.7.1-SNAPSHOT\bin"
### Stop the service:
execute "service.bat stop"

### Remove the service:
execute "service.bat remove"

## Step 4: Download and Install Azul Zulu Java 
Download and install latest version of [OpenJDK 7](https://www.azul.com/downloads/zulu-community/?&version=java-7-lts&os=windows&os-details=Windows&architecture=x86-64-bit&package=jdk)

## Step 5: Update JAVA_HOME with Azul Zulu path
![Update Java Home](java_home.png)

## Step 6: Install and Start Elasticsearch Service
Open Command Prompt as an administrator 

If Elasticsearch is installed on the same server as TFS (local installation), use below command to locate ES folder. For remote search installations, locate the ES installation path and change the directory accordingly.
### Change directory: 
cd "C:\Program Files\Microsoft Team Foundation Server 15.0\Search\ES\elasticsearch-1.7.1-SNAPSHOT\bin"
### Install the service:
execute "service.bat install"

### Start the service:
execute "service.bat start"

## Step 8: Resume Search indexing
Go to https://github.com/Microsoft/Code-Search and find the right folder based on the TFS version you are using. In this case, go to [TFS 2017 RTW](../TFS_2017RTW). If indexing was paused, execute the script ResumeSearchIndexing.ps1 with administrative privileges, to resume indexing again. You will be prompted to enter:

* The SQL server instance name where the TFS configuration database resides.
* The name of the TFS configuration database.
