DECLARE @drawerId UNIQUEIDENTIFIER, @token NVARCHAR(200), @IdCursor CURSOR, @Id UNIQUEIDENTIFIER
BEGIN
    SELECT @drawerId = drawerId 
    FROM tbl_StrongBoxDrawer 
    WHERE Name = 'ElasticsearchPasswordDrawer' AND PartitionId = 1

    PRINT CONCAT('Drawer = ', @drawerId)

    IF (@drawerId IS NOT NULL)
    BEGIN
        SET @token = CONCAT('StrongBox/', @drawerId, '/')
        SET @IdCursor = CURSOR FOR
        SELECT Id FROM tbl_Group 
        WHERE PartitionId = 1 
        AND Sid LIKE '%-0-0-0-0-3' 
        AND DisplayName = 'Project Collection Valid Users' 
 
        OPEN @IdCursor 
        FETCH NEXT FROM @IdCursor 
        INTO @Id

        WHILE @@FETCH_STATUS = 0
        BEGIN
            PRINT CONCAT('Fixing  security for token: ', @token, ', for TFID: ', @id)
        
            BEGIN TRANSACTION
                EXEC prc_pSetAccessControlEntry2 @partitionId = 1, 
                    @namespaceGuid = '4A9E8381-289A-4DFD-8460-69028EAA93B3',
                    @dataspaceId = 1, 
                    @teamFoundationId = @Id,
                    @securityToken = @token, 
                    @allowPermission=32, 
                    @denyPermission = 0, 
                    @merge = 0, 
                    @separator='/'
            COMMIT TRAN
            FETCH NEXT FROM @IdCursor 
            INTO @Id 
        END
        CLOSE @IdCursor;
        DEALLOCATE @IdCursor;
    END
END