/*
Enable indexing and search on Original content for Code entity
*/

exec prc_SetRegistryValue 1, '#\Service\ALMSearch\Settings\EnableCodeSearchOnOriginalContent\', true

exec prc_SetRegistryValue 1, '#\FeatureAvailability\Entries\Search.Server.IndexOriginalCodeContent\AvailabilityState\', 1

-- Enable workitem tags sorting on the basis of system language
exec prc_SetRegistryValue 1, '#\FeatureAvailability\Entries\WebAccess.Search.WorkItem.EnableTagsSorting\AvailabilityState\', 1
