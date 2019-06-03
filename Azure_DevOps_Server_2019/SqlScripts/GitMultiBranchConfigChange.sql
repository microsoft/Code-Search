/*
This script sets the number of branches that can be configured for code search for Git repositories.
This has to be run against COLLECTION DB.
*/

Declare @CollectionId uniqueidentifier = $(CollectionID);
Declare @BranchCount int = $(BranchCountToConfigure);

-- Step1 – Change the reg setting that governs number of Git branches that can configured for code search.
DECLARE @partitionID VARCHAR(50)
SELECT @partitionID = PartitionID FROM [dbo].[tbl_DatabasePartitionMap] WHERE ServiceHostId = @CollectionId

DECLARE @features [dbo].[typ_KeyValuePairStringTableNullable]
INSERT INTO @features values('#\Service\Search\Settings\MaxNumberOfConfigurableBranchesForSearch\', @BranchCount)
EXEC prc_UpdateRegistry @partitionId = @partitionID, @identityName = '00000000-0000-0000-0000-000000000000', @registryUpdates = @features
