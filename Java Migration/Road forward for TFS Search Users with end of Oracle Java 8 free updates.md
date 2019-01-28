Road forward for TFS Search Users with end of Oracle Java 8 free updates

Oracle Java SE 8 is undergoing the “End of Public Updates” process, which means there will be no longer free updates to JRE (Java Runtime Environment) for commercial use after January 2019. This has an impact on Team Foundation Server Search feature (Code, Work Item and Wiki) users because existing TFS versions including the latest version TFS 2018 Update 3.2 have dependencies on Elasticsearch versions 5.4.1 or less, which in turn have a dependency on Oracle Java JRE 8.
What is the impact for existing TFS Search users (Code, Work Item and Wiki)?
Existing TFS users can continue to use Search (Code, Work Item and Wiki) along with Oracle JRE 8 for free but they will not get free updates to JRE 8 from Oracle. Since JRE 8 updates comprise of bug fixes and critical security updates, TFS Search users are strongly recommended to choose one of the below options and thereby continue to get Java updates.

Option 1: Move from Oracle JRE 8 to Azul Zulu OpenJDK 8
In the Azure DevOps Search service, we are already using Azul Zulu’s builds of OpenJDK. Since OpenJDK (and by extension Azul Zulu OpenJDK) is supported by Elasticsearch, when users replace Oracle JRE 8 with Azul Zulu OpenJDK 8 in their machines, TFS Search will work as expected without breaking anything. Note that changing Java provider from Oracle to Azul would not require a TFS downtime. 
Steps for migrating from Oracle JRE to Azul Zulu Java (for all versions of TFS except 2017 RTW)
Below diagram explains the steps to migrate from Oracle JRE to Azul Zulu OpenJDK for all versions of TFS except 2017 RTW without incurring any TFS downtime.
 
Step 1: Pause Search indexing
Go to https://github.com/Microsoft/Code-Search and find the right folder based on the TFS version you are using E.g. If you are using TFS 2018 Update3.2, go to https://github.com/Microsoft/Code-Search/tree/master/TFS_2018Update3. To pause all indexing, execute the script PauseSearchIndexing.ps1 from Windows PowerShell with administrative privileges.. You will be prompted to enter:
•	The SQL server instance name where the TFS configuration database resides.
•	The name of the TFS configuration database.
Step 2: Stop Elasticsearch Service
1.	Open Command Prompt as an administrator 
2.	Change directory: 
For TFS 2017 Update 1, cd "C:\Program Files\Microsoft Team Foundation Server 15.0\Search\ES\elasticsearch-2.4.1\bin"
For TFS 2018 Update 2 and above, cd "C:\Program Files\Microsoft Team Foundation Server 15.0\Search\ES\elasticsearch-5.4.1\bin"
3.	Stop the service:
For TFS 2017, execute "service.bat stop"
	For TFS 2018, execute "elasticsearch-service.bat stop"
Step 3: Download and Install Azul Zulu Java OpenJDK 8u192 or Azul Zulu Java OpenJDK 7u201 (Refer table 1 below for correct version)

Step 4: Update JAVA_HOME with Azul Zulu path
 
Step 5: Start Elasticsearch Service
1.	Open Command Prompt as an administrator 
2.	Change directory: 
For TFS 2017 Update 1, cd "C:\Program Files\Microsoft Team Foundation Server 15.0\Search\ES\elasticsearch-2.4.1\bin"
For TFS 2018 Update 2 and above, cd "C:\Program Files\Microsoft Team Foundation Server 15.0\Search\ES\elasticsearch-5.4.1\bin"
3.	Start the service:
For TFS 2017, execute "service.bat start"
	For TFS 2018, execute "elasticsearch-service.bat start"
Step 6: Resume Search indexing
Go to https://github.com/Microsoft/Code-Search and find the right folder based on the TFS version you are using. If you are using TFS 2018 Update3.2, go to https://github.com/Microsoft/Code-Search/tree/master/TFS_2018Update3. If indexing was paused, execute the script ResumeSearchIndexing.ps1 with administrative privileges, to resume indexing again. You will be prompted to enter:
•	The SQL server instance name where the TFS configuration database resides.
•	The name of the TFS configuration database.
Steps for migrating from Oracle JRE to Azul Zulu Java (for TFS 2017 RTW)
Below diagram explains the steps to migrate from Oracle JRE to Azul Zulu OpenJDK for TFS 2017 RTW.
 
Step 1: Pause Search indexing
Go to https://github.com/Microsoft/Code-Search and find the right folder based on the TFS version you are using. For TFS 2017 RTW, go to https://github.com/Microsoft/Code-Search/tree/master/TFS_2017RTW. To pause all indexing, execute the script PauseSearchIndexing.ps1 from Windows PowerShell with administrative privileges.. You will be prompted to enter:
•	The SQL server instance name where the TFS configuration database resides.
•	The name of the TFS configuration database.
Step 2: Remove Elasticsearch Service
4.	Open Command Prompt as an administrator 
5.	Change directory: 
For TFS 2017 RTM, cd "C:\Program Files\Microsoft Team Foundation Server 15.0\Search\ES\elasticsearch-1.7.1-SNAPSHOT\bin"
6.	Stop the service:
For TFS 2017, execute "service.bat remove"
Step 3: Download and Install Azul Zulu Java OpenJDK 7u201

Step 4: Update JAVA_HOME with Azul Zulu path
 
Step 5: Install Elasticsearch Service
4.	Open Command Prompt as an administrator 
5.	Change directory: 
For TFS 2017 RTM, cd "C:\Program Files\Microsoft Team Foundation Server 15.0\Search\ES\elasticsearch-1.7.1-SNAPSHOT\bin"
6.	Start the service:
For TFS 2017, execute "service.bat install"
Step 6: Resume Search indexing
Go to https://github.com/Microsoft/Code-Search and find the right folder based on the TFS version you are using. For TFS 2017 RTW, go to https://github.com/Microsoft/Code-Search/tree/master/TFS_2017RTW. If indexing was paused, execute the script ResumeSearchIndexing.ps1 with administrative privileges, to resume indexing again. You will be prompted to enter:
•	The SQL server instance name where the TFS configuration database resides.
•	The name of the TFS configuration database.
Below table captures version of Azul Zulu OpenJDK required based on the TFS version. 
TFS version	Elasticsearch version	Oracle JRE Version 	Azul Zulu OpenJDK Version to be used
TFS 2019 RTW, TFS 2019 RC2, TFS 2018 Update 3.2, TFS 2018 Update 2	5.x	JRE 8 Update 60 or higher	Azul Zulu Java OpenJDK 8u192
TFS 2018 Update 1.1, TFS 2018 RTM, TFS 2017 Update 3, TFS 2017 Update 2, TFS 2017 Update 1	2.x	JRE 7 Update 55 or higher OR 
JRE 8 Update 20 or higher	Azul Zulu Java OpenJDK 8u192 
or Azul Zulu Java OpenJDK 7u201

TFS 2017 RTM	1.7x	JRE 7 Update 20 or higher	Azul Zulu Java OpenJDK 7u201
Table 1: Azul Zulu OpenJDK TFS Search compatibility table

Option 2: Continue Oracle JRE 8 and buy a commercial license
If users choose to continue with Oracle JRE, they can buy a commercial Oracle license and they will continue to get free updates to JRE 8 from Oracle under the BCL license until Mar 2025 and free updates to JRE 7 from Oracle until 2022. 
 
What will be the experience for users planning to use TFS 2019 RTW and onward?
For TFS 2019 RTW and onward Search configuration experience, Java auto install experience from Oracle Java will be replaced Azul Zulu OpenJDK. Today Java configuration in TFS Search installation wizard looks like the image below.


In TFS 2019 RTW and onward, after users have agreed to Azul Zulu Terms of Use, we will download and install Azul Zulu OpenJDK 8 instead of Oracle JRE 8. Note that users are free to have either Oracle JRE 8 (Update 60 or higher) or Azul Zulu OpenJDK 8 (Update 60 or higher) to have TFS search running normally. While TFS Search will work with both Oracle JRE and Azul Zulu OpenJDK, TFS Search configuration wizard will ONLY install Azul Zulu OpenJDK on user’s behalf when Java is not detected on user machine. Below image captures TFS Search Java auto install experience moving forward.
 
You can reach us on Developer Community if you need any further help or have any suggestions.


