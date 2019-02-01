## Steps for migrating to Azul Zulu OpenJDK from Oracle JRE

The search feature of Team Foundation Server (TFS) uses Elasticsearch, which depends on Java SE. Until now  , Oracle Java SE was the supported version of JRE for TFS search. With the change in Oracle licensing terms, [there will be no more “free public Java updates”](https://www.oracle.com/technetwork/java/java-se-support-roadmap.html) and users are required to buy a subscription to continue to get JRE updates for commercial use. TFS Search will support both Azul Zulu OpenJDK and Oracle JRE, allowing you to choose between them based on your needs. 

Note that while users with Oracle Java subscription will get automatic updates, Azul Zulu OpenJDK community version is a volunteer driven effort with no dedicated commercial support and updates. If you require dedicated commercial support to Azul Zulu OpenJDK, please contact Azul for more details on [Zulu Enterprise](https://www.azul.com/products/zulu-and-zulu-enterprise/zulu-enterprise-java-support-options/). 


Below diagram captures the overall flow of steps invloved in migrating to Azul Zulu OpenJDK from Oracle JRE. 
![Migration Flow](https://github.com/msftazdev/Code-Search/blob/msftazdev-patch-1/Java%20Migration/flow1.png)

Based on the version of TFS that you are using, please select an appropriate option below to proceed. 

[TFS 2017 RTW](TFS_2017%20RTW.md)

[TFS 2017 Update 1](TFS_2017Update1.md)

[TFS 2017 Update 2](TFS_2017Update2.md)

[TFS 2017 Update 3](TFS_2017Update3.md)

[TFS 2018 RTW](TFS_2018RTW.md)

[TFS 2018 Update 1](TFS_2018Update1.md)

[TFS 2018 Update 2](TFS_2018Update2.md)

[TFS 2018 Update 3](TFS_2018Update3.md)

[Azure DevOps Server 2019](Azure_DevOps_Server_2019.md)

