CREATE OR ALTER PROCEDURE EXEC [Config_Oracle].[UpdateWaterMarkSP]
AS
BEGIN
    SET NOCOUNT ON;
 
    DECLARE @Sql NVARCHAR(MAX),
            @Id BIGINT,
            @SilverSchemaName VARCHAR(128),
            @SilverTableName VARCHAR(128),
            @CreatedField VARCHAR(128),
            @UpdatedField VARCHAR(128),
            @NewCreatedValue DATETIME2,
            @NewUpdatedValue DATETIME2;
 
    DROP TABLE IF EXISTS [WH_MetaData].[Config_Oracle].[WaterMarkProcessing];
 
    CREATE TABLE [WH_MetaData].[Config_Oracle].[WaterMarkProcessing] (
        Id BIGINT,
        SilverSchemaName VARCHAR(128),
        SilverTableName VARCHAR(128),
        CreatedWaterMarkField VARCHAR(128),
        UpdatedWaterMarkField VARCHAR(128)
    );
 
    INSERT INTO [WH_MetaData].[Config_Oracle].[WaterMarkProcessing]
        (Id, SilverSchemaName, SilverTableName, CreatedWaterMarkField, UpdatedWaterMarkField)
    SELECT
        Id,
        SilverSchemaName,
        SilverTableName,
        CreatedWaterMarkField,
        UpdatedWaterMarkField
    FROM [WH_MetaData].[Config_Oracle].[IncrementalConfigETL]
    WHERE IsFullLoad = 0
      AND IsActive = 1
      AND (CreatedWaterMarkField IS NOT NULL AND CreatedWaterMarkField <> '1')  
      OR (UpdatedWaterMarkField IS NOT NULL AND UpdatedWaterMarkField <> '1');
 
    PRINT 'Total tables to process: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
 
    WHILE EXISTS (SELECT 1 FROM [WH_MetaData].[Config_Oracle].[WaterMarkProcessing])
    BEGIN
        SELECT TOP 1
            @Id = Id,
            @SilverSchemaName = SilverSchemaName,
            @SilverTableName = SilverTableName,
            @CreatedField = CreatedWaterMarkField,
            @UpdatedField = UpdatedWaterMarkField
        FROM [WH_MetaData].[Config_Oracle].[WaterMarkProcessing];
 
        PRINT 'Processing Id: ' + CAST(@Id AS VARCHAR(10)) +
              ' | Table: ' + ISNULL(@SilverSchemaName,'') + '.' + ISNULL(@SilverTableName,'');
 
        SET @NewCreatedValue = NULL;
        SET @NewUpdatedValue = NULL;
 
        BEGIN TRY
            -- Only Created
            IF @CreatedField IS NOT NULL AND @CreatedField <> '1'
               AND ISNULL(@UpdatedField, '') IN ('', '1')
            BEGIN
                SET @Sql = N'SELECT @NewCreatedValue = MAX(' + QUOTENAME(@CreatedField) + ')
                             FROM LH_Silver.' + QUOTENAME(@SilverSchemaName) + '.' + QUOTENAME(@SilverTableName);
                EXEC sp_executesql @Sql, N'@NewCreatedValue DATETIME2 OUTPUT', @NewCreatedValue OUTPUT;
            END
            -- Only Updated
            ELSE IF @UpdatedField IS NOT NULL AND @UpdatedField <> '1'
                    AND ISNULL(@CreatedField, '') IN ('', '1')
            BEGIN
                SET @Sql = N'SELECT @NewUpdatedValue = MAX(' + QUOTENAME(@UpdatedField) + ')
                             FROM LH_Silver.' + QUOTENAME(@SilverSchemaName) + '.' + QUOTENAME(@SilverTableName);
                EXEC sp_executesql @Sql, N'@NewUpdatedValue DATETIME2 OUTPUT', @NewUpdatedValue OUTPUT;
            END
            -- Both
            ELSE IF @CreatedField IS NOT NULL AND @CreatedField <> '1'
                    AND @UpdatedField IS NOT NULL AND @UpdatedField <> '1'
            BEGIN
                SET @Sql = N'SELECT
                                @NewCreatedValue = MAX(' + QUOTENAME(@CreatedField) + '),
                                @NewUpdatedValue = MAX(' + QUOTENAME(@UpdatedField) + ')
                             FROM LH_Silver.' + QUOTENAME(@SilverSchemaName) + '.' + QUOTENAME(@SilverTableName);
                EXEC sp_executesql @Sql,
                    N'@NewCreatedValue DATETIME2 OUTPUT, @NewUpdatedValue DATETIME2 OUTPUT',
                    @NewCreatedValue OUTPUT, @NewUpdatedValue OUTPUT;
            END
 
            UPDATE [WH_MetaData].[Config_Oracle].[IncrementalConfigETL]
            SET
                CreatedWaterMarkValue = @NewCreatedValue,
                UpdatedWaterMarkValue = @NewUpdatedValue,
                LastModifiedDate = SYSUTCDATETIME()
            WHERE Id = @Id;
 
            PRINT 'SUCCESS - Id ' + CAST(@Id AS VARCHAR(10));
 
        END TRY
        BEGIN CATCH
            PRINT 'FAILED - Id ' + CAST(@Id AS VARCHAR(10)) + ' | Error: ' + ERROR_MESSAGE();
        END CATCH
 
        DELETE FROM [WH_MetaData].[Config_Oracle].[WaterMarkProcessing] WHERE Id = @Id;
    END
 
    DROP TABLE IF EXISTS [WH_MetaData].[Config_Oracle].[WaterMarkProcessing];
    PRINT 'Watermark Update Process Completed Successfully.';
 
END
