------------------------------------------------------------
-- Global Variable Declarations
------------------------------------------------------------
DECLARE @WarehouseName     VARCHAR(MAX) = 'WH_VIRGINIA';
DECLARE @StageSchemaName   VARCHAR(MAX) = 'dbo';
DECLARE @TargetSchemaName  VARCHAR(MAX) = 'VIRGINIA';

DECLARE @StartTime         DATETIME2(6);
DECLARE @InsertedRows      BIGINT;
DECLARE @UpdatedRows       BIGINT;
DECLARE @SrcFQN            NVARCHAR(500);
DECLARE @TgtFQN            NVARCHAR(500);
DECLARE @TgtObjectId       NVARCHAR(500);
DECLARE @SQL               NVARCHAR(MAX);
DECLARE @TableExists       BIT;

-- Temporary table to collect execution logs across all tables
IF OBJECT_ID('tempdb..#Logs', 'U') IS NOT NULL
    DROP TABLE #Logs;

CREATE TABLE #Logs (
    TableName       VARCHAR(200),
    StartTime       DATETIME2(6),
    EndTime         DATETIME2(6),
    RowsAffected    BIGINT,
    Status          VARCHAR(20),
    ErrorMessage    VARCHAR(4000)
);

------------------------------------------------------------
-- 1. T_DW_ACCESS_CONTROL
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;

-- Fully-qualified, safely-quoted object names built from parameters
SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' + QUOTENAME(@StageSchemaName) + '.' + QUOTENAME('T_DW_ACCESS_CONTROL');
SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' + QUOTENAME('T_DW_ACCESS_CONTROL');
SET @TgtObjectId = @TargetSchemaName + '.' + 'T_DW_ACCESS_CONTROL';

BEGIN TRY

    

    IF OBJECT_ID(@TgtObjectId, 'U') IS NULL
    BEGIN
        -- Target table does not exist: create it directly from staging
        SET @SQL = N'
            SELECT
                CAST(src.ACCESS_PARTY_ID AS INT)              AS ACCESS_PARTY_ID,
                CAST(src.ACCESS_CONTROL_ID AS INT)             AS ACCESS_CONTROL_ID,
                CAST(src.PLAN_KEY AS INT)                      AS PLAN_KEY,
                CAST(src.ACCESS_END_DATE AS DATETIME2(6))      AS ACCESS_END_DATE,
                CAST(src.ACCESS_START_DATE AS DATETIME2(6))    AS ACCESS_START_DATE,
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM,
                CAST(src.TRAUNCH_ID AS VARCHAR(MAX))           AS TRAUNCH_ID,
                CAST(src.ACTIVE_RECORD_IND AS VARCHAR(MAX))    AS ACTIVE_RECORD_IND
            INTO ' + @TgtFQN + N'
            FROM ' + @SrcFQN + N' AS src;';

        EXEC sp_executesql @SQL;
        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN
        -- Target table exists: perform standard UPDATE + INSERT (upsert)
        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.ACCESS_PARTY_ID    = CAST(src.ACCESS_PARTY_ID AS INT),
                tgt.PLAN_KEY           = CAST(src.PLAN_KEY AS INT),
                tgt.ACCESS_END_DATE    = CAST(src.ACCESS_END_DATE AS DATETIME2(6)),
                tgt.ACCESS_START_DATE  = CAST(src.ACCESS_START_DATE AS DATETIME2(6)),
                tgt.DW_UPD_DTTM        = src.DW_UPD_DTTM,
                tgt.DW_INS_DTTM        = src.DW_INS_DTTM,
                tgt.TRAUNCH_ID         = CAST(src.TRAUNCH_ID AS VARCHAR(MAX)),
                tgt.ACTIVE_RECORD_IND  = CAST(src.ACTIVE_RECORD_IND AS VARCHAR(MAX))
            FROM ' + @TgtFQN + N' AS tgt
            INNER JOIN ' + @SrcFQN + N' AS src
                ON tgt.ACCESS_CONTROL_ID = CAST(src.ACCESS_CONTROL_ID AS INT);';

        EXEC sp_executesql @SQL;
        SET @UpdatedRows = @@ROWCOUNT;

        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + N'
            (
                ACCESS_PARTY_ID, ACCESS_CONTROL_ID, PLAN_KEY, ACCESS_END_DATE,
                ACCESS_START_DATE, DW_UPD_DTTM, DW_INS_DTTM, TRAUNCH_ID, ACTIVE_RECORD_IND
            )
            SELECT
                CAST(src.ACCESS_PARTY_ID AS INT),
                CAST(src.ACCESS_CONTROL_ID AS INT),
                CAST(src.PLAN_KEY AS INT),
                CAST(src.ACCESS_END_DATE AS DATETIME2(6)),
                CAST(src.ACCESS_START_DATE AS DATETIME2(6)),
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM,
                CAST(src.TRAUNCH_ID AS VARCHAR(MAX)),
                CAST(src.ACTIVE_RECORD_IND AS VARCHAR(MAX))
            FROM ' + @SrcFQN + N' AS src
            WHERE NOT EXISTS (
                SELECT 1 FROM ' + @TgtFQN + N' AS tgt
                WHERE tgt.ACCESS_CONTROL_ID = CAST(src.ACCESS_CONTROL_ID AS INT)
            );';

        EXEC sp_executesql @SQL;
        SET @InsertedRows = @@ROWCOUNT;
    END

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 2. T_DW_ACCESS_PARTY
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;

SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' + QUOTENAME(@StageSchemaName) + '.' + QUOTENAME('T_DW_ACCESS_PARTY');
SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' + QUOTENAME('T_DW_ACCESS_PARTY');
SET @TgtObjectId = @TargetSchemaName + '.' + 'T_DW_ACCESS_PARTY';

BEGIN TRY

    

    IF OBJECT_ID(@TgtObjectId, 'U') IS NULL
    BEGIN
        SET @SQL = N'
            SELECT
                CAST(src.PARENT_DW_ACCESS_PARTY_ID AS INT)  AS PARENT_DW_ACCESS_PARTY_ID,
                CAST(src.ACCESS_PARTY_ID AS INT)             AS ACCESS_PARTY_ID,
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM,
                CAST(src.ACCESS_PARTY_NAME AS VARCHAR(MAX))  AS ACCESS_PARTY_NAME,
                CAST(src.ACCESS_PARTY_TYPE AS VARCHAR(MAX))  AS ACCESS_PARTY_TYPE,
                CAST(src.ACTIVE_RECORD_IND AS VARCHAR(MAX))  AS ACTIVE_RECORD_IND
            INTO ' + @TgtFQN + N'
            FROM ' + @SrcFQN + N' AS src;';

        EXEC sp_executesql @SQL;
        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN
        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.PARENT_DW_ACCESS_PARTY_ID = CAST(src.PARENT_DW_ACCESS_PARTY_ID AS INT),
                tgt.DW_UPD_DTTM                = src.DW_UPD_DTTM,
                tgt.DW_INS_DTTM                = src.DW_INS_DTTM,
                tgt.ACCESS_PARTY_NAME          = CAST(src.ACCESS_PARTY_NAME AS VARCHAR(MAX)),
                tgt.ACCESS_PARTY_TYPE          = CAST(src.ACCESS_PARTY_TYPE AS VARCHAR(MAX)),
                tgt.ACTIVE_RECORD_IND          = CAST(src.ACTIVE_RECORD_IND AS VARCHAR(MAX))
            FROM ' + @TgtFQN + N' AS tgt
            INNER JOIN ' + @SrcFQN + N' AS src
                ON tgt.ACCESS_PARTY_ID = CAST(src.ACCESS_PARTY_ID AS INT);';

        EXEC sp_executesql @SQL;
        SET @UpdatedRows = @@ROWCOUNT;

        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + N'
            (
                PARENT_DW_ACCESS_PARTY_ID, ACCESS_PARTY_ID, DW_UPD_DTTM, DW_INS_DTTM,
                ACCESS_PARTY_NAME, ACCESS_PARTY_TYPE, ACTIVE_RECORD_IND
            )
            SELECT
                CAST(src.PARENT_DW_ACCESS_PARTY_ID AS INT),
                CAST(src.ACCESS_PARTY_ID AS INT),
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM,
                CAST(src.ACCESS_PARTY_NAME AS VARCHAR(MAX)),
                CAST(src.ACCESS_PARTY_TYPE AS VARCHAR(MAX)),
                CAST(src.ACTIVE_RECORD_IND AS VARCHAR(MAX))
            FROM ' + @SrcFQN + N' AS src
            WHERE NOT EXISTS (
                SELECT 1 FROM ' + @TgtFQN + N' AS tgt
                WHERE tgt.ACCESS_PARTY_ID = CAST(src.ACCESS_PARTY_ID AS INT)
            );';

        EXEC sp_executesql @SQL;
        SET @InsertedRows = @@ROWCOUNT;
    END

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 3. T_D_AGE
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;

SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' + QUOTENAME(@StageSchemaName) + '.' + QUOTENAME('T_D_AGE');
SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' + QUOTENAME('T_D_AGE');
SET @TgtObjectId = @TargetSchemaName + '.' + 'T_D_AGE';

BEGIN TRY

    

    IF OBJECT_ID(@TgtObjectId, 'U') IS NULL
    BEGIN
        SET @SQL = N'
            SELECT
                CAST(src.AGE AS INT)                       AS AGE,
                CAST(src.AGE_KEY AS INT)                   AS AGE_KEY,
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX))     AS DW_CHANGE_ID,
                CAST(src.AGE_BAND_2 AS VARCHAR(MAX))       AS AGE_BAND_2,
                CAST(src.AGE_BAND_1 AS VARCHAR(MAX))       AS AGE_BAND_1,
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM
            INTO ' + @TgtFQN + N'
            FROM ' + @SrcFQN + N' AS src;';

        EXEC sp_executesql @SQL;
        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN
        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.DW_CHANGE_ID = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                tgt.AGE_BAND_2   = CAST(src.AGE_BAND_2 AS VARCHAR(MAX)),
                tgt.AGE_BAND_1   = CAST(src.AGE_BAND_1 AS VARCHAR(MAX)),
                tgt.DW_UPD_DTTM  = src.DW_UPD_DTTM,
                tgt.DW_INS_DTTM  = src.DW_INS_DTTM
            FROM ' + @TgtFQN + N' AS tgt
            INNER JOIN ' + @SrcFQN + N' AS src
                ON tgt.AGE_KEY = CAST(src.AGE_KEY AS INT);';

        EXEC sp_executesql @SQL;
        SET @UpdatedRows = @@ROWCOUNT;

        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + N'
            (
                AGE, AGE_KEY, DW_CHANGE_ID, AGE_BAND_2, AGE_BAND_1, DW_UPD_DTTM, DW_INS_DTTM
            )
            SELECT
                CAST(src.AGE AS INT),
                CAST(src.AGE_KEY AS INT),
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                CAST(src.AGE_BAND_2 AS VARCHAR(MAX)),
                CAST(src.AGE_BAND_1 AS VARCHAR(MAX)),
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM
            FROM ' + @SrcFQN + N' AS src
            WHERE NOT EXISTS (
                SELECT 1 FROM ' + @TgtFQN + N' AS tgt
                WHERE tgt.AGE_KEY = CAST(src.AGE_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;
        SET @InsertedRows = @@ROWCOUNT;
    END

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 4. T_D_AO_AGE
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;

SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' + QUOTENAME(@StageSchemaName) + '.' + QUOTENAME('T_D_AO_AGE');
SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' + QUOTENAME('T_D_AO_AGE');
SET @TgtObjectId = @TargetSchemaName + '.' + 'T_D_AO_AGE';

BEGIN TRY

    

    IF OBJECT_ID(@TgtObjectId, 'U') IS NULL
    BEGIN
        SET @SQL = N'
            SELECT
                CAST(src.AGE AS INT)                       AS AGE,
                CAST(src.AGE_KEY AS INT)                   AS AGE_KEY,
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX))     AS DW_CHANGE_ID,
                CAST(src.AGE_BAND_2 AS VARCHAR(MAX))       AS AGE_BAND_2,
                CAST(src.AGE_BAND_1 AS VARCHAR(MAX))       AS AGE_BAND_1,
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM
            INTO ' + @TgtFQN + N'
            FROM ' + @SrcFQN + N' AS src;';

        EXEC sp_executesql @SQL;
        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN
        -- Update existing rows
        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.DW_CHANGE_ID = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                tgt.AGE_BAND_2   = CAST(src.AGE_BAND_2 AS VARCHAR(MAX)),
                tgt.AGE_BAND_1   = CAST(src.AGE_BAND_1 AS VARCHAR(MAX)),
                tgt.DW_UPD_DTTM  = src.DW_UPD_DTTM,
                tgt.DW_INS_DTTM  = src.DW_INS_DTTM
            FROM ' + @TgtFQN + N' AS tgt
            INNER JOIN ' + @SrcFQN + N' AS src
                ON tgt.AGE_KEY = CAST(src.AGE_KEY AS INT);';

        EXEC sp_executesql @SQL;
        SET @UpdatedRows = @@ROWCOUNT;

        -- Insert new rows
        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + N'
            (
                AGE,
                AGE_KEY,
                DW_CHANGE_ID,
                AGE_BAND_2,
                AGE_BAND_1,
                DW_UPD_DTTM,
                DW_INS_DTTM
            )
            SELECT
                CAST(src.AGE AS INT),
                CAST(src.AGE_KEY AS INT),
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                CAST(src.AGE_BAND_2 AS VARCHAR(MAX)),
                CAST(src.AGE_BAND_1 AS VARCHAR(MAX)),
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM
            FROM ' + @SrcFQN + N' AS src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + N' AS tgt
                WHERE tgt.AGE_KEY = CAST(src.AGE_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;
        SET @InsertedRows = @@ROWCOUNT;
    END;

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 5. T_D_BENE_AGE
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;

-- Fully-qualified object names
SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' + QUOTENAME(@StageSchemaName) + '.' + QUOTENAME('T_D_BENE_AGE');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' + QUOTENAME('T_D_BENE_AGE');

SET @TgtObjectId = @TargetSchemaName + '.T_D_BENE_AGE';

BEGIN TRY

    

    IF OBJECT_ID(@TgtObjectId, 'U') IS NULL
    BEGIN
        SET @SQL = N'
            SELECT
                CAST(src.AGE AS INT)                       AS AGE,
                CAST(src.AGE_KEY AS INT)                   AS AGE_KEY,
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX))     AS DW_CHANGE_ID,
                CAST(src.AGE_BAND_2 AS VARCHAR(MAX))       AS AGE_BAND_2,
                CAST(src.AGE_BAND_1 AS VARCHAR(MAX))       AS AGE_BAND_1,
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM
            INTO ' + @TgtFQN + N'
            FROM ' + @SrcFQN + N' AS src;';

        EXEC sp_executesql @SQL;
        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN
        -- Update existing rows
        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.DW_CHANGE_ID = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                tgt.AGE_BAND_2   = CAST(src.AGE_BAND_2 AS VARCHAR(MAX)),
                tgt.AGE_BAND_1   = CAST(src.AGE_BAND_1 AS VARCHAR(MAX)),
                tgt.DW_UPD_DTTM  = src.DW_UPD_DTTM,
                tgt.DW_INS_DTTM  = src.DW_INS_DTTM
            FROM ' + @TgtFQN + N' AS tgt
            INNER JOIN ' + @SrcFQN + N' AS src
                ON tgt.AGE_KEY = CAST(src.AGE_KEY AS INT);';

        EXEC sp_executesql @SQL;
        SET @UpdatedRows = @@ROWCOUNT;

        -- Insert new rows
        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + N'
            (
                AGE,
                AGE_KEY,
                DW_CHANGE_ID,
                AGE_BAND_2,
                AGE_BAND_1,
                DW_UPD_DTTM,
                DW_INS_DTTM
            )
            SELECT
                CAST(src.AGE AS INT),
                CAST(src.AGE_KEY AS INT),
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                CAST(src.AGE_BAND_2 AS VARCHAR(MAX)),
                CAST(src.AGE_BAND_1 AS VARCHAR(MAX)),
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM
            FROM ' + @SrcFQN + N' AS src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + N' AS tgt
                WHERE tgt.AGE_KEY = CAST(src.AGE_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;
        SET @InsertedRows = @@ROWCOUNT;
    END;

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 6. T_D_BRANCH
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;

-- Fully-qualified, safely-quoted object names built from parameters
SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' + QUOTENAME(@StageSchemaName) + '.' + QUOTENAME('T_D_BRANCH');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' + QUOTENAME('T_D_BRANCH');

SET @TgtObjectId = @TargetSchemaName + '.T_D_BRANCH';

BEGIN TRY

    

    IF OBJECT_ID(@TgtObjectId, 'U') IS NULL
    BEGIN
        -- Target table does not exist: create it directly from staging
        SET @SQL = N'
            SELECT
                CAST(src.BRANCH_KEY AS INT)                       AS BRANCH_KEY,
                CAST(src.SEQ_BRANCH_ID AS INT)                    AS SEQ_BRANCH_ID,
                CAST(src.SC_OFFICE_ID AS VARCHAR(MAX))            AS SC_OFFICE_ID,
                CAST(src.BRANCH_NAME AS VARCHAR(MAX))             AS BRANCH_NAME,
                CAST(src.BRANCH_TRADING_ID AS VARCHAR(MAX))       AS BRANCH_TRADING_ID,
                CAST(src.BRANCH_ADDLINE1 AS VARCHAR(MAX))         AS BRANCH_ADDLINE1,
                CAST(src.BRANCH_ADDLINE2 AS VARCHAR(MAX))         AS BRANCH_ADDLINE2,
                CAST(src.BRANCH_ADDLINE3 AS VARCHAR(MAX))         AS BRANCH_ADDLINE3,
                CAST(src.BRANCH_ADDLINE4 AS VARCHAR(MAX))         AS BRANCH_ADDLINE4,
                CAST(src.BRANCH_CITY AS VARCHAR(MAX))             AS BRANCH_CITY,
                CAST(src.BRANCH_STATE AS VARCHAR(MAX))            AS BRANCH_STATE,
                CAST(src.BRANCH_ZIPCODE AS VARCHAR(MAX))          AS BRANCH_ZIPCODE,
                CAST(src.BRANCH_PHONE AS VARCHAR(MAX))            AS BRANCH_PHONE,
                CAST(src.TLM AS DATETIME2(6))                     AS TLM,
                CAST(src.ACTIVE_FLAG AS CHAR(1))                  AS ACTIVE_FLAG,
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX))            AS DW_CHANGE_ID,
                CAST(src.DEALER_TRADING_ID AS VARCHAR(MAX))       AS DEALER_TRADING_ID
            INTO ' + @TgtFQN + N'
            FROM ' + @SrcFQN + N' AS src;';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN
        -- Update existing records
        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.SEQ_BRANCH_ID       = CAST(src.SEQ_BRANCH_ID AS INT),
                tgt.SC_OFFICE_ID        = CAST(src.SC_OFFICE_ID AS VARCHAR(MAX)),
                tgt.BRANCH_NAME         = CAST(src.BRANCH_NAME AS VARCHAR(MAX)),
                tgt.BRANCH_TRADING_ID   = CAST(src.BRANCH_TRADING_ID AS VARCHAR(MAX)),
                tgt.BRANCH_ADDLINE1     = CAST(src.BRANCH_ADDLINE1 AS VARCHAR(MAX)),
                tgt.BRANCH_ADDLINE2     = CAST(src.BRANCH_ADDLINE2 AS VARCHAR(MAX)),
                tgt.BRANCH_ADDLINE3     = CAST(src.BRANCH_ADDLINE3 AS VARCHAR(MAX)),
                tgt.BRANCH_ADDLINE4     = CAST(src.BRANCH_ADDLINE4 AS VARCHAR(MAX)),
                tgt.BRANCH_CITY         = CAST(src.BRANCH_CITY AS VARCHAR(MAX)),
                tgt.BRANCH_STATE        = CAST(src.BRANCH_STATE AS VARCHAR(MAX)),
                tgt.BRANCH_ZIPCODE      = CAST(src.BRANCH_ZIPCODE AS VARCHAR(MAX)),
                tgt.BRANCH_PHONE        = CAST(src.BRANCH_PHONE AS VARCHAR(MAX)),
                tgt.TLM                 = CAST(src.TLM AS DATETIME2(6)),
                tgt.ACTIVE_FLAG         = CAST(src.ACTIVE_FLAG AS CHAR(1)),
                tgt.DW_CHANGE_ID        = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                tgt.DEALER_TRADING_ID   = CAST(src.DEALER_TRADING_ID AS VARCHAR(MAX))
            FROM ' + @TgtFQN + N' AS tgt
            INNER JOIN ' + @SrcFQN + N' AS src
                ON tgt.BRANCH_KEY = CAST(src.BRANCH_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        -- Insert new records
        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + N'
            (
                BRANCH_KEY,
                SEQ_BRANCH_ID,
                SC_OFFICE_ID,
                BRANCH_NAME,
                BRANCH_TRADING_ID,
                BRANCH_ADDLINE1,
                BRANCH_ADDLINE2,
                BRANCH_ADDLINE3,
                BRANCH_ADDLINE4,
                BRANCH_CITY,
                BRANCH_STATE,
                BRANCH_ZIPCODE,
                BRANCH_PHONE,
                TLM,
                ACTIVE_FLAG,
                DW_CHANGE_ID,
                DEALER_TRADING_ID
            )
            SELECT
                CAST(src.BRANCH_KEY AS INT),
                CAST(src.SEQ_BRANCH_ID AS INT),
                CAST(src.SC_OFFICE_ID AS VARCHAR(MAX)),
                CAST(src.BRANCH_NAME AS VARCHAR(MAX)),
                CAST(src.BRANCH_TRADING_ID AS VARCHAR(MAX)),
                CAST(src.BRANCH_ADDLINE1 AS VARCHAR(MAX)),
                CAST(src.BRANCH_ADDLINE2 AS VARCHAR(MAX)),
                CAST(src.BRANCH_ADDLINE3 AS VARCHAR(MAX)),
                CAST(src.BRANCH_ADDLINE4 AS VARCHAR(MAX)),
                CAST(src.BRANCH_CITY AS VARCHAR(MAX)),
                CAST(src.BRANCH_STATE AS VARCHAR(MAX)),
                CAST(src.BRANCH_ZIPCODE AS VARCHAR(MAX)),
                CAST(src.BRANCH_PHONE AS VARCHAR(MAX)),
                CAST(src.TLM AS DATETIME2(6)),
                CAST(src.ACTIVE_FLAG AS CHAR(1)),
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                CAST(src.DEALER_TRADING_ID AS VARCHAR(MAX))
            FROM ' + @SrcFQN + N' AS src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + N' AS tgt
                WHERE tgt.BRANCH_KEY = CAST(src.BRANCH_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END;

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 7. T_D_CSR
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;

-- Fully-qualified, safely-quoted object names built from parameters
SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' + QUOTENAME(@StageSchemaName) + '.' + QUOTENAME('T_D_CSR');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' + QUOTENAME('T_D_CSR');

SET @TgtObjectId = @TargetSchemaName + '.T_D_CSR';

BEGIN TRY

    

    IF OBJECT_ID(@TgtObjectId, 'U') IS NULL
    BEGIN
        -- Target table does not exist: create it directly from staging
        SET @SQL = N'
            SELECT
                CAST(src.CSR_KEY AS INT)                          AS CSR_KEY,
                CAST(src.TLM AS DATETIME2(6))                     AS TLM,
                CAST(src.CSR_STATUS AS VARCHAR(MAX))              AS CSR_STATUS,
                CAST(src.TEAM_NAME_ID AS VARCHAR(MAX))            AS TEAM_NAME_ID,
                CAST(src.AGENT_ID AS VARCHAR(MAX))                AS AGENT_ID,
                CAST(src.EMAIL AS VARCHAR(MAX))                   AS EMAIL,
                CAST(src.TEAM_NAME AS VARCHAR(MAX))               AS TEAM_NAME,
                CAST(src.CSR_LOCATION AS VARCHAR(MAX))            AS CSR_LOCATION,
                CAST(src.FULL_NAME AS VARCHAR(MAX))               AS FULL_NAME,
                CAST(src.LAST_NAME AS VARCHAR(MAX))               AS LAST_NAME,
                CAST(src.FIRST_NAME AS VARCHAR(MAX))              AS FIRST_NAME,
                CAST(src.USERNAME AS VARCHAR(MAX))                AS USERNAME,
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX))            AS DW_CHANGE_ID,
                CAST(src.COMPANY AS VARCHAR(MAX))                 AS COMPANY,
                CAST(src.AGENT_ACTIVE_FLAG AS VARCHAR(MAX))       AS AGENT_ACTIVE_FLAG,
                CAST(src.CSR_STATUS_CODE AS VARCHAR(MAX))         AS CSR_STATUS_CODE,
                CAST(src.CSR_ID AS INT)                           AS CSR_ID
            INTO ' + @TgtFQN + N'
            FROM ' + @SrcFQN + N' AS src;';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN
        -- Update existing records
        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.TLM                = CAST(src.TLM AS DATETIME2(6)),
                tgt.CSR_STATUS         = CAST(src.CSR_STATUS AS VARCHAR(MAX)),
                tgt.TEAM_NAME_ID       = CAST(src.TEAM_NAME_ID AS VARCHAR(MAX)),
                tgt.AGENT_ID           = CAST(src.AGENT_ID AS VARCHAR(MAX)),
                tgt.EMAIL              = CAST(src.EMAIL AS VARCHAR(MAX)),
                tgt.TEAM_NAME          = CAST(src.TEAM_NAME AS VARCHAR(MAX)),
                tgt.CSR_LOCATION       = CAST(src.CSR_LOCATION AS VARCHAR(MAX)),
                tgt.FULL_NAME          = CAST(src.FULL_NAME AS VARCHAR(MAX)),
                tgt.LAST_NAME          = CAST(src.LAST_NAME AS VARCHAR(MAX)),
                tgt.FIRST_NAME         = CAST(src.FIRST_NAME AS VARCHAR(MAX)),
                tgt.USERNAME           = CAST(src.USERNAME AS VARCHAR(MAX)),
                tgt.DW_CHANGE_ID       = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                tgt.COMPANY            = CAST(src.COMPANY AS VARCHAR(MAX)),
                tgt.AGENT_ACTIVE_FLAG  = CAST(src.AGENT_ACTIVE_FLAG AS VARCHAR(MAX)),
                tgt.CSR_STATUS_CODE    = CAST(src.CSR_STATUS_CODE AS VARCHAR(MAX)),
                tgt.CSR_ID             = CAST(src.CSR_ID AS INT)
            FROM ' + @TgtFQN + N' AS tgt
            INNER JOIN ' + @SrcFQN + N' AS src
                ON tgt.CSR_KEY = CAST(src.CSR_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        -- Insert new records
        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + N'
            (
                CSR_KEY,
                TLM,
                CSR_STATUS,
                TEAM_NAME_ID,
                AGENT_ID,
                EMAIL,
                TEAM_NAME,
                CSR_LOCATION,
                FULL_NAME,
                LAST_NAME,
                FIRST_NAME,
                USERNAME,
                DW_CHANGE_ID,
                COMPANY,
                AGENT_ACTIVE_FLAG,
                CSR_STATUS_CODE,
                CSR_ID
            )
            SELECT
                CAST(src.CSR_KEY AS INT),
                CAST(src.TLM AS DATETIME2(6)),
                CAST(src.CSR_STATUS AS VARCHAR(MAX)),
                CAST(src.TEAM_NAME_ID AS VARCHAR(MAX)),
                CAST(src.AGENT_ID AS VARCHAR(MAX)),
                CAST(src.EMAIL AS VARCHAR(MAX)),
                CAST(src.TEAM_NAME AS VARCHAR(MAX)),
                CAST(src.CSR_LOCATION AS VARCHAR(MAX)),
                CAST(src.FULL_NAME AS VARCHAR(MAX)),
                CAST(src.LAST_NAME AS VARCHAR(MAX)),
                CAST(src.FIRST_NAME AS VARCHAR(MAX)),
                CAST(src.USERNAME AS VARCHAR(MAX)),
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                CAST(src.COMPANY AS VARCHAR(MAX)),
                CAST(src.AGENT_ACTIVE_FLAG AS VARCHAR(MAX)),
                CAST(src.CSR_STATUS_CODE AS VARCHAR(MAX)),
                CAST(src.CSR_ID AS INT)
            FROM ' + @SrcFQN + N' AS src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + N' AS tgt
                WHERE tgt.CSR_KEY = CAST(src.CSR_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END;

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 8. T_D_DEALER
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;

-- Fully-qualified, safely-quoted object names built from parameters
SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' + QUOTENAME(@StageSchemaName) + '.' + QUOTENAME('T_D_DEALER');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' + QUOTENAME('T_D_DEALER');

SET @TgtObjectId = @TargetSchemaName + '.T_D_DEALER';

BEGIN TRY

    

    IF OBJECT_ID(@TgtObjectId, 'U') IS NULL
    BEGIN
        -- Target table does not exist: create it directly from staging
        SET @SQL = N'
            SELECT
                CAST(src.DEALER_KEY AS INT)                       AS DEALER_KEY,
                CAST(src.TLM AS DATETIME2(6))                     AS TLM,
                CAST(src.ACTIVE_FLAG AS CHAR(1))                  AS ACTIVE_FLAG,
                CAST(src.DEALER_CITY AS VARCHAR(MAX))             AS DEALER_CITY,
                CAST(src.DEALER_ADDLINE4 AS VARCHAR(MAX))         AS DEALER_ADDLINE4,
                CAST(src.DEALER_ADDLINE3 AS VARCHAR(MAX))         AS DEALER_ADDLINE3,
                CAST(src.DEALER_ADDLINE2 AS VARCHAR(MAX))         AS DEALER_ADDLINE2,
                CAST(src.DEALER_ADDLINE1 AS VARCHAR(MAX))         AS DEALER_ADDLINE1,
                CAST(src.DEALER_TYPE AS VARCHAR(MAX))             AS DEALER_TYPE,
                CAST(src.DEALER_NAME AS VARCHAR(MAX))             AS DEALER_NAME,
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX))            AS DW_CHANGE_ID,
                CAST(src.DEALER_ZIPCODE AS VARCHAR(MAX))          AS DEALER_ZIPCODE,
                CAST(src.DEALER_STATE AS VARCHAR(MAX))            AS DEALER_STATE,
                CAST(src.DEALER_TRADING_ID AS VARCHAR(MAX))       AS DEALER_TRADING_ID,
                CAST(src.SC_FIRM_ID AS VARCHAR(MAX))              AS SC_FIRM_ID,
                CAST(src.DEALER_TYPE_CODE AS INT)                 AS DEALER_TYPE_CODE,
                CAST(src.SEQ_DEALER_ID AS INT)                    AS SEQ_DEALER_ID
            INTO ' + @TgtFQN + N'
            FROM ' + @SrcFQN + N' AS src;';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN
        -- Update existing records
        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.TLM                 = CAST(src.TLM AS DATETIME2(6)),
                tgt.ACTIVE_FLAG         = CAST(src.ACTIVE_FLAG AS CHAR(1)),
                tgt.DEALER_CITY         = CAST(src.DEALER_CITY AS VARCHAR(MAX)),
                tgt.DEALER_ADDLINE4     = CAST(src.DEALER_ADDLINE4 AS VARCHAR(MAX)),
                tgt.DEALER_ADDLINE3     = CAST(src.DEALER_ADDLINE3 AS VARCHAR(MAX)),
                tgt.DEALER_ADDLINE2     = CAST(src.DEALER_ADDLINE2 AS VARCHAR(MAX)),
                tgt.DEALER_ADDLINE1     = CAST(src.DEALER_ADDLINE1 AS VARCHAR(MAX)),
                tgt.DEALER_TYPE         = CAST(src.DEALER_TYPE AS VARCHAR(MAX)),
                tgt.DEALER_NAME         = CAST(src.DEALER_NAME AS VARCHAR(MAX)),
                tgt.DW_CHANGE_ID        = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                tgt.DEALER_ZIPCODE      = CAST(src.DEALER_ZIPCODE AS VARCHAR(MAX)),
                tgt.DEALER_STATE        = CAST(src.DEALER_STATE AS VARCHAR(MAX)),
                tgt.DEALER_TRADING_ID   = CAST(src.DEALER_TRADING_ID AS VARCHAR(MAX)),
                tgt.SC_FIRM_ID          = CAST(src.SC_FIRM_ID AS VARCHAR(MAX)),
                tgt.DEALER_TYPE_CODE    = CAST(src.DEALER_TYPE_CODE AS INT),
                tgt.SEQ_DEALER_ID       = CAST(src.SEQ_DEALER_ID AS INT)
            FROM ' + @TgtFQN + N' AS tgt
            INNER JOIN ' + @SrcFQN + N' AS src
                ON tgt.DEALER_KEY = CAST(src.DEALER_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        -- Insert new records
        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + N'
            (
                DEALER_KEY,
                TLM,
                ACTIVE_FLAG,
                DEALER_CITY,
                DEALER_ADDLINE4,
                DEALER_ADDLINE3,
                DEALER_ADDLINE2,
                DEALER_ADDLINE1,
                DEALER_TYPE,
                DEALER_NAME,
                DW_CHANGE_ID,
                DEALER_ZIPCODE,
                DEALER_STATE,
                DEALER_TRADING_ID,
                SC_FIRM_ID,
                DEALER_TYPE_CODE,
                SEQ_DEALER_ID
            )
            SELECT
                CAST(src.DEALER_KEY AS INT),
                CAST(src.TLM AS DATETIME2(6)),
                CAST(src.ACTIVE_FLAG AS CHAR(1)),
                CAST(src.DEALER_CITY AS VARCHAR(MAX)),
                CAST(src.DEALER_ADDLINE4 AS VARCHAR(MAX)),
                CAST(src.DEALER_ADDLINE3 AS VARCHAR(MAX)),
                CAST(src.DEALER_ADDLINE2 AS VARCHAR(MAX)),
                CAST(src.DEALER_ADDLINE1 AS VARCHAR(MAX)),
                CAST(src.DEALER_TYPE AS VARCHAR(MAX)),
                CAST(src.DEALER_NAME AS VARCHAR(MAX)),
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                CAST(src.DEALER_ZIPCODE AS VARCHAR(MAX)),
                CAST(src.DEALER_STATE AS VARCHAR(MAX)),
                CAST(src.DEALER_TRADING_ID AS VARCHAR(MAX)),
                CAST(src.SC_FIRM_ID AS VARCHAR(MAX)),
                CAST(src.DEALER_TYPE_CODE AS INT),
                CAST(src.SEQ_DEALER_ID AS INT)
            FROM ' + @SrcFQN + N' AS src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + N' AS tgt
                WHERE tgt.DEALER_KEY = CAST(src.DEALER_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END;

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 9. T_D_DISBURSEMENT
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;

-- Fully-qualified, safely-quoted object names built from parameters
SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' + QUOTENAME(@StageSchemaName) + '.' + QUOTENAME('T_D_DISBURSEMENT');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' + QUOTENAME('T_D_DISBURSEMENT');

SET @TgtObjectId = @TargetSchemaName + '.T_D_DISBURSEMENT';

BEGIN TRY

    

    IF OBJECT_ID(@TgtObjectId, 'U') IS NULL
    BEGIN
        -- Target table does not exist: create it directly from staging
        SET @SQL = N'
            SELECT
                CAST(src.EARNINGS_AMOUNT AS DECIMAL(18,4))        AS EARNINGS_AMOUNT,
                CAST(src.PRINCIPAL_AMOUNT AS DECIMAL(18,4))       AS PRINCIPAL_AMOUNT,
                CAST(src.DISBURSEMENT_KEY AS INT)                 AS DISBURSEMENT_KEY,
                CAST(src.TLM AS DATETIME2(6))                     AS TLM,
                CAST(src.REVERSAL_FLAG AS CHAR(1))                AS REVERSAL_FLAG,
                CAST(src.PAYEE_CITY AS VARCHAR(MAX))              AS PAYEE_CITY,
                CAST(src.PAYEE_ADDLINE4 AS VARCHAR(MAX))          AS PAYEE_ADDLINE4,
                CAST(src.PAYEE_ADDLINE3 AS VARCHAR(MAX))          AS PAYEE_ADDLINE3,
                CAST(src.PAYEE_ADDLINE2 AS VARCHAR(MAX))          AS PAYEE_ADDLINE2,
                CAST(src.PAYEE_ADDLINE1 AS VARCHAR(MAX))          AS PAYEE_ADDLINE1,
                CAST(src.PAYEE_NAME AS VARCHAR(MAX))              AS PAYEE_NAME,
                CAST(src.WITHDRAW_TYPE AS VARCHAR(MAX))           AS WITHDRAW_TYPE,
                CAST(src.WITHDRAWAL_AMOUNT_TYPE AS VARCHAR(MAX))  AS WITHDRAWAL_AMOUNT_TYPE,
                CAST(src.DISBURSEMENT_TYPE AS VARCHAR(MAX))       AS DISBURSEMENT_TYPE,
                CAST(src.TRAUNCH_ID AS VARCHAR(MAX))              AS TRAUNCH_ID,
                CAST(src.PAYEE_COUNTRY AS VARCHAR(MAX))           AS PAYEE_COUNTRY,
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX))            AS DW_CHANGE_ID,
                CAST(src.PAYEE_ZIPCODE AS VARCHAR(MAX))           AS PAYEE_ZIPCODE,
                CAST(src.PAYEE_STATE AS VARCHAR(MAX))             AS PAYEE_STATE,
                CAST(src.SEQ_DISBURSEMENT_ID AS INT)              AS SEQ_DISBURSEMENT_ID
            INTO ' + @TgtFQN + N'
            FROM ' + @SrcFQN + N' AS src;';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN
        -- Update existing records
        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.EARNINGS_AMOUNT        = CAST(src.EARNINGS_AMOUNT AS DECIMAL(18,4)),
                tgt.PRINCIPAL_AMOUNT       = CAST(src.PRINCIPAL_AMOUNT AS DECIMAL(18,4)),
                tgt.TLM                    = CAST(src.TLM AS DATETIME2(6)),
                tgt.REVERSAL_FLAG          = CAST(src.REVERSAL_FLAG AS CHAR(1)),
                tgt.PAYEE_CITY             = CAST(src.PAYEE_CITY AS VARCHAR(MAX)),
                tgt.PAYEE_ADDLINE4         = CAST(src.PAYEE_ADDLINE4 AS VARCHAR(MAX)),
                tgt.PAYEE_ADDLINE3         = CAST(src.PAYEE_ADDLINE3 AS VARCHAR(MAX)),
                tgt.PAYEE_ADDLINE2         = CAST(src.PAYEE_ADDLINE2 AS VARCHAR(MAX)),
                tgt.PAYEE_ADDLINE1         = CAST(src.PAYEE_ADDLINE1 AS VARCHAR(MAX)),
                tgt.PAYEE_NAME             = CAST(src.PAYEE_NAME AS VARCHAR(MAX)),
                tgt.WITHDRAW_TYPE          = CAST(src.WITHDRAW_TYPE AS VARCHAR(MAX)),
                tgt.WITHDRAWAL_AMOUNT_TYPE = CAST(src.WITHDRAWAL_AMOUNT_TYPE AS VARCHAR(MAX)),
                tgt.DISBURSEMENT_TYPE      = CAST(src.DISBURSEMENT_TYPE AS VARCHAR(MAX)),
                tgt.TRAUNCH_ID             = CAST(src.TRAUNCH_ID AS VARCHAR(MAX)),
                tgt.PAYEE_COUNTRY          = CAST(src.PAYEE_COUNTRY AS VARCHAR(MAX)),
                tgt.DW_CHANGE_ID           = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                tgt.PAYEE_ZIPCODE          = CAST(src.PAYEE_ZIPCODE AS VARCHAR(MAX)),
                tgt.PAYEE_STATE            = CAST(src.PAYEE_STATE AS VARCHAR(MAX)),
                tgt.SEQ_DISBURSEMENT_ID    = CAST(src.SEQ_DISBURSEMENT_ID AS INT)
            FROM ' + @TgtFQN + N' AS tgt
            INNER JOIN ' + @SrcFQN + N' AS src
                ON tgt.DISBURSEMENT_KEY = CAST(src.DISBURSEMENT_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        -- Insert new records
        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + N'
            (
                EARNINGS_AMOUNT,
                PRINCIPAL_AMOUNT,
                DISBURSEMENT_KEY,
                TLM,
                REVERSAL_FLAG,
                PAYEE_CITY,
                PAYEE_ADDLINE4,
                PAYEE_ADDLINE3,
                PAYEE_ADDLINE2,
                PAYEE_ADDLINE1,
                PAYEE_NAME,
                WITHDRAW_TYPE,
                WITHDRAWAL_AMOUNT_TYPE,
                DISBURSEMENT_TYPE,
                TRAUNCH_ID,
                PAYEE_COUNTRY,
                DW_CHANGE_ID,
                PAYEE_ZIPCODE,
                PAYEE_STATE,
                SEQ_DISBURSEMENT_ID
            )
            SELECT
                CAST(src.EARNINGS_AMOUNT AS DECIMAL(18,4)),
                CAST(src.PRINCIPAL_AMOUNT AS DECIMAL(18,4)),
                CAST(src.DISBURSEMENT_KEY AS INT),
                CAST(src.TLM AS DATETIME2(6)),
                CAST(src.REVERSAL_FLAG AS CHAR(1)),
                CAST(src.PAYEE_CITY AS VARCHAR(MAX)),
                CAST(src.PAYEE_ADDLINE4 AS VARCHAR(MAX)),
                CAST(src.PAYEE_ADDLINE3 AS VARCHAR(MAX)),
                CAST(src.PAYEE_ADDLINE2 AS VARCHAR(MAX)),
                CAST(src.PAYEE_ADDLINE1 AS VARCHAR(MAX)),
                CAST(src.PAYEE_NAME AS VARCHAR(MAX)),
                CAST(src.WITHDRAW_TYPE AS VARCHAR(MAX)),
                CAST(src.WITHDRAWAL_AMOUNT_TYPE AS VARCHAR(MAX)),
                CAST(src.DISBURSEMENT_TYPE AS VARCHAR(MAX)),
                CAST(src.TRAUNCH_ID AS VARCHAR(MAX)),
                CAST(src.PAYEE_COUNTRY AS VARCHAR(MAX)),
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                CAST(src.PAYEE_ZIPCODE AS VARCHAR(MAX)),
                CAST(src.PAYEE_STATE AS VARCHAR(MAX)),
                CAST(src.SEQ_DISBURSEMENT_ID AS INT)
            FROM ' + @SrcFQN + N' AS src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + N' AS tgt
                WHERE tgt.DISBURSEMENT_KEY = CAST(src.DISBURSEMENT_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END;

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 10. T_D_DORMANCY
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;

-- Fully-qualified, safely-quoted object names built from parameters
SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' + QUOTENAME(@StageSchemaName) + '.' + QUOTENAME('T_D_DORMANCY');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' + QUOTENAME('T_D_DORMANCY');

SET @TgtObjectId = @TargetSchemaName + '.T_D_DORMANCY';

BEGIN TRY

    

    IF OBJECT_ID(@TgtObjectId, 'U') IS NULL
    BEGIN
        -- Target table does not exist: create it directly from staging
        SET @SQL = N'
            SELECT
                CAST(src.DORMANCY_KEY AS INT)              AS DORMANCY_KEY,
                CAST(src.DORMANCY_FLAG AS VARCHAR(MAX))    AS DORMANCY_FLAG,
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX))     AS DW_CHANGE_ID,
                CAST(src.DORMANCY_DESCRIPTION AS VARCHAR(MAX)) AS DORMANCY_DESCRIPTION,
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM
            INTO ' + @TgtFQN + N'
            FROM ' + @SrcFQN + N' AS src;';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN
        -- Update existing records
        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.DORMANCY_FLAG        = CAST(src.DORMANCY_FLAG AS VARCHAR(MAX)),
                tgt.DW_CHANGE_ID         = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                tgt.DORMANCY_DESCRIPTION = CAST(src.DORMANCY_DESCRIPTION AS VARCHAR(MAX)),
                tgt.DW_UPD_DTTM          = src.DW_UPD_DTTM,
                tgt.DW_INS_DTTM          = src.DW_INS_DTTM
            FROM ' + @TgtFQN + N' AS tgt
            INNER JOIN ' + @SrcFQN + N' AS src
                ON tgt.DORMANCY_KEY = CAST(src.DORMANCY_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        -- Insert new records
        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + N'
            (
                DORMANCY_KEY,
                DORMANCY_FLAG,
                DW_CHANGE_ID,
                DORMANCY_DESCRIPTION,
                DW_UPD_DTTM,
                DW_INS_DTTM
            )
            SELECT
                CAST(src.DORMANCY_KEY AS INT),
                CAST(src.DORMANCY_FLAG AS VARCHAR(MAX)),
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                CAST(src.DORMANCY_DESCRIPTION AS VARCHAR(MAX)),
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM
            FROM ' + @SrcFQN + N' AS src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + N' AS tgt
                WHERE tgt.DORMANCY_KEY = CAST(src.DORMANCY_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END;

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 11. T_D_FUNDED
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;

-- Fully-qualified, safely-quoted object names built from parameters
SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' + QUOTENAME(@StageSchemaName) + '.' + QUOTENAME('T_D_FUNDED');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' + QUOTENAME('T_D_FUNDED');

SET @TgtObjectId = @TargetSchemaName + '.T_D_FUNDED';

BEGIN TRY

    

    IF OBJECT_ID(@TgtObjectId, 'U') IS NULL
    BEGIN
        -- Target table does not exist: create it directly from staging
        SET @SQL = N'
            SELECT
                CAST(src.FUNDED_KEY AS INT)              AS FUNDED_KEY,
                CAST(src.FUNDED_FLAG AS VARCHAR(MAX))    AS FUNDED_FLAG,
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX))   AS DW_CHANGE_ID,
                CAST(src.FUNDED_DESCRIPTION AS VARCHAR(MAX)) AS FUNDED_DESCRIPTION,
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM
            INTO ' + @TgtFQN + N'
            FROM ' + @SrcFQN + N' AS src;';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN
        -- Update existing records
        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.FUNDED_FLAG        = CAST(src.FUNDED_FLAG AS VARCHAR(MAX)),
                tgt.DW_CHANGE_ID       = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                tgt.FUNDED_DESCRIPTION = CAST(src.FUNDED_DESCRIPTION AS VARCHAR(MAX)),
                tgt.DW_UPD_DTTM        = src.DW_UPD_DTTM,
                tgt.DW_INS_DTTM        = src.DW_INS_DTTM
            FROM ' + @TgtFQN + N' AS tgt
            INNER JOIN ' + @SrcFQN + N' AS src
                ON tgt.FUNDED_KEY = CAST(src.FUNDED_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        -- Insert new records
        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + N'
            (
                FUNDED_KEY,
                FUNDED_FLAG,
                DW_CHANGE_ID,
                FUNDED_DESCRIPTION,
                DW_UPD_DTTM,
                DW_INS_DTTM
            )
            SELECT
                CAST(src.FUNDED_KEY AS INT),
                CAST(src.FUNDED_FLAG AS VARCHAR(MAX)),
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                CAST(src.FUNDED_DESCRIPTION AS VARCHAR(MAX)),
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM
            FROM ' + @SrcFQN + N' AS src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + N' AS tgt
                WHERE tgt.FUNDED_KEY = CAST(src.FUNDED_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END;

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 12. T_D_MEMBER_PERM_TYPE
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;

-- Fully-qualified, safely-quoted object names built from parameters
SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' + QUOTENAME(@StageSchemaName) + '.' + QUOTENAME('T_D_MEMBER_PERM_TYPE');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' + QUOTENAME('T_D_MEMBER_PERM_TYPE');

SET @TgtObjectId = @TargetSchemaName + '.T_D_MEMBER_PERM_TYPE';

BEGIN TRY

    

    IF OBJECT_ID(@TgtObjectId, 'U') IS NULL
    BEGIN
        -- Target table does not exist: create it directly from staging
        SET @SQL = N'
            SELECT
                CAST(src.DW_ETL_JOB_ID AS INT)                    AS DW_ETL_JOB_ID,
                CAST(src.MEMBER_PERM_TYPE_KEY AS INT)             AS MEMBER_PERM_TYPE_KEY,
                CAST(src.MEMBER_PERM_TYPE_DESC AS VARCHAR(MAX))   AS MEMBER_PERM_TYPE_DESC,
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX))            AS DW_CHANGE_ID,
                CAST(src.MEMBER_PERM_TYPE_CODE AS VARCHAR(MAX))   AS MEMBER_PERM_TYPE_CODE,
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM
            INTO ' + @TgtFQN + N'
            FROM ' + @SrcFQN + N' AS src;';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN
        -- Update existing records
        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.DW_ETL_JOB_ID          = CAST(src.DW_ETL_JOB_ID AS INT),
                tgt.MEMBER_PERM_TYPE_DESC  = CAST(src.MEMBER_PERM_TYPE_DESC AS VARCHAR(MAX)),
                tgt.DW_CHANGE_ID           = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                tgt.MEMBER_PERM_TYPE_CODE  = CAST(src.MEMBER_PERM_TYPE_CODE AS VARCHAR(MAX)),
                tgt.DW_UPD_DTTM            = src.DW_UPD_DTTM,
                tgt.DW_INS_DTTM            = src.DW_INS_DTTM
            FROM ' + @TgtFQN + N' AS tgt
            INNER JOIN ' + @SrcFQN + N' AS src
                ON tgt.MEMBER_PERM_TYPE_KEY = CAST(src.MEMBER_PERM_TYPE_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        -- Insert new records
        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + N'
            (
                DW_ETL_JOB_ID,
                MEMBER_PERM_TYPE_KEY,
                MEMBER_PERM_TYPE_DESC,
                DW_CHANGE_ID,
                MEMBER_PERM_TYPE_CODE,
                DW_UPD_DTTM,
                DW_INS_DTTM
            )
            SELECT
                CAST(src.DW_ETL_JOB_ID AS INT),
                CAST(src.MEMBER_PERM_TYPE_KEY AS INT),
                CAST(src.MEMBER_PERM_TYPE_DESC AS VARCHAR(MAX)),
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                CAST(src.MEMBER_PERM_TYPE_CODE AS VARCHAR(MAX)),
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM
            FROM ' + @SrcFQN + N' AS src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + N' AS tgt
                WHERE tgt.MEMBER_PERM_TYPE_KEY = CAST(src.MEMBER_PERM_TYPE_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END;

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 13. T_D_MEMBER_ROLE_TYPE
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;

-- Fully-qualified, safely-quoted object names built from parameters
SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' + QUOTENAME(@StageSchemaName) + '.' + QUOTENAME('T_D_MEMBER_ROLE_TYPE');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' + QUOTENAME('T_D_MEMBER_ROLE_TYPE');

SET @TgtObjectId = @TargetSchemaName + '.T_D_MEMBER_ROLE_TYPE';

BEGIN TRY

    

    IF OBJECT_ID(@TgtObjectId, 'U') IS NULL
    BEGIN
        -- Target table does not exist: create it directly from staging
        SET @SQL = N'
            SELECT
                CAST(src.DW_ETL_JOB_ID AS INT)                     AS DW_ETL_JOB_ID,
                CAST(src.MEMBER_ROLE_TYPE_KEY AS INT)              AS MEMBER_ROLE_TYPE_KEY,
                CAST(src.MEMBER_ROLE_TYPE_DESCR AS VARCHAR(MAX))   AS MEMBER_ROLE_TYPE_DESCR,
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX))             AS DW_CHANGE_ID,
                CAST(src.MEMBER_ROLE_TYPE_CODE AS VARCHAR(MAX))    AS MEMBER_ROLE_TYPE_CODE,
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM
            INTO ' + @TgtFQN + N'
            FROM ' + @SrcFQN + N' AS src;';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN
        -- Update existing records
        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.DW_ETL_JOB_ID           = CAST(src.DW_ETL_JOB_ID AS INT),
                tgt.MEMBER_ROLE_TYPE_DESCR  = CAST(src.MEMBER_ROLE_TYPE_DESCR AS VARCHAR(MAX)),
                tgt.DW_CHANGE_ID            = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                tgt.MEMBER_ROLE_TYPE_CODE   = CAST(src.MEMBER_ROLE_TYPE_CODE AS VARCHAR(MAX)),
                tgt.DW_UPD_DTTM             = src.DW_UPD_DTTM,
                tgt.DW_INS_DTTM             = src.DW_INS_DTTM
            FROM ' + @TgtFQN + N' AS tgt
            INNER JOIN ' + @SrcFQN + N' AS src
                ON tgt.MEMBER_ROLE_TYPE_KEY = CAST(src.MEMBER_ROLE_TYPE_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        -- Insert new records
        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + N'
            (
                DW_ETL_JOB_ID,
                MEMBER_ROLE_TYPE_KEY,
                MEMBER_ROLE_TYPE_DESCR,
                DW_CHANGE_ID,
                MEMBER_ROLE_TYPE_CODE,
                DW_UPD_DTTM,
                DW_INS_DTTM
            )
            SELECT
                CAST(src.DW_ETL_JOB_ID AS INT),
                CAST(src.MEMBER_ROLE_TYPE_KEY AS INT),
                CAST(src.MEMBER_ROLE_TYPE_DESCR AS VARCHAR(MAX)),
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                CAST(src.MEMBER_ROLE_TYPE_CODE AS VARCHAR(MAX)),
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM
            FROM ' + @SrcFQN + N' AS src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + N' AS tgt
                WHERE tgt.MEMBER_ROLE_TYPE_KEY = CAST(src.MEMBER_ROLE_TYPE_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END;

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 14. T_D_MEMBER_STATUS
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;

-- Fully-qualified, safely-quoted object names built from parameters
SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' + QUOTENAME(@StageSchemaName) + '.' + QUOTENAME('T_D_MEMBER_STATUS');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' + QUOTENAME('T_D_MEMBER_STATUS');

SET @TgtObjectId = @TargetSchemaName + '.T_D_MEMBER_STATUS';

BEGIN TRY

    

    IF OBJECT_ID(@TgtObjectId, 'U') IS NULL
    BEGIN
        -- Target table does not exist: create it directly from staging
        SET @SQL = N'
            SELECT
                CAST(src.DW_ETL_JOB_ID AS INT)                  AS DW_ETL_JOB_ID,
                CAST(src.MEMBER_STATUS_KEY AS INT)              AS MEMBER_STATUS_KEY,
                CAST(src.MEMBER_STATUS_DESCR AS VARCHAR(MAX))   AS MEMBER_STATUS_DESCR,
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX))          AS DW_CHANGE_ID,
                CAST(src.MEMBER_STATUS_CODE AS VARCHAR(MAX))    AS MEMBER_STATUS_CODE,
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM
            INTO ' + @TgtFQN + N'
            FROM ' + @SrcFQN + N' AS src;';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN
        -- Update existing records
        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.DW_ETL_JOB_ID         = CAST(src.DW_ETL_JOB_ID AS INT),
                tgt.MEMBER_STATUS_DESCR   = CAST(src.MEMBER_STATUS_DESCR AS VARCHAR(MAX)),
                tgt.DW_CHANGE_ID          = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                tgt.MEMBER_STATUS_CODE    = CAST(src.MEMBER_STATUS_CODE AS VARCHAR(MAX)),
                tgt.DW_UPD_DTTM           = src.DW_UPD_DTTM,
                tgt.DW_INS_DTTM           = src.DW_INS_DTTM
            FROM ' + @TgtFQN + N' AS tgt
            INNER JOIN ' + @SrcFQN + N' AS src
                ON tgt.MEMBER_STATUS_KEY = CAST(src.MEMBER_STATUS_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        -- Insert new records
        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + N'
            (
                DW_ETL_JOB_ID,
                MEMBER_STATUS_KEY,
                MEMBER_STATUS_DESCR,
                DW_CHANGE_ID,
                MEMBER_STATUS_CODE,
                DW_UPD_DTTM,
                DW_INS_DTTM
            )
            SELECT
                CAST(src.DW_ETL_JOB_ID AS INT),
                CAST(src.MEMBER_STATUS_KEY AS INT),
                CAST(src.MEMBER_STATUS_DESCR AS VARCHAR(MAX)),
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                CAST(src.MEMBER_STATUS_CODE AS VARCHAR(MAX)),
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM
            FROM ' + @SrcFQN + N' AS src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + N' AS tgt
                WHERE tgt.MEMBER_STATUS_KEY = CAST(src.MEMBER_STATUS_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END;

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 15. T_D_OMNIBUS_SOURCE
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;

-- Fully-qualified, safely-quoted object names built from parameters
SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' + QUOTENAME(@StageSchemaName) + '.' + QUOTENAME('T_D_OMNIBUS_SOURCE');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' + QUOTENAME('T_D_OMNIBUS_SOURCE');

SET @TgtObjectId = @TargetSchemaName + '.T_D_OMNIBUS_SOURCE';

BEGIN TRY

    

    IF OBJECT_ID(@TgtObjectId, 'U') IS NULL
    BEGIN
        -- Target table does not exist: create it directly from staging
        SET @SQL = N'
            SELECT
                CAST(src.SEQ_RK_ID AS INT)                                AS SEQ_RK_ID,
                CAST(src.OMNIBUS_SOURCE_KEY AS INT)                       AS OMNIBUS_SOURCE_KEY,
                CAST(src.TLM AS DATETIME2(6))                             AS TLM,
                CAST(src.DEALER_NAME AS VARCHAR(MAX))                     AS DEALER_NAME,
                CAST(src.RECEIVING_FIRM_NUMBER AS VARCHAR(MAX))           AS RECEIVING_FIRM_NUMBER,
                CAST(src.SUBMITTING_FIRM_NUMBER AS VARCHAR(MAX))          AS SUBMITTING_FIRM_NUMBER,
                CAST(src.DEALER_ID AS VARCHAR(MAX))                       AS DEALER_ID,
                CAST(src.TRAUNCH_ID AS VARCHAR(MAX))                      AS TRAUNCH_ID,
                CAST(src.ACCOUNT_PREFIX AS VARCHAR(MAX))                  AS ACCOUNT_PREFIX,
                CAST(src.PLAN_STATE AS VARCHAR(MAX))                      AS PLAN_STATE,
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX))                    AS DW_CHANGE_ID,
                CAST(src.RK_NAME AS VARCHAR(MAX))                         AS RK_NAME,
                CAST(src.DW_DSA_FLAG AS VARCHAR(MAX))                     AS DW_DSA_FLAG,
                CAST(src.OMNIBUS_SOURCE_ACTIVE_FLAG AS VARCHAR(MAX))      AS OMNIBUS_SOURCE_ACTIVE_FLAG,
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM,
                CAST(src.SEQ_DEALER_ID AS INT)                            AS SEQ_DEALER_ID
            INTO ' + @TgtFQN + N'
            FROM ' + @SrcFQN + N' AS src;';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN
        -- Update existing records
        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.SEQ_RK_ID                     = CAST(src.SEQ_RK_ID AS INT),
                tgt.TLM                           = CAST(src.TLM AS DATETIME2(6)),
                tgt.DEALER_NAME                    = CAST(src.DEALER_NAME AS VARCHAR(MAX)),
                tgt.RECEIVING_FIRM_NUMBER          = CAST(src.RECEIVING_FIRM_NUMBER AS VARCHAR(MAX)),
                tgt.SUBMITTING_FIRM_NUMBER         = CAST(src.SUBMITTING_FIRM_NUMBER AS VARCHAR(MAX)),
                tgt.DEALER_ID                      = CAST(src.DEALER_ID AS VARCHAR(MAX)),
                tgt.TRAUNCH_ID                      = CAST(src.TRAUNCH_ID AS VARCHAR(MAX)),
                tgt.ACCOUNT_PREFIX                  = CAST(src.ACCOUNT_PREFIX AS VARCHAR(MAX)),
                tgt.PLAN_STATE                      = CAST(src.PLAN_STATE AS VARCHAR(MAX)),
                tgt.DW_CHANGE_ID                    = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                tgt.RK_NAME                         = CAST(src.RK_NAME AS VARCHAR(MAX)),
                tgt.DW_DSA_FLAG                      = CAST(src.DW_DSA_FLAG AS VARCHAR(MAX)),
                tgt.OMNIBUS_SOURCE_ACTIVE_FLAG       = CAST(src.OMNIBUS_SOURCE_ACTIVE_FLAG AS VARCHAR(MAX)),
                tgt.DW_UPD_DTTM                      = src.DW_UPD_DTTM,
                tgt.DW_INS_DTTM                      = src.DW_INS_DTTM,
                tgt.SEQ_DEALER_ID                    = CAST(src.SEQ_DEALER_ID AS INT)
            FROM ' + @TgtFQN + N' AS tgt
            INNER JOIN ' + @SrcFQN + N' AS src
                ON tgt.OMNIBUS_SOURCE_KEY = CAST(src.OMNIBUS_SOURCE_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        -- Insert new records
        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + N'
            (
                SEQ_RK_ID,
                OMNIBUS_SOURCE_KEY,
                TLM,
                DEALER_NAME,
                RECEIVING_FIRM_NUMBER,
                SUBMITTING_FIRM_NUMBER,
                DEALER_ID,
                TRAUNCH_ID,
                ACCOUNT_PREFIX,
                PLAN_STATE,
                DW_CHANGE_ID,
                RK_NAME,
                DW_DSA_FLAG,
                OMNIBUS_SOURCE_ACTIVE_FLAG,
                DW_UPD_DTTM,
                DW_INS_DTTM,
                SEQ_DEALER_ID
            )
            SELECT
                CAST(src.SEQ_RK_ID AS INT),
                CAST(src.OMNIBUS_SOURCE_KEY AS INT),
                CAST(src.TLM AS DATETIME2(6)),
                CAST(src.DEALER_NAME AS VARCHAR(MAX)),
                CAST(src.RECEIVING_FIRM_NUMBER AS VARCHAR(MAX)),
                CAST(src.SUBMITTING_FIRM_NUMBER AS VARCHAR(MAX)),
                CAST(src.DEALER_ID AS VARCHAR(MAX)),
                CAST(src.TRAUNCH_ID AS VARCHAR(MAX)),
                CAST(src.ACCOUNT_PREFIX AS VARCHAR(MAX)),
                CAST(src.PLAN_STATE AS VARCHAR(MAX)),
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                CAST(src.RK_NAME AS VARCHAR(MAX)),
                CAST(src.DW_DSA_FLAG AS VARCHAR(MAX)),
                CAST(src.OMNIBUS_SOURCE_ACTIVE_FLAG AS VARCHAR(MAX)),
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM,
                CAST(src.SEQ_DEALER_ID AS INT)
            FROM ' + @SrcFQN + N' AS src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + N' AS tgt
                WHERE tgt.OMNIBUS_SOURCE_KEY = CAST(src.OMNIBUS_SOURCE_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END;

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 16. T_D_ORGANIZATION_STATUS
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;

-- Fully-qualified, safely-quoted object names built from parameters
SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' + QUOTENAME(@StageSchemaName) + '.' + QUOTENAME('T_D_ORGANIZATION_STATUS');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' + QUOTENAME('T_D_ORGANIZATION_STATUS');

SET @TgtObjectId = @TargetSchemaName + '.T_D_ORGANIZATION_STATUS';

BEGIN TRY

    

    IF OBJECT_ID(@TgtObjectId, 'U') IS NULL
    BEGIN
        -- Target table does not exist: create it directly from staging
        SET @SQL = N'
            SELECT
                CAST(src.DW_ETL_JOB_ID AS INT)                        AS DW_ETL_JOB_ID,
                CAST(src.ORGANIZATION_STATUS_KEY AS INT)              AS ORGANIZATION_STATUS_KEY,
                CAST(src.ORGANIZATION_STATUS_DESCR AS VARCHAR(MAX))   AS ORGANIZATION_STATUS_DESCR,
                CAST(src.ORGANIZATION_STATUS_CODE AS VARCHAR(MAX))    AS ORGANIZATION_STATUS_CODE,
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX))                AS DW_CHANGE_ID,
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM
            INTO ' + @TgtFQN + N'
            FROM ' + @SrcFQN + N' AS src;';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN
        -- Update existing records
        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.DW_ETL_JOB_ID              = CAST(src.DW_ETL_JOB_ID AS INT),
                tgt.ORGANIZATION_STATUS_DESCR  = CAST(src.ORGANIZATION_STATUS_DESCR AS VARCHAR(MAX)),
                tgt.ORGANIZATION_STATUS_CODE   = CAST(src.ORGANIZATION_STATUS_CODE AS VARCHAR(MAX)),
                tgt.DW_CHANGE_ID                = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                tgt.DW_UPD_DTTM                 = src.DW_UPD_DTTM,
                tgt.DW_INS_DTTM                 = src.DW_INS_DTTM
            FROM ' + @TgtFQN + N' AS tgt
            INNER JOIN ' + @SrcFQN + N' AS src
                ON tgt.ORGANIZATION_STATUS_KEY = CAST(src.ORGANIZATION_STATUS_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        -- Insert new records
        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + N'
            (
                DW_ETL_JOB_ID,
                ORGANIZATION_STATUS_KEY,
                ORGANIZATION_STATUS_DESCR,
                ORGANIZATION_STATUS_CODE,
                DW_CHANGE_ID,
                DW_UPD_DTTM,
                DW_INS_DTTM
            )
            SELECT
                CAST(src.DW_ETL_JOB_ID AS INT),
                CAST(src.ORGANIZATION_STATUS_KEY AS INT),
                CAST(src.ORGANIZATION_STATUS_DESCR AS VARCHAR(MAX)),
                CAST(src.ORGANIZATION_STATUS_CODE AS VARCHAR(MAX)),
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM
            FROM ' + @SrcFQN + N' AS src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + N' AS tgt
                WHERE tgt.ORGANIZATION_STATUS_KEY = CAST(src.ORGANIZATION_STATUS_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END;

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 17. T_D_ORGANIZATION_TYPE
-- NOTE: this block uses a different existence-check pattern
-- (sys.tables / sys.schemas + @TableExists BIT) rather than OBJECT_ID.
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;
SET @TableExists = 0;

-- Fully-qualified, safely-quoted object names built from parameters
SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' + QUOTENAME(@StageSchemaName) + '.' + QUOTENAME('T_D_ORGANIZATION_TYPE');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' + QUOTENAME('T_D_ORGANIZATION_TYPE');

SET @TgtObjectId = @TargetSchemaName + '.T_D_ORGANIZATION_TYPE';

BEGIN TRY

    

    -- Check whether target table already exists (schema parameterized)
    IF EXISTS
    (
        SELECT 1
        FROM sys.tables t
        INNER JOIN sys.schemas s
            ON t.schema_id = s.schema_id
        WHERE s.name = @TargetSchemaName
          AND t.name = 'T_D_ORGANIZATION_TYPE'
    )
        SET @TableExists = 1;

    IF @TableExists = 0
    BEGIN
        -- Target does NOT exist: create it via SELECT INTO
        SET @SQL = N'
            SELECT
                CAST(src.DW_ETL_JOB_ID AS INT)                       AS DW_ETL_JOB_ID,
                CAST(src.ORGANIZATION_TYPE_KEY AS INT)               AS ORGANIZATION_TYPE_KEY,
                CAST(src.ORGANIZATION_TYPE_DESCR AS VARCHAR(MAX))    AS ORGANIZATION_TYPE_DESCR,
                CAST(src.ORGANIZATION_TYPE_CODE AS VARCHAR(MAX))     AS ORGANIZATION_TYPE_CODE,
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX))               AS DW_CHANGE_ID,
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM
            INTO ' + @TgtFQN + N'
            FROM ' + @SrcFQN + N' AS src;';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN
        -- Target exists: standard UPDATE + INSERT (upsert)
        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.DW_ETL_JOB_ID           = CAST(src.DW_ETL_JOB_ID AS INT),
                tgt.ORGANIZATION_TYPE_DESCR = CAST(src.ORGANIZATION_TYPE_DESCR AS VARCHAR(MAX)),
                tgt.ORGANIZATION_TYPE_CODE  = CAST(src.ORGANIZATION_TYPE_CODE AS VARCHAR(MAX)),
                tgt.DW_CHANGE_ID            = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                tgt.DW_UPD_DTTM             = src.DW_UPD_DTTM,
                tgt.DW_INS_DTTM             = src.DW_INS_DTTM
            FROM ' + @TgtFQN + N' AS tgt
            INNER JOIN ' + @SrcFQN + N' AS src
                ON tgt.ORGANIZATION_TYPE_KEY = CAST(src.ORGANIZATION_TYPE_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + N'
            (
                DW_ETL_JOB_ID,
                ORGANIZATION_TYPE_KEY,
                ORGANIZATION_TYPE_DESCR,
                ORGANIZATION_TYPE_CODE,
                DW_CHANGE_ID,
                DW_UPD_DTTM,
                DW_INS_DTTM
            )
            SELECT
                CAST(src.DW_ETL_JOB_ID AS INT),
                CAST(src.ORGANIZATION_TYPE_KEY AS INT),
                CAST(src.ORGANIZATION_TYPE_DESCR AS VARCHAR(MAX)),
                CAST(src.ORGANIZATION_TYPE_CODE AS VARCHAR(MAX)),
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM
            FROM ' + @SrcFQN + N' AS src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + N' AS tgt
                WHERE tgt.ORGANIZATION_TYPE_KEY = CAST(src.ORGANIZATION_TYPE_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END;

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 18. T_D_PLAN
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;
SET @TableExists = 0;

SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' +
    QUOTENAME(@StageSchemaName) + '.' +
    QUOTENAME('T_D_PLAN');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' +
    QUOTENAME('T_D_PLAN');

SET @TgtObjectId = @TargetSchemaName + '.T_D_PLAN';

BEGIN TRY

    IF OBJECT_ID(@TgtObjectId, 'U') IS NOT NULL
        SET @TableExists = 1;

    

    IF @TableExists = 0
    BEGIN

        SET @SQL = N'
            SELECT
                CAST(MAX_CONTRIB AS INT)                    AS MAX_CONTRIB,
                CAST(PLAN_KEY AS INT)                       AS PLAN_KEY,
                CAST(DECONVERSION_DATE AS DATETIME2(6))     AS DECONVERSION_DATE,
                CAST(CONVERTED_DATE AS DATETIME2(6))        AS CONVERTED_DATE,
                CAST(INCEPTION_DATE AS DATETIME2(6))        AS INCEPTION_DATE,
                CAST(TLM AS DATETIME2(6))                   AS TLM,
                CAST(STATE AS CHAR(2))                      AS STATE,
                CAST(PLAN_ACTIVE_FLAG AS CHAR(1))           AS PLAN_ACTIVE_FLAG,
                CAST(PRODUCT_SUBTYPE AS VARCHAR(MAX))       AS PRODUCT_SUBTYPE,
                CAST(PLAN_PHONE AS VARCHAR(MAX))            AS PLAN_PHONE,
                CAST(PROGRAM AS VARCHAR(MAX))               AS PROGRAM,
                CAST(PLAN_NAME AS VARCHAR(MAX))             AS PLAN_NAME,
                CAST(LEGAL_PLAN_NAME AS VARCHAR(MAX))       AS LEGAL_PLAN_NAME,
                CAST(TRAUNCH_ID AS VARCHAR(MAX))            AS TRAUNCH_ID,
                CAST(CONSORTIUM_BRANDING AS VARCHAR(MAX))   AS CONSORTIUM_BRANDING,
                CAST(PLAN_TYPE AS VARCHAR(MAX))             AS PLAN_TYPE,
                CAST(PRODUCT_TYPE AS VARCHAR(MAX))          AS PRODUCT_TYPE,
                CAST(DW_CHANGE_ID AS VARCHAR(MAX))          AS DW_CHANGE_ID,
                CAST(BACKEND_TYPE AS VARCHAR(MAX))          AS BACKEND_TYPE,
                CAST(STATE_NAME AS VARCHAR(MAX))            AS STATE_NAME,
                CAST(PLAN_MANAGER AS VARCHAR(MAX))          AS PLAN_MANAGER,
                CAST(LOYALTY_PLAN_NAME AS VARCHAR(MAX))     AS LOYALTY_PLAN_NAME,
                CAST(MAX_MKT_VAL AS INT)                    AS MAX_MKT_VAL,
                CAST(MIN_EPAY_CONTRIB AS INT)               AS MIN_EPAY_CONTRIB,
                CAST(MIN_REC_CONTRIB AS INT)                AS MIN_REC_CONTRIB,
                CAST(MIN_INIT_CONTRIB AS INT)               AS MIN_INIT_CONTRIB
            INTO ' + @TgtFQN + '
            FROM ' + @SrcFQN + ';';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN

        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.MAX_CONTRIB           = CAST(src.MAX_CONTRIB AS INT),
                tgt.DECONVERSION_DATE     = CAST(src.DECONVERSION_DATE AS DATETIME2(6)),
                tgt.CONVERTED_DATE        = CAST(src.CONVERTED_DATE AS DATETIME2(6)),
                tgt.INCEPTION_DATE        = CAST(src.INCEPTION_DATE AS DATETIME2(6)),
                tgt.TLM                   = CAST(src.TLM AS DATETIME2(6)),
                tgt.STATE                 = CAST(src.STATE AS CHAR(2)),
                tgt.PLAN_ACTIVE_FLAG      = CAST(src.PLAN_ACTIVE_FLAG AS CHAR(1)),
                tgt.PRODUCT_SUBTYPE       = CAST(src.PRODUCT_SUBTYPE AS VARCHAR(MAX)),
                tgt.PLAN_PHONE            = CAST(src.PLAN_PHONE AS VARCHAR(MAX)),
                tgt.PROGRAM               = CAST(src.PROGRAM AS VARCHAR(MAX)),
                tgt.PLAN_NAME             = CAST(src.PLAN_NAME AS VARCHAR(MAX)),
                tgt.LEGAL_PLAN_NAME       = CAST(src.LEGAL_PLAN_NAME AS VARCHAR(MAX)),
                tgt.TRAUNCH_ID            = CAST(src.TRAUNCH_ID AS VARCHAR(MAX)),
                tgt.CONSORTIUM_BRANDING   = CAST(src.CONSORTIUM_BRANDING AS VARCHAR(MAX)),
                tgt.PLAN_TYPE             = CAST(src.PLAN_TYPE AS VARCHAR(MAX)),
                tgt.PRODUCT_TYPE          = CAST(src.PRODUCT_TYPE AS VARCHAR(MAX)),
                tgt.DW_CHANGE_ID          = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                tgt.BACKEND_TYPE          = CAST(src.BACKEND_TYPE AS VARCHAR(MAX)),
                tgt.STATE_NAME            = CAST(src.STATE_NAME AS VARCHAR(MAX)),
                tgt.PLAN_MANAGER          = CAST(src.PLAN_MANAGER AS VARCHAR(MAX)),
                tgt.LOYALTY_PLAN_NAME     = CAST(src.LOYALTY_PLAN_NAME AS VARCHAR(MAX)),
                tgt.MAX_MKT_VAL           = CAST(src.MAX_MKT_VAL AS INT),
                tgt.MIN_EPAY_CONTRIB      = CAST(src.MIN_EPAY_CONTRIB AS INT),
                tgt.MIN_REC_CONTRIB       = CAST(src.MIN_REC_CONTRIB AS INT),
                tgt.MIN_INIT_CONTRIB      = CAST(src.MIN_INIT_CONTRIB AS INT)
            FROM ' + @TgtFQN + ' tgt
            INNER JOIN ' + @SrcFQN + ' src
                ON tgt.PLAN_KEY = CAST(src.PLAN_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + '
            (
                MAX_CONTRIB, PLAN_KEY, DECONVERSION_DATE, CONVERTED_DATE, INCEPTION_DATE,
                TLM, STATE, PLAN_ACTIVE_FLAG, PRODUCT_SUBTYPE, PLAN_PHONE, PROGRAM,
                PLAN_NAME, LEGAL_PLAN_NAME, TRAUNCH_ID, CONSORTIUM_BRANDING, PLAN_TYPE,
                PRODUCT_TYPE, DW_CHANGE_ID, BACKEND_TYPE, STATE_NAME, PLAN_MANAGER,
                LOYALTY_PLAN_NAME, MAX_MKT_VAL, MIN_EPAY_CONTRIB, MIN_REC_CONTRIB, MIN_INIT_CONTRIB
            )
            SELECT
                CAST(MAX_CONTRIB AS INT),
                CAST(PLAN_KEY AS INT),
                CAST(DECONVERSION_DATE AS DATETIME2(6)),
                CAST(CONVERTED_DATE AS DATETIME2(6)),
                CAST(INCEPTION_DATE AS DATETIME2(6)),
                CAST(TLM AS DATETIME2(6)),
                CAST(STATE AS CHAR(2)),
                CAST(PLAN_ACTIVE_FLAG AS CHAR(1)),
                CAST(PRODUCT_SUBTYPE AS VARCHAR(MAX)),
                CAST(PLAN_PHONE AS VARCHAR(MAX)),
                CAST(PROGRAM AS VARCHAR(MAX)),
                CAST(PLAN_NAME AS VARCHAR(MAX)),
                CAST(LEGAL_PLAN_NAME AS VARCHAR(MAX)),
                CAST(TRAUNCH_ID AS VARCHAR(MAX)),
                CAST(CONSORTIUM_BRANDING AS VARCHAR(MAX)),
                CAST(PLAN_TYPE AS VARCHAR(MAX)),
                CAST(PRODUCT_TYPE AS VARCHAR(MAX)),
                CAST(DW_CHANGE_ID AS VARCHAR(MAX)),
                CAST(BACKEND_TYPE AS VARCHAR(MAX)),
                CAST(STATE_NAME AS VARCHAR(MAX)),
                CAST(PLAN_MANAGER AS VARCHAR(MAX)),
                CAST(LOYALTY_PLAN_NAME AS VARCHAR(MAX)),
                CAST(MAX_MKT_VAL AS INT),
                CAST(MIN_EPAY_CONTRIB AS INT),
                CAST(MIN_REC_CONTRIB AS INT),
                CAST(MIN_INIT_CONTRIB AS INT)
            FROM ' + @SrcFQN + ' src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + ' tgt
                WHERE tgt.PLAN_KEY = CAST(src.PLAN_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 19. T_D_REP
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;
SET @TableExists = 0;

SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' +
    QUOTENAME(@StageSchemaName) + '.' +
    QUOTENAME('T_D_REP');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' +
    QUOTENAME('T_D_REP');

SET @TgtObjectId = @TargetSchemaName + '.T_D_REP';

BEGIN TRY

    IF OBJECT_ID(@TgtObjectId, 'U') IS NOT NULL
        SET @TableExists = 1;

    

    IF @TableExists = 0
    BEGIN

        SET @SQL = N'
            SELECT
                CAST(REP_KEY AS INT)                    AS REP_KEY,
                CAST(SEQ_REP_ID AS INT)                 AS SEQ_REP_ID,
                CAST(SC_REP_ID AS VARCHAR(MAX))         AS SC_REP_ID,
                CAST(REP_TRADING_ID AS VARCHAR(MAX))    AS REP_TRADING_ID,
                CAST(TITLE AS VARCHAR(MAX))             AS TITLE,
                CAST(FIRST_NAME AS VARCHAR(MAX))        AS FIRST_NAME,
                CAST(LAST_NAME AS VARCHAR(MAX))         AS LAST_NAME,
                CAST(MIDDLE_INITIAL AS CHAR(1))         AS MIDDLE_INITIAL,
                CAST(SUFFIX AS VARCHAR(MAX))            AS SUFFIX,
                CAST(REP_ADDLINE1 AS VARCHAR(MAX))      AS REP_ADDLINE1,
                CAST(REP_ADDLINE2 AS VARCHAR(MAX))      AS REP_ADDLINE2,
                CAST(REP_ADDLINE3 AS VARCHAR(MAX))      AS REP_ADDLINE3,
                CAST(REP_CITY AS VARCHAR(MAX))          AS REP_CITY,
                CAST(REP_STATE AS VARCHAR(MAX))         AS REP_STATE,
                CAST(REP_ZIPCODE AS VARCHAR(MAX))       AS REP_ZIPCODE,
                CAST(REP_PHONE AS VARCHAR(MAX))         AS REP_PHONE,
                CAST(EFFECTIVE_DATE AS DATETIME2(6))    AS EFFECTIVE_DATE,
                CAST(EXPIRATION_DATE AS DATETIME2(6))   AS EXPIRATION_DATE,
                CAST(RECORD_STATUS AS VARCHAR(MAX))     AS RECORD_STATUS,
                CAST(TLM AS DATETIME2(6))               AS TLM,
                CAST(ACTIVE_FLAG AS CHAR(1))            AS ACTIVE_FLAG,
                CAST(CRD_NUMBER AS VARCHAR(MAX))        AS CRD_NUMBER,
                CAST(REP_EMAIL AS VARCHAR(MAX))         AS REP_EMAIL,
                CAST(DW_CHANGE_ID AS VARCHAR(MAX))      AS DW_CHANGE_ID,
                CAST(DEALER_TRADING_ID AS VARCHAR(MAX)) AS DEALER_TRADING_ID,
                CAST(BRANCH_TRADING_ID AS VARCHAR(MAX)) AS BRANCH_TRADING_ID
            INTO ' + @TgtFQN + '
            FROM ' + @SrcFQN + ';';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN

        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.SEQ_REP_ID           = CAST(src.SEQ_REP_ID AS INT),
                tgt.SC_REP_ID            = CAST(src.SC_REP_ID AS VARCHAR(MAX)),
                tgt.REP_TRADING_ID       = CAST(src.REP_TRADING_ID AS VARCHAR(MAX)),
                tgt.TITLE                = CAST(src.TITLE AS VARCHAR(MAX)),
                tgt.FIRST_NAME           = CAST(src.FIRST_NAME AS VARCHAR(MAX)),
                tgt.LAST_NAME            = CAST(src.LAST_NAME AS VARCHAR(MAX)),
                tgt.MIDDLE_INITIAL       = CAST(src.MIDDLE_INITIAL AS CHAR(1)),
                tgt.SUFFIX               = CAST(src.SUFFIX AS VARCHAR(MAX)),
                tgt.REP_ADDLINE1         = CAST(src.REP_ADDLINE1 AS VARCHAR(MAX)),
                tgt.REP_ADDLINE2         = CAST(src.REP_ADDLINE2 AS VARCHAR(MAX)),
                tgt.REP_ADDLINE3         = CAST(src.REP_ADDLINE3 AS VARCHAR(MAX)),
                tgt.REP_CITY             = CAST(src.REP_CITY AS VARCHAR(MAX)),
                tgt.REP_STATE            = CAST(src.REP_STATE AS VARCHAR(MAX)),
                tgt.REP_ZIPCODE          = CAST(src.REP_ZIPCODE AS VARCHAR(MAX)),
                tgt.REP_PHONE            = CAST(src.REP_PHONE AS VARCHAR(MAX)),
                tgt.EFFECTIVE_DATE       = CAST(src.EFFECTIVE_DATE AS DATETIME2(6)),
                tgt.EXPIRATION_DATE      = CAST(src.EXPIRATION_DATE AS DATETIME2(6)),
                tgt.RECORD_STATUS        = CAST(src.RECORD_STATUS AS VARCHAR(MAX)),
                tgt.TLM                  = CAST(src.TLM AS DATETIME2(6)),
                tgt.ACTIVE_FLAG          = CAST(src.ACTIVE_FLAG AS CHAR(1)),
                tgt.CRD_NUMBER           = CAST(src.CRD_NUMBER AS VARCHAR(MAX)),
                tgt.REP_EMAIL            = CAST(src.REP_EMAIL AS VARCHAR(MAX)),
                tgt.DW_CHANGE_ID         = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                tgt.DEALER_TRADING_ID    = CAST(src.DEALER_TRADING_ID AS VARCHAR(MAX)),
                tgt.BRANCH_TRADING_ID    = CAST(src.BRANCH_TRADING_ID AS VARCHAR(MAX))
            FROM ' + @TgtFQN + ' tgt
            INNER JOIN ' + @SrcFQN + ' src
                ON tgt.REP_KEY = CAST(src.REP_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + '
            (
                REP_KEY, SEQ_REP_ID, SC_REP_ID, REP_TRADING_ID, TITLE, FIRST_NAME,
                LAST_NAME, MIDDLE_INITIAL, SUFFIX, REP_ADDLINE1, REP_ADDLINE2, REP_ADDLINE3,
                REP_CITY, REP_STATE, REP_ZIPCODE, REP_PHONE, EFFECTIVE_DATE, EXPIRATION_DATE,
                RECORD_STATUS, TLM, ACTIVE_FLAG, CRD_NUMBER, REP_EMAIL, DW_CHANGE_ID,
                DEALER_TRADING_ID, BRANCH_TRADING_ID
            )
            SELECT
                CAST(src.REP_KEY AS INT),
                CAST(src.SEQ_REP_ID AS INT),
                CAST(src.SC_REP_ID AS VARCHAR(MAX)),
                CAST(src.REP_TRADING_ID AS VARCHAR(MAX)),
                CAST(src.TITLE AS VARCHAR(MAX)),
                CAST(src.FIRST_NAME AS VARCHAR(MAX)),
                CAST(src.LAST_NAME AS VARCHAR(MAX)),
                CAST(src.MIDDLE_INITIAL AS CHAR(1)),
                CAST(src.SUFFIX AS VARCHAR(MAX)),
                CAST(src.REP_ADDLINE1 AS VARCHAR(MAX)),
                CAST(src.REP_ADDLINE2 AS VARCHAR(MAX)),
                CAST(src.REP_ADDLINE3 AS VARCHAR(MAX)),
                CAST(src.REP_CITY AS VARCHAR(MAX)),
                CAST(src.REP_STATE AS VARCHAR(MAX)),
                CAST(src.REP_ZIPCODE AS VARCHAR(MAX)),
                CAST(src.REP_PHONE AS VARCHAR(MAX)),
                CAST(src.EFFECTIVE_DATE AS DATETIME2(6)),
                CAST(src.EXPIRATION_DATE AS DATETIME2(6)),
                CAST(src.RECORD_STATUS AS VARCHAR(MAX)),
                CAST(src.TLM AS DATETIME2(6)),
                CAST(src.ACTIVE_FLAG AS CHAR(1)),
                CAST(src.CRD_NUMBER AS VARCHAR(MAX)),
                CAST(src.REP_EMAIL AS VARCHAR(MAX)),
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                CAST(src.DEALER_TRADING_ID AS VARCHAR(MAX)),
                CAST(src.BRANCH_TRADING_ID AS VARCHAR(MAX))
            FROM ' + @SrcFQN + ' src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + ' tgt
                WHERE tgt.REP_KEY = CAST(src.REP_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 20. T_F_ORGANIZATION_ACCOUNT
-- NOTE: composite join key (no single surrogate key on this fact table)
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;
SET @TableExists = 0;

SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' +
    QUOTENAME(@StageSchemaName) + '.' +
    QUOTENAME('T_F_ORGANIZATION_ACCOUNT');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' +
    QUOTENAME('T_F_ORGANIZATION_ACCOUNT');

SET @TgtObjectId = @TargetSchemaName + '.T_F_ORGANIZATION_ACCOUNT';

BEGIN TRY

    IF OBJECT_ID(@TgtObjectId, 'U') IS NOT NULL
        SET @TableExists = 1;

    

    IF @TableExists = 0
    BEGIN

        SET @SQL = N'
            SELECT
                CAST(DW_ETL_JOB_ID AS INT)                          AS DW_ETL_JOB_ID,
                CAST(ACCOUNT_PROFILE_KEY AS INT)                    AS ACCOUNT_PROFILE_KEY,
                CAST(ACCOUNT_KEY AS INT)                            AS ACCOUNT_KEY,
                CAST(ORGANIZATION_TYPE_KEY AS INT)                  AS ORGANIZATION_TYPE_KEY,
                CAST(ORGANIZATION_STATUS_KEY AS INT)                AS ORGANIZATION_STATUS_KEY,
                CAST(EFFECTIVE_TIME_KEY AS INT)                     AS EFFECTIVE_TIME_KEY,
                CAST(ORGANIZATION_KEY AS INT)                       AS ORGANIZATION_KEY,
                CAST(PLAN_KEY AS INT)                               AS PLAN_KEY,
                CAST(AUTH_INDIV_TYPE_CODE_DESCR AS VARCHAR(MAX))    AS AUTH_INDIV_TYPE_CODE_DESCR,
                CAST(ORGANIZATION_TYPE_DESCR AS VARCHAR(MAX))       AS ORGANIZATION_TYPE_DESCR,
                CAST(ORGANIZATION_STATUS_DESCR AS VARCHAR(MAX))     AS ORGANIZATION_STATUS_DESCR,
                CAST(ORGANIZATION_TYPE_CODE AS VARCHAR(MAX))        AS ORGANIZATION_TYPE_CODE,
                CAST(ORGANIZATION_STATUS_CODE AS VARCHAR(MAX))      AS ORGANIZATION_STATUS_CODE,
                CAST(DW_CHANGE_ID AS VARCHAR(MAX))                  AS DW_CHANGE_ID,
                DW_UPD_DTTM,
                DW_INS_DTTM,
                CAST(END_DATE AS DATE)                              AS END_DATE,
                CAST(EFFECTIVE_DATE AS DATE)                        AS EFFECTIVE_DATE
            INTO ' + @TgtFQN + '
            FROM ' + @SrcFQN + ';';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN

        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.DW_ETL_JOB_ID               = CAST(src.DW_ETL_JOB_ID AS INT),
                tgt.ORGANIZATION_TYPE_KEY        = CAST(src.ORGANIZATION_TYPE_KEY AS INT),
                tgt.ORGANIZATION_STATUS_KEY      = CAST(src.ORGANIZATION_STATUS_KEY AS INT),
                tgt.EFFECTIVE_TIME_KEY           = CAST(src.EFFECTIVE_TIME_KEY AS INT),
                tgt.PLAN_KEY                     = CAST(src.PLAN_KEY AS INT),
                tgt.AUTH_INDIV_TYPE_CODE_DESCR   = CAST(src.AUTH_INDIV_TYPE_CODE_DESCR AS VARCHAR(MAX)),
                tgt.ORGANIZATION_TYPE_DESCR      = CAST(src.ORGANIZATION_TYPE_DESCR AS VARCHAR(MAX)),
                tgt.ORGANIZATION_STATUS_DESCR    = CAST(src.ORGANIZATION_STATUS_DESCR AS VARCHAR(MAX)),
                tgt.ORGANIZATION_TYPE_CODE       = CAST(src.ORGANIZATION_TYPE_CODE AS VARCHAR(MAX)),
                tgt.ORGANIZATION_STATUS_CODE     = CAST(src.ORGANIZATION_STATUS_CODE AS VARCHAR(MAX)),
                tgt.DW_CHANGE_ID                 = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                tgt.DW_UPD_DTTM                  = src.DW_UPD_DTTM,
                tgt.DW_INS_DTTM                  = src.DW_INS_DTTM,
                tgt.END_DATE                     = CAST(src.END_DATE AS DATE)
            FROM ' + @TgtFQN + ' tgt
            INNER JOIN ' + @SrcFQN + ' src
                ON tgt.ORGANIZATION_KEY      = CAST(src.ORGANIZATION_KEY AS INT)
               AND tgt.ACCOUNT_PROFILE_KEY  = CAST(src.ACCOUNT_PROFILE_KEY AS INT)
               AND tgt.ACCOUNT_KEY          = CAST(src.ACCOUNT_KEY AS INT)
               AND tgt.EFFECTIVE_DATE       = CAST(src.EFFECTIVE_DATE AS DATE);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + '
            (
                DW_ETL_JOB_ID, ACCOUNT_PROFILE_KEY, ACCOUNT_KEY, ORGANIZATION_TYPE_KEY,
                ORGANIZATION_STATUS_KEY, EFFECTIVE_TIME_KEY, ORGANIZATION_KEY, PLAN_KEY,
                AUTH_INDIV_TYPE_CODE_DESCR, ORGANIZATION_TYPE_DESCR, ORGANIZATION_STATUS_DESCR,
                ORGANIZATION_TYPE_CODE, ORGANIZATION_STATUS_CODE, DW_CHANGE_ID,
                DW_UPD_DTTM, DW_INS_DTTM, END_DATE, EFFECTIVE_DATE
            )
            SELECT
                CAST(src.DW_ETL_JOB_ID AS INT),
                CAST(src.ACCOUNT_PROFILE_KEY AS INT),
                CAST(src.ACCOUNT_KEY AS INT),
                CAST(src.ORGANIZATION_TYPE_KEY AS INT),
                CAST(src.ORGANIZATION_STATUS_KEY AS INT),
                CAST(src.EFFECTIVE_TIME_KEY AS INT),
                CAST(src.ORGANIZATION_KEY AS INT),
                CAST(src.PLAN_KEY AS INT),
                CAST(src.AUTH_INDIV_TYPE_CODE_DESCR AS VARCHAR(MAX)),
                CAST(src.ORGANIZATION_TYPE_DESCR AS VARCHAR(MAX)),
                CAST(src.ORGANIZATION_STATUS_DESCR AS VARCHAR(MAX)),
                CAST(src.ORGANIZATION_TYPE_CODE AS VARCHAR(MAX)),
                CAST(src.ORGANIZATION_STATUS_CODE AS VARCHAR(MAX)),
                CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM,
                CAST(src.END_DATE AS DATE),
                CAST(src.EFFECTIVE_DATE AS DATE)
            FROM ' + @SrcFQN + ' src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + ' tgt
                WHERE tgt.ORGANIZATION_KEY     = CAST(src.ORGANIZATION_KEY AS INT)
                  AND tgt.ACCOUNT_PROFILE_KEY = CAST(src.ACCOUNT_PROFILE_KEY AS INT)
                  AND tgt.ACCOUNT_KEY         = CAST(src.ACCOUNT_KEY AS INT)
                  AND tgt.EFFECTIVE_DATE      = CAST(src.EFFECTIVE_DATE AS DATE)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 21. T_F_ORGANIZATION_MEMBER_AFFILIATION
-- NOTE: composite join key (ORGANIZATION_KEY + PROFILE_KEY + EFFECTIVE_DTTM)
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;
SET @TableExists = 0;

SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' +
    QUOTENAME(@StageSchemaName) + '.' +
    QUOTENAME('T_F_ORGANIZATION_MEMBER_AFFILIATION');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' +
    QUOTENAME('T_F_ORGANIZATION_MEMBER_AFFILIATION');

SET @TgtObjectId = @TargetSchemaName + '.T_F_ORGANIZATION_MEMBER_AFFILIATION';

BEGIN TRY

    IF OBJECT_ID(@TgtObjectId, 'U') IS NOT NULL
        SET @TableExists = 1;

    

    IF @TableExists = 0
    BEGIN

        SET @SQL = N'
            SELECT
                CAST(MEMBER_STATUS_KEY AS INT)               AS MEMBER_STATUS_KEY,
                CAST(SEC_ROLE_TYPE_KEY AS INT)                AS SEC_ROLE_TYPE_KEY,
                CAST(MEMBER_PERM_TYPE_KEY AS INT)             AS MEMBER_PERM_TYPE_KEY,
                CAST(MEMBER_ROLE_TYPE_KEY AS INT)             AS MEMBER_ROLE_TYPE_KEY,
                CAST(DW_ETL_JOB_ID AS INT)                    AS DW_ETL_JOB_ID,
                CAST(EFFECTIVE_TIME_KEY AS INT)               AS EFFECTIVE_TIME_KEY,
                CAST(PROFILE_KEY AS INT)                      AS PROFILE_KEY,
                CAST(ORGANIZATION_KEY AS INT)                 AS ORGANIZATION_KEY,
                CAST(PLAN_KEY AS INT)                         AS PLAN_KEY,
                EFFECTIVE_DTTM,
                CAST(SEC_ROLE_TYPE_DESCR AS VARCHAR(MAX))     AS SEC_ROLE_TYPE_DESCR,
                CAST(MEMBER_PERM_TYPE_DESCR AS VARCHAR(MAX))  AS MEMBER_PERM_TYPE_DESCR,
                CAST(MEMBER_ROLE_TYPE_DESCR AS VARCHAR(MAX))  AS MEMBER_ROLE_TYPE_DESCR,
                CAST(DW_CHANGE_ID AS VARCHAR(MAX))            AS DW_CHANGE_ID,
                CAST(MEMBER_STATUS_DESCR AS VARCHAR(MAX))     AS MEMBER_STATUS_DESCR,
                CAST(MEMBER_STATUS_CODE AS VARCHAR(MAX))      AS MEMBER_STATUS_CODE,
                CAST(SEC_ROLE_TYPE_CODE AS VARCHAR(MAX))      AS SEC_ROLE_TYPE_CODE,
                CAST(MEMBER_PERM_TYPE_CODE AS VARCHAR(MAX))   AS MEMBER_PERM_TYPE_CODE,
                CAST(MEMBER_ROLE_TYPE_CODE AS VARCHAR(MAX))   AS MEMBER_ROLE_TYPE_CODE,
                DW_UPD_DTTM,
                DW_INS_DTTM,
                END_DTTM,
                CAST(SEQ_PERSON_ID AS INT)                    AS SEQ_PERSON_ID,
                CAST(UII_MEMBER_ID AS INT)                    AS UII_MEMBER_ID,
                CAST(SEQ_ORG_ID AS INT)                       AS SEQ_ORG_ID
            INTO ' + @TgtFQN + '
            FROM ' + @SrcFQN + ';';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN

        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.MEMBER_STATUS_KEY       = CAST(src.MEMBER_STATUS_KEY AS INT),
                tgt.SEC_ROLE_TYPE_KEY       = CAST(src.SEC_ROLE_TYPE_KEY AS INT),
                tgt.MEMBER_PERM_TYPE_KEY    = CAST(src.MEMBER_PERM_TYPE_KEY AS INT),
                tgt.MEMBER_ROLE_TYPE_KEY    = CAST(src.MEMBER_ROLE_TYPE_KEY AS INT),
                tgt.DW_ETL_JOB_ID           = CAST(src.DW_ETL_JOB_ID AS INT),
                tgt.EFFECTIVE_TIME_KEY      = CAST(src.EFFECTIVE_TIME_KEY AS INT),
                tgt.PLAN_KEY                = CAST(src.PLAN_KEY AS INT),
                tgt.SEC_ROLE_TYPE_DESCR     = CAST(src.SEC_ROLE_TYPE_DESCR AS VARCHAR(MAX)),
                tgt.MEMBER_PERM_TYPE_DESCR  = CAST(src.MEMBER_PERM_TYPE_DESCR AS VARCHAR(MAX)),
                tgt.MEMBER_ROLE_TYPE_DESCR  = CAST(src.MEMBER_ROLE_TYPE_DESCR AS VARCHAR(MAX)),
                tgt.DW_CHANGE_ID            = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                tgt.MEMBER_STATUS_DESCR     = CAST(src.MEMBER_STATUS_DESCR AS VARCHAR(MAX)),
                tgt.MEMBER_STATUS_CODE      = CAST(src.MEMBER_STATUS_CODE AS VARCHAR(MAX)),
                tgt.SEC_ROLE_TYPE_CODE      = CAST(src.SEC_ROLE_TYPE_CODE AS VARCHAR(MAX)),
                tgt.MEMBER_PERM_TYPE_CODE   = CAST(src.MEMBER_PERM_TYPE_CODE AS VARCHAR(MAX)),
                tgt.MEMBER_ROLE_TYPE_CODE   = CAST(src.MEMBER_ROLE_TYPE_CODE AS VARCHAR(MAX)),
                tgt.DW_UPD_DTTM             = src.DW_UPD_DTTM,
                tgt.DW_INS_DTTM             = src.DW_INS_DTTM,
                tgt.END_DTTM                = src.END_DTTM,
                tgt.SEQ_PERSON_ID           = CAST(src.SEQ_PERSON_ID AS INT),
                tgt.UII_MEMBER_ID           = CAST(src.UII_MEMBER_ID AS INT),
                tgt.SEQ_ORG_ID              = CAST(src.SEQ_ORG_ID AS INT)
            FROM ' + @TgtFQN + ' tgt
            INNER JOIN ' + @SrcFQN + ' src
                ON tgt.ORGANIZATION_KEY = CAST(src.ORGANIZATION_KEY AS INT)
               AND tgt.PROFILE_KEY      = CAST(src.PROFILE_KEY AS INT)
               AND tgt.EFFECTIVE_DTTM   = src.EFFECTIVE_DTTM;';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + '
            (
                MEMBER_STATUS_KEY, SEC_ROLE_TYPE_KEY, MEMBER_PERM_TYPE_KEY, MEMBER_ROLE_TYPE_KEY,
                DW_ETL_JOB_ID, EFFECTIVE_TIME_KEY, PROFILE_KEY, ORGANIZATION_KEY, PLAN_KEY,
                EFFECTIVE_DTTM, SEC_ROLE_TYPE_DESCR, MEMBER_PERM_TYPE_DESCR, MEMBER_ROLE_TYPE_DESCR,
                DW_CHANGE_ID, MEMBER_STATUS_DESCR, MEMBER_STATUS_CODE, SEC_ROLE_TYPE_CODE,
                MEMBER_PERM_TYPE_CODE, MEMBER_ROLE_TYPE_CODE, DW_UPD_DTTM, DW_INS_DTTM,
                END_DTTM, SEQ_PERSON_ID, UII_MEMBER_ID, SEQ_ORG_ID
            )
            SELECT
                CAST(MEMBER_STATUS_KEY AS INT),
                CAST(SEC_ROLE_TYPE_KEY AS INT),
                CAST(MEMBER_PERM_TYPE_KEY AS INT),
                CAST(MEMBER_ROLE_TYPE_KEY AS INT),
                CAST(DW_ETL_JOB_ID AS INT),
                CAST(EFFECTIVE_TIME_KEY AS INT),
                CAST(PROFILE_KEY AS INT),
                CAST(ORGANIZATION_KEY AS INT),
                CAST(PLAN_KEY AS INT),
                EFFECTIVE_DTTM,
                CAST(SEC_ROLE_TYPE_DESCR AS VARCHAR(MAX)),
                CAST(MEMBER_PERM_TYPE_DESCR AS VARCHAR(MAX)),
                CAST(MEMBER_ROLE_TYPE_DESCR AS VARCHAR(MAX)),
                CAST(DW_CHANGE_ID AS VARCHAR(MAX)),
                CAST(MEMBER_STATUS_DESCR AS VARCHAR(MAX)),
                CAST(MEMBER_STATUS_CODE AS VARCHAR(MAX)),
                CAST(SEC_ROLE_TYPE_CODE AS VARCHAR(MAX)),
                CAST(MEMBER_PERM_TYPE_CODE AS VARCHAR(MAX)),
                CAST(MEMBER_ROLE_TYPE_CODE AS VARCHAR(MAX)),
                DW_UPD_DTTM,
                DW_INS_DTTM,
                END_DTTM,
                CAST(SEQ_PERSON_ID AS INT),
                CAST(UII_MEMBER_ID AS INT),
                CAST(SEQ_ORG_ID AS INT)
            FROM ' + @SrcFQN + ' src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + ' tgt
                WHERE tgt.ORGANIZATION_KEY = CAST(src.ORGANIZATION_KEY AS INT)
                  AND tgt.PROFILE_KEY      = CAST(src.PROFILE_KEY AS INT)
                  AND tgt.EFFECTIVE_DTTM   = src.EFFECTIVE_DTTM
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 22. T_F_POOL_ACCOUNT_ASSETS
-- NOTE: composite join key (ACCOUNT_KEY + TIME_KEY)
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;
SET @TableExists = 0;

SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' +
    QUOTENAME(@StageSchemaName) + '.' +
    QUOTENAME('T_F_POOL_ACCOUNT_ASSETS');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' +
    QUOTENAME('T_F_POOL_ACCOUNT_ASSETS');

SET @TgtObjectId = @TargetSchemaName + '.T_F_POOL_ACCOUNT_ASSETS';

BEGIN TRY

    IF OBJECT_ID(@TgtObjectId, 'U') IS NOT NULL
        SET @TableExists = 1;

    

    IF @TableExists = 0
    BEGIN

        SET @SQL = N'
            SELECT
                CAST(ETL_JOB_ID AS INT)              AS ETL_JOB_ID,
                CAST(ACCOUNT_PROFILE_KEY AS INT)     AS ACCOUNT_PROFILE_KEY,
                CAST(TIME_KEY AS INT)                AS TIME_KEY,
                CAST(ACCOUNT_KEY AS INT)             AS ACCOUNT_KEY,
                CAST(PLAN_KEY AS INT)                AS PLAN_KEY,
                CAST(DW_CHANGE_ID AS VARCHAR(MAX))   AS DW_CHANGE_ID,
                DW_UPD_DTTM,
                DW_INS_DTTM,
                CAST(TOTAL_SHARES AS FLOAT)          AS TOTAL_SHARES,
                CAST(TOTAL_ASSETS AS FLOAT)          AS TOTAL_ASSETS
            INTO ' + @TgtFQN + '
            FROM ' + @SrcFQN + ';';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN

        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.ETL_JOB_ID            = CAST(src.ETL_JOB_ID AS INT),
                tgt.ACCOUNT_PROFILE_KEY   = CAST(src.ACCOUNT_PROFILE_KEY AS INT),
                tgt.PLAN_KEY              = CAST(src.PLAN_KEY AS INT),
                tgt.DW_CHANGE_ID          = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
                tgt.DW_UPD_DTTM           = src.DW_UPD_DTTM,
                tgt.DW_INS_DTTM           = src.DW_INS_DTTM,
                tgt.TOTAL_SHARES          = CAST(src.TOTAL_SHARES AS FLOAT),
                tgt.TOTAL_ASSETS          = CAST(src.TOTAL_ASSETS AS FLOAT)
            FROM ' + @TgtFQN + ' tgt
            INNER JOIN ' + @SrcFQN + ' src
                ON tgt.ACCOUNT_KEY = CAST(src.ACCOUNT_KEY AS INT)
               AND tgt.TIME_KEY    = CAST(src.TIME_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + '
            (
                ETL_JOB_ID, ACCOUNT_PROFILE_KEY, TIME_KEY, ACCOUNT_KEY, PLAN_KEY,
                DW_CHANGE_ID, DW_UPD_DTTM, DW_INS_DTTM, TOTAL_SHARES, TOTAL_ASSETS
            )
            SELECT
                CAST(ETL_JOB_ID AS INT),
                CAST(ACCOUNT_PROFILE_KEY AS INT),
                CAST(TIME_KEY AS INT),
                CAST(ACCOUNT_KEY AS INT),
                CAST(PLAN_KEY AS INT),
                CAST(DW_CHANGE_ID AS VARCHAR(MAX)),
                DW_UPD_DTTM,
                DW_INS_DTTM,
                CAST(TOTAL_SHARES AS FLOAT),
                CAST(TOTAL_ASSETS AS FLOAT)
            FROM ' + @SrcFQN + ' src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + ' tgt
                WHERE tgt.ACCOUNT_KEY = CAST(src.ACCOUNT_KEY AS INT)
                  AND tgt.TIME_KEY    = CAST(src.TIME_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 23. V_ACCOUNT_SUMMARY_AAV2
-- NOTE: this is a view. Uses SYSNAME-typed name variables and T/S aliases.
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;

SET @TableExists = 0;

SET @SrcFQN = NULL;
SET @TgtFQN = NULL;
SET @TgtObjectId = NULL;

SET @SrcFQN =
      QUOTENAME(@WarehouseName)
    + '.' + QUOTENAME(@StageSchemaName)
    + '.' + QUOTENAME('V_ACCOUNT_SUMMARY_AAV2');

SET @TgtFQN =
      QUOTENAME(@TargetSchemaName)
    + '.' + QUOTENAME('V_ACCOUNT_SUMMARY_AAV2');

SET @TgtObjectId =
      QUOTENAME(@TargetSchemaName)
    + '.' + QUOTENAME('V_ACCOUNT_SUMMARY_AAV2');

SET @TableName = 'V_ACCOUNT_SUMMARY_AAV2';

BEGIN TRY

    IF OBJECT_ID(@TgtObjectId, 'U') IS NOT NULL
        SET @TableExists = 1;

    IF @TableExists = 0
    BEGIN

        SET @SQL = N'
            SELECT
                CAST(PLAN_KEY AS INT) AS PLAN_KEY,
                CAST(ACCOUNT_PROFILE_KEY AS INT) AS ACCOUNT_PROFILE_KEY,
                CAST(ACCOUNT_OWNER_AGE AS INT) AS ACCOUNT_OWNER_AGE,
                CAST(BENE_AGE AS INT) AS BENE_AGE
            INTO ' + @TgtFQN + N'
            FROM ' + @SrcFQN + N';';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END
    ELSE
    BEGIN

        SET @SQL = N'
            UPDATE T
            SET T.PLAN_KEY = CAST(S.PLAN_KEY AS INT),
                T.ACCOUNT_OWNER_AGE = CAST(S.ACCOUNT_OWNER_AGE AS INT),
                T.BENE_AGE = CAST(S.BENE_AGE AS INT)
            FROM ' + @TgtFQN + N' T
            INNER JOIN ' + @SrcFQN + N' S
                ON T.ACCOUNT_PROFILE_KEY =
                   CAST(S.ACCOUNT_PROFILE_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + N'
            (
                PLAN_KEY,
                ACCOUNT_PROFILE_KEY,
                ACCOUNT_OWNER_AGE,
                BENE_AGE
            )
            SELECT
                CAST(S.PLAN_KEY AS INT),
                CAST(S.ACCOUNT_PROFILE_KEY AS INT),
                CAST(S.ACCOUNT_OWNER_AGE AS INT),
                CAST(S.BENE_AGE AS INT)
            FROM ' + @SrcFQN + N' S
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + N' T
                WHERE T.ACCOUNT_PROFILE_KEY =
                      CAST(S.ACCOUNT_PROFILE_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END;

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 24. V_T_D_FUND
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;
SET @TableExists = 0;

SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' +
    QUOTENAME(@StageSchemaName) + '.' +
    QUOTENAME('V_T_D_FUND');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' +
    QUOTENAME('V_T_D_FUND');

SET @TgtObjectId = @TargetSchemaName + '.V_T_D_FUND';

BEGIN TRY

    IF OBJECT_ID(@TgtObjectId, 'U') IS NOT NULL
        SET @TableExists = 1;

    

    IF @TableExists = 0
    BEGIN

        SET @SQL = N'
            SELECT
                CAST(PLAN_KEY AS INT)                           AS PLAN_KEY,
                CAST(FUND_KEY AS INT)                           AS FUND_KEY,
                CAST(CDSC_COMMISSION AS DECIMAL(18,4))          AS CDSC_COMMISSION,
                CAST(SALES_COMMISSION AS DECIMAL(18,4))         AS SALES_COMMISSION,
                CAST(CDSC_PERIOD AS INT)                        AS CDSC_PERIOD,
                CAST(TLM AS DATETIME2(6))                       AS TLM,
                CAST(INCEPTION_DATE AS DATE)                    AS INCEPTION_DATE,
                CAST(ALLOWS_NEW_INVESTMENT AS CHAR(1))          AS ALLOWS_NEW_INVESTMENT,
                CAST(FUND_TYPE AS CHAR(1))                      AS FUND_TYPE,
                CAST(FUND_NAME_GROUPING AS VARCHAR(MAX))        AS FUND_NAME_GROUPING,
                CAST(FUND_NAME AS VARCHAR(MAX))                 AS FUND_NAME,
                CAST(FUND_MANAGER_NAME AS VARCHAR(MAX))         AS FUND_MANAGER_NAME,
                CAST(FUND_DESC AS VARCHAR(MAX))                 AS FUND_DESC,
                CAST(ENROLL_DESC AS VARCHAR(MAX))               AS ENROLL_DESC,
                CAST(CUSIP AS VARCHAR(MAX))                     AS CUSIP,
                CAST(OMNI_FUND_ID AS VARCHAR(MAX))              AS OMNI_FUND_ID,
                CAST(DST_CUSIP AS VARCHAR(MAX))                 AS DST_CUSIP,
                CAST(PRICE_ID AS VARCHAR(MAX))                  AS PRICE_ID,
                CAST(VENDOR_PRICE_ID AS VARCHAR(MAX))           AS VENDOR_PRICE_ID,
                CAST(ASSET_CLASS AS VARCHAR(MAX))               AS ASSET_CLASS,
                CAST(FUND_SHORT_NAME AS VARCHAR(MAX))           AS FUND_SHORT_NAME,
                CAST(TRAUNCH_ID AS VARCHAR(MAX))                AS TRAUNCH_ID,
                CAST(CUSTODIAN_ACCOUNT_NUMBER AS VARCHAR(MAX))  AS CUSTODIAN_ACCOUNT_NUMBER,
                CAST(TRADING_PARTNER AS VARCHAR(MAX))           AS TRADING_PARTNER,
                CAST(PARTNER_FUND_ID AS VARCHAR(MAX))           AS PARTNER_FUND_ID,
                CAST(FUND_TYPE_DESC AS VARCHAR(MAX))            AS FUND_TYPE_DESC,
                CAST(CLASSIFICATION AS VARCHAR(MAX))            AS CLASSIFICATION,
                CAST(CATEGORY AS VARCHAR(MAX))                  AS CATEGORY,
                CAST(CLASS_SUBTYPE AS VARCHAR(MAX))             AS CLASS_SUBTYPE,
                CAST(CLASS_TYPE AS VARCHAR(MAX))                AS CLASS_TYPE,
                CAST(FUND_ID AS INT)                            AS FUND_ID
            INTO ' + @TgtFQN + '
            FROM ' + @SrcFQN + ';';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN

        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.PLAN_KEY                   = CAST(src.PLAN_KEY AS INT),
                tgt.CDSC_COMMISSION             = CAST(src.CDSC_COMMISSION AS DECIMAL(18,4)),
                tgt.SALES_COMMISSION            = CAST(src.SALES_COMMISSION AS DECIMAL(18,4)),
                tgt.CDSC_PERIOD                 = CAST(src.CDSC_PERIOD AS INT),
                tgt.TLM                         = CAST(src.TLM AS DATETIME2(6)),
                tgt.INCEPTION_DATE              = CAST(src.INCEPTION_DATE AS DATE),
                tgt.ALLOWS_NEW_INVESTMENT       = CAST(src.ALLOWS_NEW_INVESTMENT AS CHAR(1)),
                tgt.FUND_TYPE                   = CAST(src.FUND_TYPE AS CHAR(1)),
                tgt.FUND_NAME_GROUPING          = CAST(src.FUND_NAME_GROUPING AS VARCHAR(MAX)),
                tgt.FUND_NAME                   = CAST(src.FUND_NAME AS VARCHAR(MAX)),
                tgt.FUND_MANAGER_NAME           = CAST(src.FUND_MANAGER_NAME AS VARCHAR(MAX)),
                tgt.FUND_DESC                   = CAST(src.FUND_DESC AS VARCHAR(MAX)),
                tgt.ENROLL_DESC                 = CAST(src.ENROLL_DESC AS VARCHAR(MAX)),
                tgt.CUSIP                       = CAST(src.CUSIP AS VARCHAR(MAX)),
                tgt.OMNI_FUND_ID                = CAST(src.OMNI_FUND_ID AS VARCHAR(MAX)),
                tgt.DST_CUSIP                   = CAST(src.DST_CUSIP AS VARCHAR(MAX)),
                tgt.PRICE_ID                    = CAST(src.PRICE_ID AS VARCHAR(MAX)),
                tgt.VENDOR_PRICE_ID             = CAST(src.VENDOR_PRICE_ID AS VARCHAR(MAX)),
                tgt.ASSET_CLASS                 = CAST(src.ASSET_CLASS AS VARCHAR(MAX)),
                tgt.FUND_SHORT_NAME             = CAST(src.FUND_SHORT_NAME AS VARCHAR(MAX)),
                tgt.TRAUNCH_ID                  = CAST(src.TRAUNCH_ID AS VARCHAR(MAX)),
                tgt.CUSTODIAN_ACCOUNT_NUMBER    = CAST(src.CUSTODIAN_ACCOUNT_NUMBER AS VARCHAR(MAX)),
                tgt.TRADING_PARTNER             = CAST(src.TRADING_PARTNER AS VARCHAR(MAX)),
                tgt.PARTNER_FUND_ID             = CAST(src.PARTNER_FUND_ID AS VARCHAR(MAX)),
                tgt.FUND_TYPE_DESC              = CAST(src.FUND_TYPE_DESC AS VARCHAR(MAX)),
                tgt.CLASSIFICATION              = CAST(src.CLASSIFICATION AS VARCHAR(MAX)),
                tgt.CATEGORY                    = CAST(src.CATEGORY AS VARCHAR(MAX)),
                tgt.CLASS_SUBTYPE               = CAST(src.CLASS_SUBTYPE AS VARCHAR(MAX)),
                tgt.CLASS_TYPE                  = CAST(src.CLASS_TYPE AS VARCHAR(MAX)),
                tgt.FUND_ID                     = CAST(src.FUND_ID AS INT)
            FROM ' + @TgtFQN + ' tgt
            INNER JOIN ' + @SrcFQN + ' src
                ON tgt.FUND_KEY = CAST(src.FUND_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + '
            (
                PLAN_KEY, FUND_KEY, CDSC_COMMISSION, SALES_COMMISSION, CDSC_PERIOD,
                TLM, INCEPTION_DATE, ALLOWS_NEW_INVESTMENT, FUND_TYPE, FUND_NAME_GROUPING,
                FUND_NAME, FUND_MANAGER_NAME, FUND_DESC, ENROLL_DESC, CUSIP,
                OMNI_FUND_ID, DST_CUSIP, PRICE_ID, VENDOR_PRICE_ID, ASSET_CLASS,
                FUND_SHORT_NAME, TRAUNCH_ID, CUSTODIAN_ACCOUNT_NUMBER, TRADING_PARTNER,
                PARTNER_FUND_ID, FUND_TYPE_DESC, CLASSIFICATION, CATEGORY,
                CLASS_SUBTYPE, CLASS_TYPE, FUND_ID
            )
            SELECT
                CAST(src.PLAN_KEY AS INT),
                CAST(src.FUND_KEY AS INT),
                CAST(src.CDSC_COMMISSION AS DECIMAL(18,4)),
                CAST(src.SALES_COMMISSION AS DECIMAL(18,4)),
                CAST(src.CDSC_PERIOD AS INT),
                CAST(src.TLM AS DATETIME2(6)),
                CAST(src.INCEPTION_DATE AS DATE),
                CAST(src.ALLOWS_NEW_INVESTMENT AS CHAR(1)),
                CAST(src.FUND_TYPE AS CHAR(1)),
                CAST(src.FUND_NAME_GROUPING AS VARCHAR(MAX)),
                CAST(src.FUND_NAME AS VARCHAR(MAX)),
                CAST(src.FUND_MANAGER_NAME AS VARCHAR(MAX)),
                CAST(src.FUND_DESC AS VARCHAR(MAX)),
                CAST(src.ENROLL_DESC AS VARCHAR(MAX)),
                CAST(src.CUSIP AS VARCHAR(MAX)),
                CAST(src.OMNI_FUND_ID AS VARCHAR(MAX)),
                CAST(src.DST_CUSIP AS VARCHAR(MAX)),
                CAST(src.PRICE_ID AS VARCHAR(MAX)),
                CAST(src.VENDOR_PRICE_ID AS VARCHAR(MAX)),
                CAST(src.ASSET_CLASS AS VARCHAR(MAX)),
                CAST(src.FUND_SHORT_NAME AS VARCHAR(MAX)),
                CAST(src.TRAUNCH_ID AS VARCHAR(MAX)),
                CAST(src.CUSTODIAN_ACCOUNT_NUMBER AS VARCHAR(MAX)),
                CAST(src.TRADING_PARTNER AS VARCHAR(MAX)),
                CAST(src.PARTNER_FUND_ID AS VARCHAR(MAX)),
                CAST(src.FUND_TYPE_DESC AS VARCHAR(MAX)),
                CAST(src.CLASSIFICATION AS VARCHAR(MAX)),
                CAST(src.CATEGORY AS VARCHAR(MAX)),
                CAST(src.CLASS_SUBTYPE AS VARCHAR(MAX)),
                CAST(src.CLASS_TYPE AS VARCHAR(MAX)),
                CAST(src.FUND_ID AS INT)
            FROM ' + @SrcFQN + ' src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + ' tgt
                WHERE tgt.FUND_KEY = CAST(src.FUND_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 25. V_T_D_ORGANIZATION_BI
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;
SET @TableExists = 0;

SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' +
    QUOTENAME(@StageSchemaName) + '.' +
    QUOTENAME('V_T_D_ORGANIZATION_BI');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' +
    QUOTENAME('V_T_D_ORGANIZATION_BI');

SET @TgtObjectId = @TargetSchemaName + '.V_T_D_ORGANIZATION_BI';

BEGIN TRY

    IF OBJECT_ID(@TgtObjectId, 'U') IS NOT NULL
        SET @TableExists = 1;

    

    IF @TableExists = 0
    BEGIN

        SET @SQL = N'
            SELECT
                CAST(PLAN_KEY AS INT)                        AS PLAN_KEY,
                CAST(ORGANIZATION_KEY AS INT)                AS ORGANIZATION_KEY,
                CAST(ORGANIZATION_STATUS_KEY AS INT)         AS ORGANIZATION_STATUS_KEY,
                CAST(ORGANIZATION_TYPE_KEY AS INT)           AS ORGANIZATION_TYPE_KEY,
                CAST(APPROVAL_TIME_KEY AS INT)                AS APPROVAL_TIME_KEY,
                CAST(SUBM_TIME_KEY AS INT)                    AS SUBM_TIME_KEY,
                CAST(ORGANIZATION_STATUS_DESCR AS VARCHAR(MAX)) AS ORGANIZATION_STATUS_DESCR,
                CAST(ORGANIZATION_TYPE_DESCR AS VARCHAR(MAX))  AS ORGANIZATION_TYPE_DESCR,
                CAST(PLAN_NAME AS VARCHAR(MAX))                AS PLAN_NAME,
                CAST(ORGANIZATION_NAME AS VARCHAR(MAX))        AS ORGANIZATION_NAME,
                CAST(PERM_ADDLINE1 AS VARCHAR(MAX))            AS PERM_ADDLINE1,
                CAST(PERM_CITY AS VARCHAR(MAX))                AS PERM_CITY,
                CAST(EMAIL AS VARCHAR(MAX))                    AS EMAIL,
                CAST(ML_CITY AS VARCHAR(MAX))                  AS ML_CITY,
                CAST(ML_ADDLINE2 AS VARCHAR(MAX))              AS ML_ADDLINE2,
                CAST(PERM_ADDLINE2 AS VARCHAR(MAX))            AS PERM_ADDLINE2,
                CAST(ML_ADDLINE1 AS VARCHAR(MAX))              AS ML_ADDLINE1,
                CAST(ML_ZIPCODE AS VARCHAR(MAX))               AS ML_ZIPCODE,
                CAST(SOURCE_ORG_ID AS VARCHAR(MAX))            AS SOURCE_ORG_ID,
                CAST(ORGANIZATION_TYPE_CODE AS VARCHAR(MAX))   AS ORGANIZATION_TYPE_CODE,
                CAST(ML_STATELABEL AS VARCHAR(MAX))            AS ML_STATELABEL,
                CAST(TRAUNCH_ID AS VARCHAR(MAX))               AS TRAUNCH_ID,
                CAST(PERM_STATELABEL AS VARCHAR(MAX))          AS PERM_STATELABEL,
                CAST(PERM_ZIPCODE AS VARCHAR(MAX))             AS PERM_ZIPCODE,
                CAST(MAIN_PHONE AS VARCHAR(MAX))               AS MAIN_PHONE,
                CAST(ORGANIZATION_STATUS_CODE AS VARCHAR(MAX)) AS ORGANIZATION_STATUS_CODE,
                CAST(APPROVAL_DATE AS DATETIME2(6))            AS APPROVAL_DATE,
                DW_UPD_DTTM,
                DW_INS_DTTM,
                CAST(SUBM_DATE AS DATETIME2(6))                AS SUBM_DATE,
                CAST(SEQ_ORG_ID AS INT)                        AS SEQ_ORG_ID
            INTO ' + @TgtFQN + '
            FROM ' + @SrcFQN + ';';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN

        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.PLAN_KEY                     = CAST(src.PLAN_KEY AS INT),
                tgt.ORGANIZATION_STATUS_KEY      = CAST(src.ORGANIZATION_STATUS_KEY AS INT),
                tgt.ORGANIZATION_TYPE_KEY        = CAST(src.ORGANIZATION_TYPE_KEY AS INT),
                tgt.APPROVAL_TIME_KEY             = CAST(src.APPROVAL_TIME_KEY AS INT),
                tgt.SUBM_TIME_KEY                 = CAST(src.SUBM_TIME_KEY AS INT),
                tgt.ORGANIZATION_STATUS_DESCR     = CAST(src.ORGANIZATION_STATUS_DESCR AS VARCHAR(MAX)),
                tgt.ORGANIZATION_TYPE_DESCR       = CAST(src.ORGANIZATION_TYPE_DESCR AS VARCHAR(MAX)),
                tgt.PLAN_NAME                     = CAST(src.PLAN_NAME AS VARCHAR(MAX)),
                tgt.ORGANIZATION_NAME             = CAST(src.ORGANIZATION_NAME AS VARCHAR(MAX)),
                tgt.PERM_ADDLINE1                 = CAST(src.PERM_ADDLINE1 AS VARCHAR(MAX)),
                tgt.PERM_CITY                     = CAST(src.PERM_CITY AS VARCHAR(MAX)),
                tgt.EMAIL                         = CAST(src.EMAIL AS VARCHAR(MAX)),
                tgt.ML_CITY                       = CAST(src.ML_CITY AS VARCHAR(MAX)),
                tgt.ML_ADDLINE2                   = CAST(src.ML_ADDLINE2 AS VARCHAR(MAX)),
                tgt.PERM_ADDLINE2                 = CAST(src.PERM_ADDLINE2 AS VARCHAR(MAX)),
                tgt.ML_ADDLINE1                   = CAST(src.ML_ADDLINE1 AS VARCHAR(MAX)),
                tgt.ML_ZIPCODE                    = CAST(src.ML_ZIPCODE AS VARCHAR(MAX)),
                tgt.SOURCE_ORG_ID                 = CAST(src.SOURCE_ORG_ID AS VARCHAR(MAX)),
                tgt.ORGANIZATION_TYPE_CODE        = CAST(src.ORGANIZATION_TYPE_CODE AS VARCHAR(MAX)),
                tgt.ML_STATELABEL                 = CAST(src.ML_STATELABEL AS VARCHAR(MAX)),
                tgt.TRAUNCH_ID                    = CAST(src.TRAUNCH_ID AS VARCHAR(MAX)),
                tgt.PERM_STATELABEL               = CAST(src.PERM_STATELABEL AS VARCHAR(MAX)),
                tgt.PERM_ZIPCODE                  = CAST(src.PERM_ZIPCODE AS VARCHAR(MAX)),
                tgt.MAIN_PHONE                    = CAST(src.MAIN_PHONE AS VARCHAR(MAX)),
                tgt.ORGANIZATION_STATUS_CODE      = CAST(src.ORGANIZATION_STATUS_CODE AS VARCHAR(MAX)),
                tgt.APPROVAL_DATE                 = CAST(src.APPROVAL_DATE AS DATETIME2(6)),
                tgt.DW_UPD_DTTM                    = src.DW_UPD_DTTM,
                tgt.DW_INS_DTTM                    = src.DW_INS_DTTM,
                tgt.SUBM_DATE                      = CAST(src.SUBM_DATE AS DATETIME2(6)),
                tgt.SEQ_ORG_ID                     = CAST(src.SEQ_ORG_ID AS INT)
            FROM ' + @TgtFQN + ' tgt
            INNER JOIN ' + @SrcFQN + ' src
                ON tgt.ORGANIZATION_KEY = CAST(src.ORGANIZATION_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + '
            (
                PLAN_KEY, ORGANIZATION_KEY, ORGANIZATION_STATUS_KEY, ORGANIZATION_TYPE_KEY,
                APPROVAL_TIME_KEY, SUBM_TIME_KEY, ORGANIZATION_STATUS_DESCR, ORGANIZATION_TYPE_DESCR,
                PLAN_NAME, ORGANIZATION_NAME, PERM_ADDLINE1, PERM_CITY, EMAIL, ML_CITY,
                ML_ADDLINE2, PERM_ADDLINE2, ML_ADDLINE1, ML_ZIPCODE, SOURCE_ORG_ID,
                ORGANIZATION_TYPE_CODE, ML_STATELABEL, TRAUNCH_ID, PERM_STATELABEL,
                PERM_ZIPCODE, MAIN_PHONE, ORGANIZATION_STATUS_CODE, APPROVAL_DATE,
                DW_UPD_DTTM, DW_INS_DTTM, SUBM_DATE, SEQ_ORG_ID
            )
            SELECT
                CAST(src.PLAN_KEY AS INT),
                CAST(src.ORGANIZATION_KEY AS INT),
                CAST(src.ORGANIZATION_STATUS_KEY AS INT),
                CAST(src.ORGANIZATION_TYPE_KEY AS INT),
                CAST(src.APPROVAL_TIME_KEY AS INT),
                CAST(src.SUBM_TIME_KEY AS INT),
                CAST(src.ORGANIZATION_STATUS_DESCR AS VARCHAR(MAX)),
                CAST(src.ORGANIZATION_TYPE_DESCR AS VARCHAR(MAX)),
                CAST(src.PLAN_NAME AS VARCHAR(MAX)),
                CAST(src.ORGANIZATION_NAME AS VARCHAR(MAX)),
                CAST(src.PERM_ADDLINE1 AS VARCHAR(MAX)),
                CAST(src.PERM_CITY AS VARCHAR(MAX)),
                CAST(src.EMAIL AS VARCHAR(MAX)),
                CAST(src.ML_CITY AS VARCHAR(MAX)),
                CAST(src.ML_ADDLINE2 AS VARCHAR(MAX)),
                CAST(src.PERM_ADDLINE2 AS VARCHAR(MAX)),
                CAST(src.ML_ADDLINE1 AS VARCHAR(MAX)),
                CAST(src.ML_ZIPCODE AS VARCHAR(MAX)),
                CAST(src.SOURCE_ORG_ID AS VARCHAR(MAX)),
                CAST(src.ORGANIZATION_TYPE_CODE AS VARCHAR(MAX)),
                CAST(src.ML_STATELABEL AS VARCHAR(MAX)),
                CAST(src.TRAUNCH_ID AS VARCHAR(MAX)),
                CAST(src.PERM_STATELABEL AS VARCHAR(MAX)),
                CAST(src.PERM_ZIPCODE AS VARCHAR(MAX)),
                CAST(src.MAIN_PHONE AS VARCHAR(MAX)),
                CAST(src.ORGANIZATION_STATUS_CODE AS VARCHAR(MAX)),
                CAST(src.APPROVAL_DATE AS DATETIME2(6)),
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM,
                CAST(src.SUBM_DATE AS DATETIME2(6)),
                CAST(src.SEQ_ORG_ID AS INT)
            FROM ' + @SrcFQN + ' src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + ' tgt
                WHERE tgt.ORGANIZATION_KEY = CAST(src.ORGANIZATION_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 26. V_T_D_PROFILE_NP
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;
SET @TableExists = 0;

SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' +
    QUOTENAME(@StageSchemaName) + '.' +
    QUOTENAME('V_T_D_PROFILE_NP');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' +
    QUOTENAME('V_T_D_PROFILE_NP');

SET @TgtObjectId = @TargetSchemaName + '.V_T_D_PROFILE_NP';

BEGIN TRY

    IF OBJECT_ID(@TgtObjectId, 'U') IS NOT NULL
        SET @TableExists = 1;

    

    IF @TableExists = 0
    BEGIN

        SET @SQL = N'
            SELECT
                CAST(PROFILE_KEY AS BIGINT)          AS PROFILE_KEY,
                CAST(PERM_ZIPCODE AS VARCHAR(MAX))   AS PERM_ZIPCODE,
                CAST(ML_STATE AS VARCHAR(MAX))       AS ML_STATE,
                CAST(PERM_STATE AS VARCHAR(MAX))     AS PERM_STATE,
                CAST(ML_ZIPCODE AS VARCHAR(MAX))     AS ML_ZIPCODE,
                DW_UPD_DTTM,
                DW_INS_DTTM,
                CAST(UII_MEMBER_ID AS BIGINT)        AS UII_MEMBER_ID,
                CAST(SEQ_PERSON_ID AS BIGINT)        AS SEQ_PERSON_ID,
                CAST(SEQ_ORG_AGENT_ID AS BIGINT)     AS SEQ_ORG_AGENT_ID
            INTO ' + @TgtFQN + '
            FROM ' + @SrcFQN + ';';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN

        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.PERM_ZIPCODE    = CAST(src.PERM_ZIPCODE AS VARCHAR(MAX)),
                tgt.ML_STATE        = CAST(src.ML_STATE AS VARCHAR(MAX)),
                tgt.PERM_STATE      = CAST(src.PERM_STATE AS VARCHAR(MAX)),
                tgt.ML_ZIPCODE      = CAST(src.ML_ZIPCODE AS VARCHAR(MAX)),
                tgt.DW_UPD_DTTM     = src.DW_UPD_DTTM,
                tgt.DW_INS_DTTM     = src.DW_INS_DTTM,
                tgt.UII_MEMBER_ID   = CAST(src.UII_MEMBER_ID AS BIGINT),
                tgt.SEQ_PERSON_ID   = CAST(src.SEQ_PERSON_ID AS BIGINT),
                tgt.SEQ_ORG_AGENT_ID = CAST(src.SEQ_ORG_AGENT_ID AS BIGINT)
            FROM ' + @TgtFQN + ' tgt
            INNER JOIN ' + @SrcFQN + ' src
                ON tgt.PROFILE_KEY = CAST(src.PROFILE_KEY AS BIGINT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + '
            (
                PROFILE_KEY, PERM_ZIPCODE, ML_STATE, PERM_STATE, ML_ZIPCODE,
                DW_UPD_DTTM, DW_INS_DTTM, UII_MEMBER_ID, SEQ_PERSON_ID, SEQ_ORG_AGENT_ID
            )
            SELECT
                CAST(src.PROFILE_KEY AS BIGINT),
                CAST(src.PERM_ZIPCODE AS VARCHAR(MAX)),
                CAST(src.ML_STATE AS VARCHAR(MAX)),
                CAST(src.PERM_STATE AS VARCHAR(MAX)),
                CAST(src.ML_ZIPCODE AS VARCHAR(MAX)),
                src.DW_UPD_DTTM,
                src.DW_INS_DTTM,
                CAST(src.UII_MEMBER_ID AS BIGINT),
                CAST(src.SEQ_PERSON_ID AS BIGINT),
                CAST(src.SEQ_ORG_AGENT_ID AS BIGINT)
            FROM ' + @SrcFQN + ' src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + ' tgt
                WHERE tgt.PROFILE_KEY = CAST(src.PROFILE_KEY AS BIGINT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 27. V_T_D_TIME
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;
SET @TableExists = 0;

SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' +
    QUOTENAME(@StageSchemaName) + '.' +
    QUOTENAME('V_T_D_TIME');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' +
    QUOTENAME('V_T_D_TIME');

SET @TgtObjectId = @TargetSchemaName + '.V_T_D_TIME';

BEGIN TRY

    IF OBJECT_ID(@TgtObjectId, 'U') IS NOT NULL
        SET @TableExists = 1;

    

    IF @TableExists = 0
    BEGIN

        SET @SQL = N'
            SELECT
                CAST(DAY_OF_YEAR AS INT)                             AS DAY_OF_YEAR,
                CAST(YEAR_ID AS INT)                                 AS YEAR_ID,
                CAST(YEARMONTH AS INT)                               AS YEARMONTH,
                CAST(FISCAL_MONTH_OF_YEAR AS INT)                    AS FISCAL_MONTH_OF_YEAR,
                CAST(DAYS_IN_MONTH AS INT)                           AS DAYS_IN_MONTH,
                CAST(DAYS_IN_DAY AS INT)                             AS DAYS_IN_DAY,
                CAST(FISCAL_QUARTER_OF_YEAR AS INT)                  AS FISCAL_QUARTER_OF_YEAR,
                CAST(DAY_OF_WEEK AS INT)                             AS DAY_OF_WEEK,
                CAST(MONTH_OF_QUARTER AS INT)                        AS MONTH_OF_QUARTER,
                CAST(TIME_KEY AS INT)                                AS TIME_KEY,
                CAST(FISCAL_YEAR AS INT)                             AS FISCAL_YEAR,
                CAST(DAYS_IN_QUARTER AS INT)                         AS DAYS_IN_QUARTER,
                CAST(QUARTER_OF_YEAR AS INT)                         AS QUARTER_OF_YEAR,
                CAST(DAY_OF_MONTH AS INT)                            AS DAY_OF_MONTH,
                CAST(MONTH_OF_YEAR AS INT)                           AS MONTH_OF_YEAR,
                CAST(DAYS_IN_YEAR AS INT)                            AS DAYS_IN_YEAR,
                CAST(NEXT_BUSINESS_DAY AS DATE)                      AS NEXT_BUSINESS_DAY,
                CAST(DATE_OF_DAY AS DATE)                            AS DATE_OF_DAY,
                CAST(END_OF_QUARTER AS DATE)                         AS END_OF_QUARTER,
                CAST(END_OF_YEAR AS DATE)                            AS END_OF_YEAR,
                CAST(END_OF_MONTH AS DATE)                           AS END_OF_MONTH,
                CAST(PRIOR_BUSINESS_DAY AS DATE)                     AS PRIOR_BUSINESS_DAY,
                CAST(END_OF_BUSINESS_MONTH_FLAG AS CHAR(1))          AS END_OF_BUSINESS_MONTH_FLAG,
                CAST(HOLIDAY_FLAG AS CHAR(1))                        AS HOLIDAY_FLAG,
                CAST(STOCK_HOLIDAY_FLAG AS CHAR(1))                  AS STOCK_HOLIDAY_FLAG,
                CAST(BANK_HOLIDAY_FLAG AS CHAR(1))                   AS BANK_HOLIDAY_FLAG,
                CAST(END_OF_MONTH_FLAG AS CHAR(1))                   AS END_OF_MONTH_FLAG,
                CAST(MONTH_ID AS VARCHAR(50))                        AS MONTH_ID,
                CAST(QUARTER_ID AS VARCHAR(50))                      AS QUARTER_ID,
                CAST(DAY_NAME AS VARCHAR(100))                       AS DAY_NAME,
                CAST(DAY_DESC AS VARCHAR(255))                       AS DAY_DESC,
                CAST(QUARTER_DESC AS VARCHAR(255))                   AS QUARTER_DESC,
                CAST(MONTH_NAME AS VARCHAR(100))                     AS MONTH_NAME,
                CAST(WEEK_OF_YEAR AS VARCHAR(50))                    AS WEEK_OF_YEAR,
                CAST(MONTH_DESC AS VARCHAR(255))                     AS MONTH_DESC,
                CAST(SEMESTER AS VARCHAR(50))                        AS SEMESTER,
                DW_INS_DTTM,
                DW_UPD_DTTM
            INTO ' + @TgtFQN + '
            FROM ' + @SrcFQN + ';';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN

        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.DAY_OF_YEAR                     = CAST(src.DAY_OF_YEAR AS INT),
                tgt.YEAR_ID                          = CAST(src.YEAR_ID AS INT),
                tgt.YEARMONTH                        = CAST(src.YEARMONTH AS INT),
                tgt.FISCAL_MONTH_OF_YEAR              = CAST(src.FISCAL_MONTH_OF_YEAR AS INT),
                tgt.DAYS_IN_MONTH                     = CAST(src.DAYS_IN_MONTH AS INT),
                tgt.DAYS_IN_DAY                        = CAST(src.DAYS_IN_DAY AS INT),
                tgt.FISCAL_QUARTER_OF_YEAR             = CAST(src.FISCAL_QUARTER_OF_YEAR AS INT),
                tgt.DAY_OF_WEEK                        = CAST(src.DAY_OF_WEEK AS INT),
                tgt.MONTH_OF_QUARTER                   = CAST(src.MONTH_OF_QUARTER AS INT),
                tgt.FISCAL_YEAR                        = CAST(src.FISCAL_YEAR AS INT),
                tgt.DAYS_IN_QUARTER                    = CAST(src.DAYS_IN_QUARTER AS INT),
                tgt.QUARTER_OF_YEAR                    = CAST(src.QUARTER_OF_YEAR AS INT),
                tgt.DAY_OF_MONTH                       = CAST(src.DAY_OF_MONTH AS INT),
                tgt.MONTH_OF_YEAR                      = CAST(src.MONTH_OF_YEAR AS INT),
                tgt.DAYS_IN_YEAR                       = CAST(src.DAYS_IN_YEAR AS INT),
                tgt.NEXT_BUSINESS_DAY                  = CAST(src.NEXT_BUSINESS_DAY AS DATE),
                tgt.DATE_OF_DAY                        = CAST(src.DATE_OF_DAY AS DATE),
                tgt.END_OF_QUARTER                     = CAST(src.END_OF_QUARTER AS DATE),
                tgt.END_OF_YEAR                        = CAST(src.END_OF_YEAR AS DATE),
                tgt.END_OF_MONTH                       = CAST(src.END_OF_MONTH AS DATE),
                tgt.PRIOR_BUSINESS_DAY                 = CAST(src.PRIOR_BUSINESS_DAY AS DATE),
                tgt.END_OF_BUSINESS_MONTH_FLAG          = CAST(src.END_OF_BUSINESS_MONTH_FLAG AS CHAR(1)),
                tgt.HOLIDAY_FLAG                       = CAST(src.HOLIDAY_FLAG AS CHAR(1)),
                tgt.STOCK_HOLIDAY_FLAG                  = CAST(src.STOCK_HOLIDAY_FLAG AS CHAR(1)),
                tgt.BANK_HOLIDAY_FLAG                   = CAST(src.BANK_HOLIDAY_FLAG AS CHAR(1)),
                tgt.END_OF_MONTH_FLAG                   = CAST(src.END_OF_MONTH_FLAG AS CHAR(1)),
                tgt.MONTH_ID                            = CAST(src.MONTH_ID AS VARCHAR(50)),
                tgt.QUARTER_ID                          = CAST(src.QUARTER_ID AS VARCHAR(50)),
                tgt.DAY_NAME                            = CAST(src.DAY_NAME AS VARCHAR(100)),
                tgt.DAY_DESC                            = CAST(src.DAY_DESC AS VARCHAR(255)),
                tgt.QUARTER_DESC                        = CAST(src.QUARTER_DESC AS VARCHAR(255)),
                tgt.MONTH_NAME                          = CAST(src.MONTH_NAME AS VARCHAR(100)),
                tgt.WEEK_OF_YEAR                        = CAST(src.WEEK_OF_YEAR AS VARCHAR(50)),
                tgt.MONTH_DESC                          = CAST(src.MONTH_DESC AS VARCHAR(255)),
                tgt.SEMESTER                            = CAST(src.SEMESTER AS VARCHAR(50)),
                tgt.DW_INS_DTTM                         = src.DW_INS_DTTM,
                tgt.DW_UPD_DTTM                         = src.DW_UPD_DTTM
            FROM ' + @TgtFQN + ' tgt
            INNER JOIN ' + @SrcFQN + ' src
                ON tgt.TIME_KEY = CAST(src.TIME_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + '
            (
                DAY_OF_YEAR, YEAR_ID, YEARMONTH, FISCAL_MONTH_OF_YEAR, DAYS_IN_MONTH,
                DAYS_IN_DAY, FISCAL_QUARTER_OF_YEAR, DAY_OF_WEEK, MONTH_OF_QUARTER,
                TIME_KEY, FISCAL_YEAR, DAYS_IN_QUARTER, QUARTER_OF_YEAR, DAY_OF_MONTH,
                MONTH_OF_YEAR, DAYS_IN_YEAR, NEXT_BUSINESS_DAY, DATE_OF_DAY, END_OF_QUARTER,
                END_OF_YEAR, END_OF_MONTH, PRIOR_BUSINESS_DAY, END_OF_BUSINESS_MONTH_FLAG,
                HOLIDAY_FLAG, STOCK_HOLIDAY_FLAG, BANK_HOLIDAY_FLAG, END_OF_MONTH_FLAG,
                MONTH_ID, QUARTER_ID, DAY_NAME, DAY_DESC, QUARTER_DESC, MONTH_NAME,
                WEEK_OF_YEAR, MONTH_DESC, SEMESTER, DW_INS_DTTM, DW_UPD_DTTM
            )
            SELECT
                CAST(src.DAY_OF_YEAR AS INT),
                CAST(src.YEAR_ID AS INT),
                CAST(src.YEARMONTH AS INT),
                CAST(src.FISCAL_MONTH_OF_YEAR AS INT),
                CAST(src.DAYS_IN_MONTH AS INT),
                CAST(src.DAYS_IN_DAY AS INT),
                CAST(src.FISCAL_QUARTER_OF_YEAR AS INT),
                CAST(src.DAY_OF_WEEK AS INT),
                CAST(src.MONTH_OF_QUARTER AS INT),
                CAST(src.TIME_KEY AS INT),
                CAST(src.FISCAL_YEAR AS INT),
                CAST(src.DAYS_IN_QUARTER AS INT),
                CAST(src.QUARTER_OF_YEAR AS INT),
                CAST(src.DAY_OF_MONTH AS INT),
                CAST(src.MONTH_OF_YEAR AS INT),
                CAST(src.DAYS_IN_YEAR AS INT),
                CAST(src.NEXT_BUSINESS_DAY AS DATE),
                CAST(src.DATE_OF_DAY AS DATE),
                CAST(src.END_OF_QUARTER AS DATE),
                CAST(src.END_OF_YEAR AS DATE),
                CAST(src.END_OF_MONTH AS DATE),
                CAST(src.PRIOR_BUSINESS_DAY AS DATE),
                CAST(src.END_OF_BUSINESS_MONTH_FLAG AS CHAR(1)),
                CAST(src.HOLIDAY_FLAG AS CHAR(1)),
                CAST(src.STOCK_HOLIDAY_FLAG AS CHAR(1)),
                CAST(src.BANK_HOLIDAY_FLAG AS CHAR(1)),
                CAST(src.END_OF_MONTH_FLAG AS CHAR(1)),
                CAST(src.MONTH_ID AS VARCHAR(50)),
                CAST(src.QUARTER_ID AS VARCHAR(50)),
                CAST(src.DAY_NAME AS VARCHAR(100)),
                CAST(src.DAY_DESC AS VARCHAR(255)),
                CAST(src.QUARTER_DESC AS VARCHAR(255)),
                CAST(src.MONTH_NAME AS VARCHAR(100)),
                CAST(src.WEEK_OF_YEAR AS VARCHAR(50)),
                CAST(src.MONTH_DESC AS VARCHAR(255)),
                CAST(src.SEMESTER AS VARCHAR(50)),
                src.DW_INS_DTTM,
                src.DW_UPD_DTTM
            FROM ' + @SrcFQN + ' src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + ' tgt
                WHERE tgt.TIME_KEY = CAST(src.TIME_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 28. V_T_D_TXN_TYPE
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;
SET @TableExists = 0;

SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' +
    QUOTENAME(@StageSchemaName) + '.' +
    QUOTENAME('V_T_D_TXN_TYPE');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' +
    QUOTENAME('V_T_D_TXN_TYPE');

SET @TgtObjectId = @TargetSchemaName + '.V_T_D_TXN_TYPE';

BEGIN TRY

    IF OBJECT_ID(@TgtObjectId, 'U') IS NOT NULL
        SET @TableExists = 1;

    

    IF @TableExists = 0
    BEGIN

        SET @SQL = N'
            SELECT
                CAST(TXN_TYPE_KEY AS INT)                       AS TXN_TYPE_KEY,
                CAST(UNITE_TXN_CODE AS INT)                     AS UNITE_TXN_CODE,
                CAST(SEQ_TXN_TYPE_ID AS INT)                    AS SEQ_TXN_TYPE_ID,
                CAST(GSP_TXN_TYPE_ID AS INT)                    AS GSP_TXN_TYPE_ID,
                CAST(GSP_DISBURSAL_TYPE_ID AS INT)               AS GSP_DISBURSAL_TYPE_ID,
                CAST(TLM AS DATETIME2(6))                       AS TLM,
                CAST(GSP_QUAL_WITHDRAWAL_FLAG AS CHAR(1))       AS GSP_QUAL_WITHDRAWAL_FLAG,
                CAST(GSP_REGULAR_CONTRIBS_FLAG AS CHAR(1))      AS GSP_REGULAR_CONTRIBS_FLAG,
                CAST(CANCEL_FLAG AS CHAR(1))                    AS CANCEL_FLAG,
                CAST(UII_REVERSE AS CHAR(1))                    AS UII_REVERSE,
                CAST(TXN_TYPE_GROUPING AS VARCHAR(MAX))         AS TXN_TYPE_GROUPING,
                CAST(AUDIT_DESCRIPTION AS VARCHAR(MAX))         AS AUDIT_DESCRIPTION,
                CAST(UII_DESCRIPTION AS VARCHAR(MAX))           AS UII_DESCRIPTION,
                CAST(FLOW_DIRECTION AS VARCHAR(MAX))            AS FLOW_DIRECTION,
                CAST(DST_DESCRIPTION AS VARCHAR(MAX))           AS DST_DESCRIPTION,
                CAST(SOURCE_DESCRIPTION AS VARCHAR(MAX))        AS SOURCE_DESCRIPTION,
                CAST(DESCRIPTION AS VARCHAR(MAX))               AS DESCRIPTION,
                CAST(OMNIBUS_SUBMITTING_FIRM AS VARCHAR(MAX))   AS OMNIBUS_SUBMITTING_FIRM,
                CAST(GSP_VT_REFUND_TYPE AS VARCHAR(MAX))        AS GSP_VT_REFUND_TYPE,
                CAST(GSP_TXN_TYPE AS VARCHAR(MAX))              AS GSP_TXN_TYPE,
                CAST(TRAUNCH_ID AS VARCHAR(MAX))                AS TRAUNCH_ID,
                CAST(USAGE_SUFFIX_CODE AS VARCHAR(MAX))         AS USAGE_SUFFIX_CODE,
                CAST(GSP_CODE_ID AS VARCHAR(MAX))               AS GSP_CODE_ID,
                CAST(GSP_LEGACY_CODE AS VARCHAR(MAX))           AS GSP_LEGACY_CODE,
                CAST(TRANSACTION_CODE AS VARCHAR(MAX))          AS TRANSACTION_CODE,
                CAST(PLATFORM AS VARCHAR(MAX))                  AS PLATFORM,
                CAST(GSP_PAYROLL_TYPE_FLAG AS VARCHAR(MAX))     AS GSP_PAYROLL_TYPE_FLAG,
                CAST(GSP_DISBURSAL_TYPE_DESC AS VARCHAR(MAX))   AS GSP_DISBURSAL_TYPE_DESC
            INTO ' + @TgtFQN + '
            FROM ' + @SrcFQN + ';';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN

        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.UNITE_TXN_CODE               = CAST(src.UNITE_TXN_CODE AS INT),
                tgt.SEQ_TXN_TYPE_ID               = CAST(src.SEQ_TXN_TYPE_ID AS INT),
                tgt.GSP_TXN_TYPE_ID                = CAST(src.GSP_TXN_TYPE_ID AS INT),
                tgt.GSP_DISBURSAL_TYPE_ID           = CAST(src.GSP_DISBURSAL_TYPE_ID AS INT),
                tgt.TLM                            = CAST(src.TLM AS DATETIME2(6)),
                tgt.GSP_QUAL_WITHDRAWAL_FLAG       = CAST(src.GSP_QUAL_WITHDRAWAL_FLAG AS CHAR(1)),
                tgt.GSP_REGULAR_CONTRIBS_FLAG      = CAST(src.GSP_REGULAR_CONTRIBS_FLAG AS CHAR(1)),
                tgt.CANCEL_FLAG                    = CAST(src.CANCEL_FLAG AS CHAR(1)),
                tgt.UII_REVERSE                    = CAST(src.UII_REVERSE AS CHAR(1)),
                tgt.TXN_TYPE_GROUPING              = CAST(src.TXN_TYPE_GROUPING AS VARCHAR(MAX)),
                tgt.AUDIT_DESCRIPTION              = CAST(src.AUDIT_DESCRIPTION AS VARCHAR(MAX)),
                tgt.UII_DESCRIPTION                = CAST(src.UII_DESCRIPTION AS VARCHAR(MAX)),
                tgt.FLOW_DIRECTION                 = CAST(src.FLOW_DIRECTION AS VARCHAR(MAX)),
                tgt.DST_DESCRIPTION                = CAST(src.DST_DESCRIPTION AS VARCHAR(MAX)),
                tgt.SOURCE_DESCRIPTION             = CAST(src.SOURCE_DESCRIPTION AS VARCHAR(MAX)),
                tgt.DESCRIPTION                    = CAST(src.DESCRIPTION AS VARCHAR(MAX)),
                tgt.OMNIBUS_SUBMITTING_FIRM        = CAST(src.OMNIBUS_SUBMITTING_FIRM AS VARCHAR(MAX)),
                tgt.GSP_VT_REFUND_TYPE             = CAST(src.GSP_VT_REFUND_TYPE AS VARCHAR(MAX)),
                tgt.GSP_TXN_TYPE                   = CAST(src.GSP_TXN_TYPE AS VARCHAR(MAX)),
                tgt.TRAUNCH_ID                     = CAST(src.TRAUNCH_ID AS VARCHAR(MAX)),
                tgt.USAGE_SUFFIX_CODE              = CAST(src.USAGE_SUFFIX_CODE AS VARCHAR(MAX)),
                tgt.GSP_CODE_ID                    = CAST(src.GSP_CODE_ID AS VARCHAR(MAX)),
                tgt.GSP_LEGACY_CODE                = CAST(src.GSP_LEGACY_CODE AS VARCHAR(MAX)),
                tgt.TRANSACTION_CODE               = CAST(src.TRANSACTION_CODE AS VARCHAR(MAX)),
                tgt.PLATFORM                       = CAST(src.PLATFORM AS VARCHAR(MAX)),
                tgt.GSP_PAYROLL_TYPE_FLAG          = CAST(src.GSP_PAYROLL_TYPE_FLAG AS VARCHAR(MAX)),
                tgt.GSP_DISBURSAL_TYPE_DESC        = CAST(src.GSP_DISBURSAL_TYPE_DESC AS VARCHAR(MAX))
            FROM ' + @TgtFQN + ' tgt
            INNER JOIN ' + @SrcFQN + ' src
                ON tgt.TXN_TYPE_KEY = CAST(src.TXN_TYPE_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + '
            (
                TXN_TYPE_KEY, UNITE_TXN_CODE, SEQ_TXN_TYPE_ID, GSP_TXN_TYPE_ID,
                GSP_DISBURSAL_TYPE_ID, TLM, GSP_QUAL_WITHDRAWAL_FLAG, GSP_REGULAR_CONTRIBS_FLAG,
                CANCEL_FLAG, UII_REVERSE, TXN_TYPE_GROUPING, AUDIT_DESCRIPTION,
                UII_DESCRIPTION, FLOW_DIRECTION, DST_DESCRIPTION, SOURCE_DESCRIPTION,
                DESCRIPTION, OMNIBUS_SUBMITTING_FIRM, GSP_VT_REFUND_TYPE, GSP_TXN_TYPE,
                TRAUNCH_ID, USAGE_SUFFIX_CODE, GSP_CODE_ID, GSP_LEGACY_CODE,
                TRANSACTION_CODE, PLATFORM, GSP_PAYROLL_TYPE_FLAG, GSP_DISBURSAL_TYPE_DESC
            )
            SELECT
                CAST(src.TXN_TYPE_KEY AS INT),
                CAST(src.UNITE_TXN_CODE AS INT),
                CAST(src.SEQ_TXN_TYPE_ID AS INT),
                CAST(src.GSP_TXN_TYPE_ID AS INT),
                CAST(src.GSP_DISBURSAL_TYPE_ID AS INT),
                CAST(src.TLM AS DATETIME2(6)),
                CAST(src.GSP_QUAL_WITHDRAWAL_FLAG AS CHAR(1)),
                CAST(src.GSP_REGULAR_CONTRIBS_FLAG AS CHAR(1)),
                CAST(src.CANCEL_FLAG AS CHAR(1)),
                CAST(src.UII_REVERSE AS CHAR(1)),
                CAST(src.TXN_TYPE_GROUPING AS VARCHAR(MAX)),
                CAST(src.AUDIT_DESCRIPTION AS VARCHAR(MAX)),
                CAST(src.UII_DESCRIPTION AS VARCHAR(MAX)),
                CAST(src.FLOW_DIRECTION AS VARCHAR(MAX)),
                CAST(src.DST_DESCRIPTION AS VARCHAR(MAX)),
                CAST(src.SOURCE_DESCRIPTION AS VARCHAR(MAX)),
                CAST(src.DESCRIPTION AS VARCHAR(MAX)),
                CAST(src.OMNIBUS_SUBMITTING_FIRM AS VARCHAR(MAX)),
                CAST(src.GSP_VT_REFUND_TYPE AS VARCHAR(MAX)),
                CAST(src.GSP_TXN_TYPE AS VARCHAR(MAX)),
                CAST(src.TRAUNCH_ID AS VARCHAR(MAX)),
                CAST(src.USAGE_SUFFIX_CODE AS VARCHAR(MAX)),
                CAST(src.GSP_CODE_ID AS VARCHAR(MAX)),
                CAST(src.GSP_LEGACY_CODE AS VARCHAR(MAX)),
                CAST(src.TRANSACTION_CODE AS VARCHAR(MAX)),
                CAST(src.PLATFORM AS VARCHAR(MAX)),
                CAST(src.GSP_PAYROLL_TYPE_FLAG AS VARCHAR(MAX)),
                CAST(src.GSP_DISBURSAL_TYPE_DESC AS VARCHAR(MAX))
            FROM ' + @SrcFQN + ' src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + ' tgt
                WHERE tgt.TXN_TYPE_KEY = CAST(src.TXN_TYPE_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 29. V_T_F_ACCOUNT_CLOSURE_AAV2
-- NOTE: composite join key (ACCOUNT_PROFILE_KEY + ACCOUNT_CLOSURE_TIME_KEY)
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;
SET @TableExists = 0;

SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' +
    QUOTENAME(@StageSchemaName) + '.' +
    QUOTENAME('V_T_F_ACCOUNT_CLOSURE_AAV2');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' +
    QUOTENAME('V_T_F_ACCOUNT_CLOSURE_AAV2');

SET @TgtObjectId = @TargetSchemaName + '.V_T_F_ACCOUNT_CLOSURE_AAV2';

BEGIN TRY

    IF OBJECT_ID(@TgtObjectId, 'U') IS NOT NULL
        SET @TableExists = 1;

    

    IF @TableExists = 0
    BEGIN

        SET @SQL = N'
            SELECT
                CAST(PLAN_KEY AS INT)                        AS PLAN_KEY,
                CAST(ACCOUNT_PROFILE_KEY AS INT)              AS ACCOUNT_PROFILE_KEY,
                CAST(ACCOUNT_CLOSURE_TIME_KEY AS INT)         AS ACCOUNT_CLOSURE_TIME_KEY,
                CAST(BENE_AGE_KEY AS INT)                     AS BENE_AGE_KEY,
                CAST(CLOSURE_DATE AS DATE)                    AS CLOSURE_DATE,
                DW_INS_DTTM,
                DW_UPD_DTTM
            INTO ' + @TgtFQN + '
            FROM ' + @SrcFQN + ';';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN

        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.PLAN_KEY       = CAST(src.PLAN_KEY AS INT),
                tgt.BENE_AGE_KEY   = CAST(src.BENE_AGE_KEY AS INT),
                tgt.CLOSURE_DATE   = CAST(src.CLOSURE_DATE AS DATE),
                tgt.DW_INS_DTTM    = src.DW_INS_DTTM,
                tgt.DW_UPD_DTTM    = src.DW_UPD_DTTM
            FROM ' + @TgtFQN + ' tgt
            INNER JOIN ' + @SrcFQN + ' src
                ON tgt.ACCOUNT_PROFILE_KEY      = CAST(src.ACCOUNT_PROFILE_KEY AS INT)
               AND tgt.ACCOUNT_CLOSURE_TIME_KEY = CAST(src.ACCOUNT_CLOSURE_TIME_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + '
            (
                PLAN_KEY, ACCOUNT_PROFILE_KEY, ACCOUNT_CLOSURE_TIME_KEY, BENE_AGE_KEY,
                CLOSURE_DATE, DW_INS_DTTM, DW_UPD_DTTM
            )
            SELECT
                CAST(src.PLAN_KEY AS INT),
                CAST(src.ACCOUNT_PROFILE_KEY AS INT),
                CAST(src.ACCOUNT_CLOSURE_TIME_KEY AS INT),
                CAST(src.BENE_AGE_KEY AS INT),
                CAST(src.CLOSURE_DATE AS DATE),
                src.DW_INS_DTTM,
                src.DW_UPD_DTTM
            FROM ' + @SrcFQN + ' src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + ' tgt
                WHERE tgt.ACCOUNT_PROFILE_KEY      = CAST(src.ACCOUNT_PROFILE_KEY AS INT)
                  AND tgt.ACCOUNT_CLOSURE_TIME_KEY = CAST(src.ACCOUNT_CLOSURE_TIME_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 30. V_T_F_ACCOUNT_ENROLLMENT_AAV2
-- NOTE: composite join key (ACCOUNT_PROFILE_KEY + ACCOUNT_TC_ACCEPTED_TIME_KEY)
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;
SET @TableExists = 0;

SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' +
    QUOTENAME(@StageSchemaName) + '.' +
    QUOTENAME('V_T_F_ACCOUNT_ENROLLMENT_AAV2');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' +
    QUOTENAME('V_T_F_ACCOUNT_ENROLLMENT_AAV2');

SET @TgtObjectId = @TargetSchemaName + '.V_T_F_ACCOUNT_ENROLLMENT_AAV2';

BEGIN TRY

    IF OBJECT_ID(@TgtObjectId, 'U') IS NOT NULL
        SET @TableExists = 1;

    

    IF @TableExists = 0
    BEGIN

        SET @SQL = N'
            SELECT
                CAST(PLAN_KEY AS INT)                              AS PLAN_KEY,
                CAST(ACCOUNT_PROFILE_KEY AS INT)                   AS ACCOUNT_PROFILE_KEY,
                CAST(ACCOUNT_TC_ACCEPTED_TIME_KEY AS INT)          AS ACCOUNT_TC_ACCEPTED_TIME_KEY,
                CAST(ACCOUNT_ENROLL_TIME_KEY AS INT)               AS ACCOUNT_ENROLL_TIME_KEY,
                CAST(INITIAL_CONTRIB_AMOUNT AS DECIMAL(18,2))      AS INITIAL_CONTRIB_AMOUNT,
                CAST(BENE_AGE_KEY AS INT)                          AS BENE_AGE_KEY,
                CAST(ENROLLMENT_DATE AS DATE)                      AS ENROLLMENT_DATE,
                SRC_UPD_TS,
                SRC_INS_TS
            INTO ' + @TgtFQN + '
            FROM ' + @SrcFQN + ';';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN

        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.PLAN_KEY                     = CAST(src.PLAN_KEY AS INT),
                tgt.ACCOUNT_ENROLL_TIME_KEY      = CAST(src.ACCOUNT_ENROLL_TIME_KEY AS INT),
                tgt.INITIAL_CONTRIB_AMOUNT       = CAST(src.INITIAL_CONTRIB_AMOUNT AS DECIMAL(18,2)),
                tgt.BENE_AGE_KEY                 = CAST(src.BENE_AGE_KEY AS INT),
                tgt.ENROLLMENT_DATE              = CAST(src.ENROLLMENT_DATE AS DATE),
                tgt.SRC_UPD_TS                   = src.SRC_UPD_TS,
                tgt.SRC_INS_TS                   = src.SRC_INS_TS
            FROM ' + @TgtFQN + ' tgt
            INNER JOIN ' + @SrcFQN + ' src
                ON tgt.ACCOUNT_PROFILE_KEY           = CAST(src.ACCOUNT_PROFILE_KEY AS INT)
               AND tgt.ACCOUNT_TC_ACCEPTED_TIME_KEY  = CAST(src.ACCOUNT_TC_ACCEPTED_TIME_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + '
            (
                PLAN_KEY, ACCOUNT_PROFILE_KEY, ACCOUNT_TC_ACCEPTED_TIME_KEY, ACCOUNT_ENROLL_TIME_KEY,
                INITIAL_CONTRIB_AMOUNT, BENE_AGE_KEY, ENROLLMENT_DATE, SRC_UPD_TS, SRC_INS_TS
            )
            SELECT
                CAST(src.PLAN_KEY AS INT),
                CAST(src.ACCOUNT_PROFILE_KEY AS INT),
                CAST(src.ACCOUNT_TC_ACCEPTED_TIME_KEY AS INT),
                CAST(src.ACCOUNT_ENROLL_TIME_KEY AS INT),
                CAST(src.INITIAL_CONTRIB_AMOUNT AS DECIMAL(18,2)),
                CAST(src.BENE_AGE_KEY AS INT),
                CAST(src.ENROLLMENT_DATE AS DATE),
                src.SRC_UPD_TS,
                src.SRC_INS_TS
            FROM ' + @SrcFQN + ' src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + ' tgt
                WHERE tgt.ACCOUNT_PROFILE_KEY           = CAST(src.ACCOUNT_PROFILE_KEY AS INT)
                  AND tgt.ACCOUNT_TC_ACCEPTED_TIME_KEY  = CAST(src.ACCOUNT_TC_ACCEPTED_TIME_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH

------------------------------------------------------------
-- 31. V_T_F_ACCOUNT_SNAPSHOT_AAV2
-- NOTE: composite join key (ACCOUNT_PROFILE_KEY + TIME_KEY); source SELECT DISTINCT
------------------------------------------------------------

SET @StartTime = SYSDATETIME();

SET @InsertedRows = 0;
SET @UpdatedRows = 0;
SET @TableExists = 0;

SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' +
    QUOTENAME(@StageSchemaName) + '.' +
    QUOTENAME('V_T_F_ACCOUNT_SNAPSHOT_AAV2');

SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' +
    QUOTENAME('V_T_F_ACCOUNT_SNAPSHOT_AAV2');

SET @TgtObjectId = @TargetSchemaName + '.V_T_F_ACCOUNT_SNAPSHOT_AAV2';

BEGIN TRY

    IF OBJECT_ID(@TgtObjectId, 'U') IS NOT NULL
        SET @TableExists = 1;

    

    IF @TableExists = 0
    BEGIN

        SET @SQL = N'
            SELECT DISTINCT
                CAST(PLAN_KEY AS INT)             AS PLAN_KEY,
                CAST(ACCOUNT_PROFILE_KEY AS INT)  AS ACCOUNT_PROFILE_KEY,
                CAST(TIME_KEY AS INT)             AS TIME_KEY,
                CAST(FUNDED_KEY AS INT)           AS FUNDED_KEY,
                CAST(ACCOUNT_COUNT AS INT)        AS ACCOUNT_COUNT,
                CAST(DORMANCY_KEY AS INT)         AS DORMANCY_KEY,
                DW_INS_DTTM,
                DW_UPD_DTTM,
                CAST(RUN_DATE AS DATETIME2(6))    AS RUN_DATE,
                CAST(TOTAL_ASSETS AS FLOAT)       AS TOTAL_ASSETS
            INTO ' + @TgtFQN + '
            FROM ' + @SrcFQN + ';';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows  = 0;
    END
    ELSE
    BEGIN

        SET @SQL = N'
            UPDATE tgt
            SET
                tgt.PLAN_KEY        = CAST(src.PLAN_KEY AS INT),
                tgt.FUNDED_KEY      = CAST(src.FUNDED_KEY AS INT),
                tgt.ACCOUNT_COUNT   = CAST(src.ACCOUNT_COUNT AS INT),
                tgt.DORMANCY_KEY    = CAST(src.DORMANCY_KEY AS INT),
                tgt.DW_INS_DTTM     = src.DW_INS_DTTM,
                tgt.DW_UPD_DTTM     = src.DW_UPD_DTTM,
                tgt.RUN_DATE        = CAST(src.RUN_DATE AS DATETIME2(6)),
                tgt.TOTAL_ASSETS    = CAST(src.TOTAL_ASSETS AS FLOAT)
            FROM ' + @TgtFQN + ' tgt
            INNER JOIN ' + @SrcFQN + ' src
                ON tgt.ACCOUNT_PROFILE_KEY = CAST(src.ACCOUNT_PROFILE_KEY AS INT)
               AND tgt.TIME_KEY            = CAST(src.TIME_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        SET @SQL = N'
            INSERT INTO ' + @TgtFQN + '
            (
                PLAN_KEY, ACCOUNT_PROFILE_KEY, TIME_KEY, FUNDED_KEY, ACCOUNT_COUNT,
                DORMANCY_KEY, DW_INS_DTTM, DW_UPD_DTTM, RUN_DATE, TOTAL_ASSETS
            )
            SELECT DISTINCT
                CAST(src.PLAN_KEY AS INT),
                CAST(src.ACCOUNT_PROFILE_KEY AS INT),
                CAST(src.TIME_KEY AS INT),
                CAST(src.FUNDED_KEY AS INT),
                CAST(src.ACCOUNT_COUNT AS INT),
                CAST(src.DORMANCY_KEY AS INT),
                src.DW_INS_DTTM,
                src.DW_UPD_DTTM,
                CAST(src.RUN_DATE AS DATETIME2(6)),
                CAST(src.TOTAL_ASSETS AS FLOAT)
            FROM ' + @SrcFQN + ' src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + @TgtFQN + ' tgt
                WHERE tgt.ACCOUNT_PROFILE_KEY = CAST(src.ACCOUNT_PROFILE_KEY AS INT)
                  AND tgt.TIME_KEY            = CAST(src.TIME_KEY AS INT)
            );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
    END

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH


------------------------------------------------------------
-- 32. V_T_F_ACCT_TXN_AAV2
------------------------------------------------------------

SET @StartTime = SYSDATETIME();
SET @InsertedRows = 0;
SET @UpdatedRows = 0;
SET @TableExists = 0;

SET @SrcFQN = QUOTENAME(@WarehouseName) + '.' + QUOTENAME(@StageSchemaName) + '.' + QUOTENAME('V_T_F_ACCT_TXN_AAV2');
SET @TgtFQN = QUOTENAME(@TargetSchemaName) + '.' + QUOTENAME('V_T_F_ACCT_TXN_AAV2');
SET @TgtObjectId = @TargetSchemaName + '.' + 'V_T_F_ACCT_TXN_AAV2';

BEGIN TRY

    IF OBJECT_ID(@TgtObjectId, 'U') IS NOT NULL
        SET @TableExists = 1;

    IF @TableExists = 0
    BEGIN

        SET @SQL = N'
        SELECT DISTINCT
            CAST(PLAN_KEY AS INT)                                  AS PLAN_KEY,
            CAST(REP_KEY AS INT)                                   AS REP_KEY,
            CAST(BENE_RUN_AGE AS INT)                              AS BENE_RUN_AGE,
            CAST(PLATFORM_SOURCE AS INT)                           AS PLATFORM_SOURCE,
            CAST(ACCT_OWNER_RUN_AGE AS INT)                        AS ACCT_OWNER_RUN_AGE,
            CAST(DEALER_KEY AS INT)                                AS DEALER_KEY,
            CAST(TAX_YEAR AS INT)                                  AS TAX_YEAR,
            CAST(OMNIBUS_SOURCE_KEY AS INT)                        AS OMNIBUS_SOURCE_KEY,
            CAST(ACCOUNT_PROFILE_KEY AS INT)                       AS ACCOUNT_PROFILE_KEY,
            CAST(TIME_KEY AS INT)                                  AS TIME_KEY,
            CAST(ACCOUNT_KEY AS INT)                               AS ACCOUNT_KEY,
            CAST(DISBURSEMENT_KEY AS INT)                          AS DISBURSEMENT_KEY,
            CAST(SETTLEMENT_STATUS AS INT)                         AS SETTLEMENT_STATUS,
            CAST(CSR_KEY AS INT)                                   AS CSR_KEY,
            CAST(TXN_TYPE_KEY AS INT)                              AS TXN_TYPE_KEY,
            CAST(BANK_PRODUCT_KEY AS INT)                          AS BANK_PRODUCT_KEY,
            CAST(SEQ_TXN_ID AS INT)                                AS SEQ_TXN_ID,
            CAST(FUND_KEY AS INT)                                  AS FUND_KEY,
            CAST(BRANCH_KEY AS INT)                                AS BRANCH_KEY,
            CAST(TLM AS DATETIME2(6))                              AS TLM,
            CAST(RUN_DATE AS DATETIME2(6))                         AS RUN_DATE,
            CAST(TRADE_DATE AS DATETIME2(6))                       AS TRADE_DATE,
            CAST(CTL_INS_DTTM AS DATETIME2(6))                     AS CTL_INS_DTTM,
            CAST(SETTLEMENT_DATE AS DATETIME2(6))                  AS SETTLEMENT_DATE,
            CAST(TRADE_CREATED AS CHAR(1))                         AS TRADE_CREATED,
            CAST(INITIAL_CONTRIB_FLAG AS CHAR(1))                  AS INITIAL_CONTRIB_FLAG,
            CAST(CAMPAIGN_NAME AS VARCHAR(MAX))                    AS CAMPAIGN_NAME,
            CAST(GROSS_NET_IND AS VARCHAR(MAX))                    AS GROSS_NET_IND,
            CAST(AS_OF_REASON AS VARCHAR(MAX))                     AS AS_OF_REASON,
            CAST(VOUCHER_NUMBER AS VARCHAR(MAX))                   AS VOUCHER_NUMBER,
            CAST(FROM_TO_ACCT_NUM AS VARCHAR(MAX))                 AS FROM_TO_ACCT_NUM,
            CAST(TXN_PLATFORM_CHANNEL AS VARCHAR(MAX))             AS TXN_PLATFORM_CHANNEL,
            CAST(NSCC_ORDER_NUM AS VARCHAR(MAX))                   AS NSCC_ORDER_NUM,
            CAST(MAX_CONTRIBUTION_OVERRIDE_FLAG AS VARCHAR(MAX))   AS MAX_CONTRIBUTION_OVERRIDE_FLAG,
            CAST(TXN_CHANNEL AS VARCHAR(MAX))                      AS TXN_CHANNEL,
            CAST(TRANSACTION_PARTNER AS VARCHAR(MAX))              AS TRANSACTION_PARTNER,
            CAST(TRADE_ORIGIN AS VARCHAR(MAX))                     AS TRADE_ORIGIN,
            CAST(FROM_TO_FUND_CODE AS VARCHAR(MAX))                AS FROM_TO_FUND_CODE,
            CAST(TRADE_ORIGIN_NAME AS VARCHAR(MAX))                AS TRADE_ORIGIN_NAME,
            CAST(FEED_JOB_ID AS INT)                               AS FEED_JOB_ID,
            CAST(FROM_TO_SEQ_ACCT_NUM AS INT)                      AS FROM_TO_SEQ_ACCT_NUM,
            CAST(FROM_TO_FUND_ID AS INT)                           AS FROM_TO_FUND_ID,
            CAST(DISCOUNT_CATEGORY_CODE AS INT)                    AS DISCOUNT_CATEGORY_CODE,
            CAST(SEQ_FIN_TXN_ID AS INT)                            AS SEQ_FIN_TXN_ID,
            CAST(GROSS_NET_IND_CODE AS INT)                        AS GROSS_NET_IND_CODE,
            CAST(ADV_COM_AMT AS DECIMAL(18,4))                     AS ADV_COM_AMT,
            CAST(DIST_COM_AMT AS DECIMAL(18,4))                    AS DIST_COM_AMT,
            CAST(DLR_COM_AMT AS DECIMAL(18,4))                     AS DLR_COM_AMT,
            CAST(TOTAL_COMMISSION_AMOUNT AS DECIMAL(18,4))         AS TOTAL_COMMISSION_AMOUNT,
            CAST(COMMISSION_RATE AS DECIMAL(18,6))                 AS COMMISSION_RATE,
            CAST(SHARES AS FLOAT)                                  AS SHARES,
            CAST(RUN_DATE_PRICE AS FLOAT)                          AS RUN_DATE_PRICE,
            CAST(TRADE_DATE_PRICE AS FLOAT)                        AS TRADE_DATE_PRICE,
            CAST(AMOUNT AS FLOAT)                                  AS AMOUNT
        INTO ' + @TgtFQN + '
        FROM ' + @SrcFQN + ';';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;
        SET @UpdatedRows = 0;
    END
    ELSE
    BEGIN

        SET @SQL = N'
        UPDATE tgt
        SET
            tgt.PLAN_KEY                        = CAST(src.PLAN_KEY AS INT),
            tgt.REP_KEY                          = CAST(src.REP_KEY AS INT),
            tgt.BENE_RUN_AGE                     = CAST(src.BENE_RUN_AGE AS INT),
            tgt.ACCT_OWNER_RUN_AGE               = CAST(src.ACCT_OWNER_RUN_AGE AS INT),
            tgt.DEALER_KEY                       = CAST(src.DEALER_KEY AS INT),
            tgt.TAX_YEAR                         = CAST(src.TAX_YEAR AS INT),
            tgt.ACCOUNT_PROFILE_KEY              = CAST(src.ACCOUNT_PROFILE_KEY AS INT),
            tgt.TIME_KEY                         = CAST(src.TIME_KEY AS INT),
            tgt.ACCOUNT_KEY                      = CAST(src.ACCOUNT_KEY AS INT),
            tgt.DISBURSEMENT_KEY                 = CAST(src.DISBURSEMENT_KEY AS INT),
            tgt.SETTLEMENT_STATUS                = CAST(src.SETTLEMENT_STATUS AS INT),
            tgt.CSR_KEY                          = CAST(src.CSR_KEY AS INT),
            tgt.TXN_TYPE_KEY                     = CAST(src.TXN_TYPE_KEY AS INT),
            tgt.BANK_PRODUCT_KEY                 = CAST(src.BANK_PRODUCT_KEY AS INT),
            tgt.FUND_KEY                         = CAST(src.FUND_KEY AS INT),
            tgt.BRANCH_KEY                       = CAST(src.BRANCH_KEY AS INT),
            tgt.TLM                              = CAST(src.TLM AS DATETIME2(6)),
            tgt.RUN_DATE                         = CAST(src.RUN_DATE AS DATETIME2(6)),
            tgt.TRADE_DATE                       = CAST(src.TRADE_DATE AS DATETIME2(6)),
            tgt.CTL_INS_DTTM                     = CAST(src.CTL_INS_DTTM AS DATETIME2(6)),
            tgt.SETTLEMENT_DATE                  = CAST(src.SETTLEMENT_DATE AS DATETIME2(6)),
            tgt.TRADE_CREATED                    = CAST(src.TRADE_CREATED AS CHAR(1)),
            tgt.INITIAL_CONTRIB_FLAG             = CAST(src.INITIAL_CONTRIB_FLAG AS CHAR(1)),
            tgt.CAMPAIGN_NAME                    = CAST(src.CAMPAIGN_NAME AS VARCHAR(MAX)),
            tgt.GROSS_NET_IND                    = CAST(src.GROSS_NET_IND AS VARCHAR(MAX)),
            tgt.AS_OF_REASON                     = CAST(src.AS_OF_REASON AS VARCHAR(MAX)),
            tgt.VOUCHER_NUMBER                   = CAST(src.VOUCHER_NUMBER AS VARCHAR(MAX)),
            tgt.FROM_TO_ACCT_NUM                 = CAST(src.FROM_TO_ACCT_NUM AS VARCHAR(MAX)),
            tgt.TXN_PLATFORM_CHANNEL             = CAST(src.TXN_PLATFORM_CHANNEL AS VARCHAR(MAX)),
            tgt.NSCC_ORDER_NUM                   = CAST(src.NSCC_ORDER_NUM AS VARCHAR(MAX)),
            tgt.MAX_CONTRIBUTION_OVERRIDE_FLAG   = CAST(src.MAX_CONTRIBUTION_OVERRIDE_FLAG AS VARCHAR(MAX)),
            tgt.TXN_CHANNEL                      = CAST(src.TXN_CHANNEL AS VARCHAR(MAX)),
            tgt.TRANSACTION_PARTNER              = CAST(src.TRANSACTION_PARTNER AS VARCHAR(MAX)),
            tgt.TRADE_ORIGIN                     = CAST(src.TRADE_ORIGIN AS VARCHAR(MAX)),
            tgt.FROM_TO_FUND_CODE                = CAST(src.FROM_TO_FUND_CODE AS VARCHAR(MAX)),
            tgt.TRADE_ORIGIN_NAME                = CAST(src.TRADE_ORIGIN_NAME AS VARCHAR(MAX)),
            tgt.FEED_JOB_ID                      = CAST(src.FEED_JOB_ID AS INT),
            tgt.FROM_TO_SEQ_ACCT_NUM             = CAST(src.FROM_TO_SEQ_ACCT_NUM AS INT),
            tgt.FROM_TO_FUND_ID                  = CAST(src.FROM_TO_FUND_ID AS INT),
            tgt.DISCOUNT_CATEGORY_CODE           = CAST(src.DISCOUNT_CATEGORY_CODE AS INT),
            tgt.SEQ_FIN_TXN_ID                   = CAST(src.SEQ_FIN_TXN_ID AS INT),
            tgt.GROSS_NET_IND_CODE               = CAST(src.GROSS_NET_IND_CODE AS INT),
            tgt.ADV_COM_AMT                      = CAST(src.ADV_COM_AMT AS DECIMAL(18,4)),
            tgt.DIST_COM_AMT                     = CAST(src.DIST_COM_AMT AS DECIMAL(18,4)),
            tgt.DLR_COM_AMT                      = CAST(src.DLR_COM_AMT AS DECIMAL(18,4)),
            tgt.TOTAL_COMMISSION_AMOUNT          = CAST(src.TOTAL_COMMISSION_AMOUNT AS DECIMAL(18,4)),
            tgt.COMMISSION_RATE                  = CAST(src.COMMISSION_RATE AS DECIMAL(18,6)),
            tgt.SHARES                           = CAST(src.SHARES AS FLOAT),
            tgt.RUN_DATE_PRICE                   = CAST(src.RUN_DATE_PRICE AS FLOAT),
            tgt.TRADE_DATE_PRICE                 = CAST(src.TRADE_DATE_PRICE AS FLOAT),
            tgt.AMOUNT                           = CAST(src.AMOUNT AS FLOAT)
        FROM ' + @TgtFQN + ' tgt
        INNER JOIN ' + @SrcFQN + ' src
            ON tgt.SEQ_TXN_ID          = CAST(src.SEQ_TXN_ID AS INT)
           AND tgt.PLATFORM_SOURCE     = CAST(src.PLATFORM_SOURCE AS INT)
           AND tgt.OMNIBUS_SOURCE_KEY  = CAST(src.OMNIBUS_SOURCE_KEY AS INT);';

        EXEC sp_executesql @SQL;

        SET @UpdatedRows = @@ROWCOUNT;

        SET @SQL = N'
        INSERT INTO ' + @TgtFQN + N'
        (
            PLAN_KEY, REP_KEY, BENE_RUN_AGE, PLATFORM_SOURCE, ACCT_OWNER_RUN_AGE,
            DEALER_KEY, TAX_YEAR, OMNIBUS_SOURCE_KEY, ACCOUNT_PROFILE_KEY, TIME_KEY,
            ACCOUNT_KEY, DISBURSEMENT_KEY, SETTLEMENT_STATUS, CSR_KEY, TXN_TYPE_KEY,
            BANK_PRODUCT_KEY, SEQ_TXN_ID, FUND_KEY, BRANCH_KEY, TLM,
            RUN_DATE, TRADE_DATE, CTL_INS_DTTM, SETTLEMENT_DATE, TRADE_CREATED,
            INITIAL_CONTRIB_FLAG, CAMPAIGN_NAME, GROSS_NET_IND, AS_OF_REASON, VOUCHER_NUMBER,
            FROM_TO_ACCT_NUM, TXN_PLATFORM_CHANNEL, NSCC_ORDER_NUM, MAX_CONTRIBUTION_OVERRIDE_FLAG, TXN_CHANNEL,
            TRANSACTION_PARTNER, TRADE_ORIGIN, FROM_TO_FUND_CODE, TRADE_ORIGIN_NAME, FEED_JOB_ID,
            FROM_TO_SEQ_ACCT_NUM, FROM_TO_FUND_ID, DISCOUNT_CATEGORY_CODE, SEQ_FIN_TXN_ID, GROSS_NET_IND_CODE,
            ADV_COM_AMT, DIST_COM_AMT, DLR_COM_AMT, TOTAL_COMMISSION_AMOUNT, COMMISSION_RATE,
            SHARES, RUN_DATE_PRICE, TRADE_DATE_PRICE, AMOUNT
        )
        SELECT
            CAST(src.PLAN_KEY AS INT),
            CAST(src.REP_KEY AS INT),
            CAST(src.BENE_RUN_AGE AS INT),
            CAST(src.PLATFORM_SOURCE AS INT),
            CAST(src.ACCT_OWNER_RUN_AGE AS INT),
            CAST(src.DEALER_KEY AS INT),
            CAST(src.TAX_YEAR AS INT),
            CAST(src.OMNIBUS_SOURCE_KEY AS INT),
            CAST(src.ACCOUNT_PROFILE_KEY AS INT),
            CAST(src.TIME_KEY AS INT),
            CAST(src.ACCOUNT_KEY AS INT),
            CAST(src.DISBURSEMENT_KEY AS INT),
            CAST(src.SETTLEMENT_STATUS AS INT),
            CAST(src.CSR_KEY AS INT),
            CAST(src.TXN_TYPE_KEY AS INT),
            CAST(src.BANK_PRODUCT_KEY AS INT),
            CAST(src.SEQ_TXN_ID AS INT),
            CAST(src.FUND_KEY AS INT),
            CAST(src.BRANCH_KEY AS INT),
            CAST(src.TLM AS DATETIME2(6)),
            CAST(src.RUN_DATE AS DATETIME2(6)),
            CAST(src.TRADE_DATE AS DATETIME2(6)),
            CAST(src.CTL_INS_DTTM AS DATETIME2(6)),
            CAST(src.SETTLEMENT_DATE AS DATETIME2(6)),
            CAST(src.TRADE_CREATED AS CHAR(1)),
            CAST(src.INITIAL_CONTRIB_FLAG AS CHAR(1)),
            CAST(src.CAMPAIGN_NAME AS VARCHAR(MAX)),
            CAST(src.GROSS_NET_IND AS VARCHAR(MAX)),
            CAST(src.AS_OF_REASON AS VARCHAR(MAX)),
            CAST(src.VOUCHER_NUMBER AS VARCHAR(MAX)),
            CAST(src.FROM_TO_ACCT_NUM AS VARCHAR(MAX)),
            CAST(src.TXN_PLATFORM_CHANNEL AS VARCHAR(MAX)),
            CAST(src.NSCC_ORDER_NUM AS VARCHAR(MAX)),
            CAST(src.MAX_CONTRIBUTION_OVERRIDE_FLAG AS VARCHAR(MAX)),
            CAST(src.TXN_CHANNEL AS VARCHAR(MAX)),
            CAST(src.TRANSACTION_PARTNER AS VARCHAR(MAX)),
            CAST(src.TRADE_ORIGIN AS VARCHAR(MAX)),
            CAST(src.FROM_TO_FUND_CODE AS VARCHAR(MAX)),
            CAST(src.TRADE_ORIGIN_NAME AS VARCHAR(MAX)),
            CAST(src.FEED_JOB_ID AS INT),
            CAST(src.FROM_TO_SEQ_ACCT_NUM AS INT),
            CAST(src.FROM_TO_FUND_ID AS INT),
            CAST(src.DISCOUNT_CATEGORY_CODE AS INT),
            CAST(src.SEQ_FIN_TXN_ID AS INT),
            CAST(src.GROSS_NET_IND_CODE AS INT),
            CAST(src.ADV_COM_AMT AS DECIMAL(18,4)),
            CAST(src.DIST_COM_AMT AS DECIMAL(18,4)),
            CAST(src.DLR_COM_AMT AS DECIMAL(18,4)),
            CAST(src.TOTAL_COMMISSION_AMOUNT AS DECIMAL(18,4)),
            CAST(src.COMMISSION_RATE AS DECIMAL(18,6)),
            CAST(src.SHARES AS FLOAT),
            CAST(src.RUN_DATE_PRICE AS FLOAT),
            CAST(src.TRADE_DATE_PRICE AS FLOAT),
            CAST(src.AMOUNT AS FLOAT)
        FROM ' + @SrcFQN + N' AS src
        WHERE NOT EXISTS (
            SELECT 1 FROM ' + @TgtFQN + N' AS tgt
            WHERE tgt.SEQ_TXN_ID          = CAST(src.SEQ_TXN_ID AS INT)
              AND tgt.PLATFORM_SOURCE     = CAST(src.PLATFORM_SOURCE AS INT)
              AND tgt.OMNIBUS_SOURCE_KEY  = CAST(src.OMNIBUS_SOURCE_KEY AS INT)
        );';

        EXEC sp_executesql @SQL;

        SET @InsertedRows = @@ROWCOUNT;

    END;

    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'SUCCESS', NULL);

END TRY
BEGIN CATCH
    INSERT INTO #Logs VALUES (@TgtObjectId, @StartTime, SYSDATETIME(), @InsertedRows + @UpdatedRows, 'FAILED', ERROR_MESSAGE());

    INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
    SELECT TableName, StartTime, EndTime, DATEDIFF(SECOND, StartTime, EndTime), RowsAffected, Status, ErrorMessage
    FROM #Logs;

    THROW;
END CATCH;

------------------------------------------------------------
-- Insert all collected logs in a single multi-row insert statement
------------------------------------------------------------
INSERT INTO Metadata.Upsert_LOG (TableName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
SELECT 
    TableName, 
    StartTime, 
    EndTime, 
    DATEDIFF(SECOND, StartTime, EndTime), 
    RowsAffected, 
    Status, 
    ErrorMessage
FROM #Logs;

DROP TABLE #Logs;
