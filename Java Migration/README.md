## Steps for migrating to Azul Zulu OpenJDK from Oracle JRE

Oracle Java SE 8 is undergoing the “End of Public Updates” process, which means there will be no longer free updates to JRE (Java Runtime Environment) for commercial use after January 2019. This has an impact on Team Foundation Server Search feature (Code, Work Item and Wiki) users because existing TFS versions including the latest version TFS 2018 Update 3.2 have dependencies on Elasticsearch versions 5.4.1 or less, which in turn have a dependency either on Oracle Java JRE 8 or JRE 7.

Below diagram captures the overall flow of steps invloved in migrating to Azul Zulu OpenJDK from Oracle JRE. 
![Migration Flow](https://github.com/msftazdev/Code-Search/blob/msftazdev-patch-1/Java%20Migration/flow1.png)

Based on the version of TFS that you are using, please select the appropriate option below to proceed. 




