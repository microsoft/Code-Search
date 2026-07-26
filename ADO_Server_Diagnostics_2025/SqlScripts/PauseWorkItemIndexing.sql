--This script will disable work item indexing for Search.

DECLARE @features dbo.typ_KeyValuePairStringTableNullable

INSERT INTO @features values('#\FeatureAvailability\Entries\Search.Server.WorkItem.Indexing\AvailabilityState\', '0')
EXEC prc_UpdateRegistry @partitionId=1, @identityName = '00000000-0000-0000-0000-000000000000', @registryUpdates = @features
INSERT INTO @features values('#\FeatureAvailability\Entries\Search.Server.WorkItem.CrudOperations\AvailabilityState\', '0')
EXEC prc_UpdateRegistry @partitionId=1, @identityName = '00000000-0000-0000-0000-000000000000', @registryUpdates = @features
