--This script will disable code indexing for Search.

DECLARE @features dbo.typ_KeyValuePairStringTableNullable

INSERT INTO @features values('#\FeatureAvailability\Entries\Search.Server.Code.Indexing\AvailabilityState\', '0')
EXEC prc_UpdateRegistry @partitionId=1, @identityName = '00000000-0000-0000-0000-000000000000', @registryUpdates = @features
INSERT INTO @features values('#\FeatureAvailability\Entries\Search.Server.Code.CrudOperations\AvailabilityState\', '0')
EXEC prc_UpdateRegistry @partitionId=1, @identityName = '00000000-0000-0000-0000-000000000000', @registryUpdates = @features
