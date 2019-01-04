/** This sql script is to update the job definition in config DB for CodeRepairJob to allow override.
-- Any job definition for the same job Id if present in collection db would be used then while running job instead of the one present in config db created via job template.
-- DATABASE : CONFIG DB
**/

-- Update the job definition in Config DB to allow override of job definition in collection DB
BEGIN TRAN

DECLARE @codeRepairJobId uniqueidentifier = 'C1F3C994-3C3A-4AC5-8A21-CDB6B5FC8EE8'
DECLARE @changeGuid uniqueidentifier = '3DB2CC86-FEE2-40E8-8C6A-7856983A1069'
DECLARE @newSequenceId BIGINT
EXEC prc_iCounterGetNext @partitionId = 1, @counterName = N'JobTemplate',
                                   @countToReserve = 1,
                                   @firstIdToUse = @newSequenceId OUTPUT

update JobService.tbl_JobDefinitionTemplate set Flags = 32, SequenceId = @newSequenceId where JobId = @codeRepairJobId

EXEC prc_iiSendNotification 1, @changeGuid

COMMIT TRAN
