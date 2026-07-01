/* ================================================================
   AA2.0 STAGE -> DBO LOAD PROCEDURES (Fabric Warehouse / T-SQL)
   Combined script - deploy in order shown below.
   ================================================================ */

-- ================================================================
-- FILE: 00_dbo.ETL_LOAD_LOG.sql
-- ================================================================
/* ============================================================
   dbo.ETL_LOAD_LOG
   Centralized logging table for all Stage -> dbo load procedures.
   Each run inserts one row at start and one row at completion
   (no update-by-id lookup, no separate logging procedure).
   ============================================================ */

IF OBJECT_ID('dbo.ETL_LOAD_LOG', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ETL_LOAD_LOG
    (
        TableName       VARCHAR(200)    NOT NULL,
        ProcedureName   VARCHAR(200)    NOT NULL,
        StartTime       DATETIME2(6)    NOT NULL,
        EndTime         DATETIME2(6)    NULL,
        DurationSeconds INT             NULL,
        RowsAffected    BIGINT          NULL,
        Status          VARCHAR(20)     NOT NULL,   -- STARTED / SUCCESS / FAILED
        ErrorMessage    VARCHAR(4000)   NULL,
        LogDate         DATE            NOT NULL DEFAULT CAST(GETDATE() AS DATE)
    );
END
GO

-- ================================================================
-- FILE: 01_sp_Load_V_T_F_ACCOUNT_CLOSURE_AAV2.sql
-- ================================================================
/* ============================================================
   dbo.sp_Load_V_T_F_ACCOUNT_CLOSURE_AAV2
   Source : Stage.DW_BI_DEV_V_T_F_ACCOUNT_CLOSURE_AAV2
   Target : dbo.V_T_F_ACCOUNT_CLOSURE_AAV2
   Keys   : ACCOUNT_PROFILE_KEY, ACCOUNT_CLOSURE_TIME_KEY

   Source -> Target type mapping applied on SELECT:
     NUMBER        -> DECIMAL(18,2)
     TIMESTAMP(6)  -> DATETIME2(6)
     DATE          -> DATE
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_Load_V_T_F_ACCOUNT_CLOSURE_AAV2
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TableName     VARCHAR(200) = 'dbo.V_T_F_ACCOUNT_CLOSURE_AAV2';
    DECLARE @ProcedureName VARCHAR(200) = 'dbo.sp_Load_V_T_F_ACCOUNT_CLOSURE_AAV2';
    DECLARE @StartTime     DATETIME2(6) = SYSDATETIME();
    DECLARE @EndTime       DATETIME2(6);
    DECLARE @Duration      INT;
    DECLARE @ErrorMessage  VARCHAR(4000) = NULL;
    DECLARE @RowsAffected  BIGINT = 0;
    DECLARE @Status        VARCHAR(20) = 'STARTED';
    DECLARE @InsertedRows  BIGINT = 0;
    DECLARE @UpdatedRows   BIGINT = 0;

    INSERT INTO dbo.ETL_LOAD_LOG (TableName, ProcedureName, StartTime, Status)
    VALUES (@TableName, @ProcedureName, @StartTime, @Status);

    BEGIN TRY

        IF OBJECT_ID('tempdb..#StgAccountClosure') IS NOT NULL
            DROP TABLE #StgAccountClosure;

        SELECT
            CAST(PLAN_KEY                AS DECIMAL(18,2)) AS PLAN_KEY,
            CAST(ACCOUNT_PROFILE_KEY      AS DECIMAL(18,2)) AS ACCOUNT_PROFILE_KEY,
            CAST(ACCOUNT_CLOSURE_TIME_KEY AS DECIMAL(18,2)) AS ACCOUNT_CLOSURE_TIME_KEY,
            CAST(BENE_AGE_KEY             AS DECIMAL(18,2)) AS BENE_AGE_KEY,
            CAST(CLOSURE_DATE             AS DATE)          AS CLOSURE_DATE,
            CAST(DW_INS_DTTM              AS DATETIME2(6))  AS DW_INS_DTTM,
            CAST(DW_UPD_DTTM              AS DATETIME2(6))  AS DW_UPD_DTTM
        INTO #StgAccountClosure
        FROM Stage.DW_BI_DEV_V_T_F_ACCOUNT_CLOSURE_AAV2;

        IF OBJECT_ID('dbo.V_T_F_ACCOUNT_CLOSURE_AAV2', 'U') IS NULL
        BEGIN
            CREATE TABLE dbo.V_T_F_ACCOUNT_CLOSURE_AAV2
            (
                PLAN_KEY                DECIMAL(18,2),
                ACCOUNT_PROFILE_KEY      DECIMAL(18,2) NOT NULL,
                ACCOUNT_CLOSURE_TIME_KEY DECIMAL(18,2) NOT NULL,
                BENE_AGE_KEY             DECIMAL(18,2),
                CLOSURE_DATE             DATE,
                DW_INS_DTTM              DATETIME2(6),
                DW_UPD_DTTM              DATETIME2(6),
                DW_LOAD_DTTM             DATETIME2(6) NOT NULL DEFAULT SYSDATETIME()
            );
        END

        UPDATE tgt
        SET
            tgt.PLAN_KEY     = src.PLAN_KEY,
            tgt.BENE_AGE_KEY = src.BENE_AGE_KEY,
            tgt.CLOSURE_DATE = src.CLOSURE_DATE,
            tgt.DW_INS_DTTM  = src.DW_INS_DTTM,
            tgt.DW_UPD_DTTM  = src.DW_UPD_DTTM,
            tgt.DW_LOAD_DTTM = SYSDATETIME()
        FROM dbo.V_T_F_ACCOUNT_CLOSURE_AAV2 AS tgt
        INNER JOIN #StgAccountClosure AS src
            ON tgt.ACCOUNT_PROFILE_KEY      = src.ACCOUNT_PROFILE_KEY
           AND tgt.ACCOUNT_CLOSURE_TIME_KEY = src.ACCOUNT_CLOSURE_TIME_KEY;

        SET @UpdatedRows = @@ROWCOUNT;

        INSERT INTO dbo.V_T_F_ACCOUNT_CLOSURE_AAV2
        (
            PLAN_KEY, ACCOUNT_PROFILE_KEY, ACCOUNT_CLOSURE_TIME_KEY,
            BENE_AGE_KEY, CLOSURE_DATE, DW_INS_DTTM, DW_UPD_DTTM, DW_LOAD_DTTM
        )
        SELECT
            src.PLAN_KEY, src.ACCOUNT_PROFILE_KEY, src.ACCOUNT_CLOSURE_TIME_KEY,
            src.BENE_AGE_KEY, src.CLOSURE_DATE, src.DW_INS_DTTM, src.DW_UPD_DTTM, SYSDATETIME()
        FROM #StgAccountClosure AS src
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.V_T_F_ACCOUNT_CLOSURE_AAV2 AS tgt
            WHERE tgt.ACCOUNT_PROFILE_KEY      = src.ACCOUNT_PROFILE_KEY
              AND tgt.ACCOUNT_CLOSURE_TIME_KEY = src.ACCOUNT_CLOSURE_TIME_KEY
        );

        SET @InsertedRows = @@ROWCOUNT;
        SET @RowsAffected = @InsertedRows + @UpdatedRows;

        IF OBJECT_ID('tempdb..#StgAccountClosure') IS NOT NULL
            DROP TABLE #StgAccountClosure;

        SET @EndTime  = SYSDATETIME();
        SET @Duration = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status   = 'SUCCESS';

        INSERT INTO dbo.ETL_LOAD_LOG
            (TableName, ProcedureName, StartTime, EndTime, DurationSeconds, RowsAffected, Status)
        VALUES
            (@TableName, @ProcedureName, @StartTime, @EndTime, @Duration, @RowsAffected, @Status);

    END TRY
    BEGIN CATCH

        IF OBJECT_ID('tempdb..#StgAccountClosure') IS NOT NULL
            DROP TABLE #StgAccountClosure;

        SET @EndTime      = SYSDATETIME();
        SET @Duration     = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status       = 'FAILED';
        SET @ErrorMessage = ERROR_MESSAGE();

        INSERT INTO dbo.ETL_LOAD_LOG
            (TableName, ProcedureName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
        VALUES
            (@TableName, @ProcedureName, @StartTime, @EndTime, @Duration, @RowsAffected, @Status, @ErrorMessage);

        THROW;

    END CATCH
END
GO

-- ================================================================
-- FILE: 02_sp_Load_V_T_F_ACCOUNT_ENROLLMENT_AAV2.sql
-- ================================================================
/* ============================================================
   dbo.sp_Load_V_T_F_ACCOUNT_ENROLLMENT_AAV2
   Source : Stage.DW_BI_DEV_V_T_F_ACCOUNT_ENROLLMENT_AAV2
   Target : dbo.V_T_F_ACCOUNT_ENROLLMENT_AAV2
   Keys   : ACCOUNT_PROFILE_KEY, ACCOUNT_TC_ACCEPTED_TIME_KEY

   Source -> Target type mapping applied on SELECT:
     NUMBER        -> DECIMAL(18,2)
     TIMESTAMP(6)  -> DATETIME2(6)
     DATE          -> DATE
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_Load_V_T_F_ACCOUNT_ENROLLMENT_AAV2
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TableName     VARCHAR(200) = 'dbo.V_T_F_ACCOUNT_ENROLLMENT_AAV2';
    DECLARE @ProcedureName VARCHAR(200) = 'dbo.sp_Load_V_T_F_ACCOUNT_ENROLLMENT_AAV2';
    DECLARE @StartTime     DATETIME2(6) = SYSDATETIME();
    DECLARE @EndTime       DATETIME2(6);
    DECLARE @Duration      INT;
    DECLARE @ErrorMessage  VARCHAR(4000) = NULL;
    DECLARE @RowsAffected  BIGINT = 0;
    DECLARE @Status        VARCHAR(20) = 'STARTED';
    DECLARE @InsertedRows  BIGINT = 0;
    DECLARE @UpdatedRows   BIGINT = 0;

    INSERT INTO dbo.ETL_LOAD_LOG (TableName, ProcedureName, StartTime, Status)
    VALUES (@TableName, @ProcedureName, @StartTime, @Status);

    BEGIN TRY

        IF OBJECT_ID('tempdb..#StgAccountEnrollment') IS NOT NULL
            DROP TABLE #StgAccountEnrollment;

        SELECT
            CAST(PLAN_KEY                    AS DECIMAL(18,2)) AS PLAN_KEY,
            CAST(ACCOUNT_PROFILE_KEY          AS DECIMAL(18,2)) AS ACCOUNT_PROFILE_KEY,
            CAST(ACCOUNT_TC_ACCEPTED_TIME_KEY AS DECIMAL(18,2)) AS ACCOUNT_TC_ACCEPTED_TIME_KEY,
            CAST(ACCOUNT_ENROLL_TIME_KEY      AS DECIMAL(18,2)) AS ACCOUNT_ENROLL_TIME_KEY,
            CAST(INITIAL_CONTRIB_AMOUNT       AS DECIMAL(18,2)) AS INITIAL_CONTRIB_AMOUNT,
            CAST(BENE_AGE_KEY                 AS DECIMAL(18,2)) AS BENE_AGE_KEY,
            CAST(ENROLLMENT_DATE              AS DATE)          AS ENROLLMENT_DATE,
            CAST(SRC_UPD_TS                    AS DATETIME2(6)) AS SRC_UPD_TS,
            CAST(SRC_INS_TS                    AS DATETIME2(6)) AS SRC_INS_TS
        INTO #StgAccountEnrollment
        FROM Stage.DW_BI_DEV_V_T_F_ACCOUNT_ENROLLMENT_AAV2;

        IF OBJECT_ID('dbo.V_T_F_ACCOUNT_ENROLLMENT_AAV2', 'U') IS NULL
        BEGIN
            CREATE TABLE dbo.V_T_F_ACCOUNT_ENROLLMENT_AAV2
            (
                PLAN_KEY                    DECIMAL(18,2),
                ACCOUNT_PROFILE_KEY          DECIMAL(18,2) NOT NULL,
                ACCOUNT_TC_ACCEPTED_TIME_KEY DECIMAL(18,2) NOT NULL,
                ACCOUNT_ENROLL_TIME_KEY      DECIMAL(18,2),
                INITIAL_CONTRIB_AMOUNT       DECIMAL(18,2),
                BENE_AGE_KEY                 DECIMAL(18,2),
                ENROLLMENT_DATE              DATE,
                SRC_UPD_TS                   DATETIME2(6),
                SRC_INS_TS                   DATETIME2(6),
                DW_LOAD_DTTM                 DATETIME2(6) NOT NULL DEFAULT SYSDATETIME()
            );
        END

        UPDATE tgt
        SET
            tgt.PLAN_KEY                = src.PLAN_KEY,
            tgt.ACCOUNT_ENROLL_TIME_KEY = src.ACCOUNT_ENROLL_TIME_KEY,
            tgt.INITIAL_CONTRIB_AMOUNT  = src.INITIAL_CONTRIB_AMOUNT,
            tgt.BENE_AGE_KEY            = src.BENE_AGE_KEY,
            tgt.ENROLLMENT_DATE         = src.ENROLLMENT_DATE,
            tgt.SRC_UPD_TS              = src.SRC_UPD_TS,
            tgt.SRC_INS_TS              = src.SRC_INS_TS,
            tgt.DW_LOAD_DTTM            = SYSDATETIME()
        FROM dbo.V_T_F_ACCOUNT_ENROLLMENT_AAV2 AS tgt
        INNER JOIN #StgAccountEnrollment AS src
            ON tgt.ACCOUNT_PROFILE_KEY          = src.ACCOUNT_PROFILE_KEY
           AND tgt.ACCOUNT_TC_ACCEPTED_TIME_KEY = src.ACCOUNT_TC_ACCEPTED_TIME_KEY;

        SET @UpdatedRows = @@ROWCOUNT;

        INSERT INTO dbo.V_T_F_ACCOUNT_ENROLLMENT_AAV2
        (
            PLAN_KEY, ACCOUNT_PROFILE_KEY, ACCOUNT_TC_ACCEPTED_TIME_KEY, ACCOUNT_ENROLL_TIME_KEY,
            INITIAL_CONTRIB_AMOUNT, BENE_AGE_KEY, ENROLLMENT_DATE, SRC_UPD_TS, SRC_INS_TS, DW_LOAD_DTTM
        )
        SELECT
            src.PLAN_KEY, src.ACCOUNT_PROFILE_KEY, src.ACCOUNT_TC_ACCEPTED_TIME_KEY, src.ACCOUNT_ENROLL_TIME_KEY,
            src.INITIAL_CONTRIB_AMOUNT, src.BENE_AGE_KEY, src.ENROLLMENT_DATE, src.SRC_UPD_TS, src.SRC_INS_TS, SYSDATETIME()
        FROM #StgAccountEnrollment AS src
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.V_T_F_ACCOUNT_ENROLLMENT_AAV2 AS tgt
            WHERE tgt.ACCOUNT_PROFILE_KEY          = src.ACCOUNT_PROFILE_KEY
              AND tgt.ACCOUNT_TC_ACCEPTED_TIME_KEY = src.ACCOUNT_TC_ACCEPTED_TIME_KEY
        );

        SET @InsertedRows = @@ROWCOUNT;
        SET @RowsAffected = @InsertedRows + @UpdatedRows;

        IF OBJECT_ID('tempdb..#StgAccountEnrollment') IS NOT NULL
            DROP TABLE #StgAccountEnrollment;

        SET @EndTime  = SYSDATETIME();
        SET @Duration = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status   = 'SUCCESS';

        INSERT INTO dbo.ETL_LOAD_LOG
            (TableName, ProcedureName, StartTime, EndTime, DurationSeconds, RowsAffected, Status)
        VALUES
            (@TableName, @ProcedureName, @StartTime, @EndTime, @Duration, @RowsAffected, @Status);

    END TRY
    BEGIN CATCH

        IF OBJECT_ID('tempdb..#StgAccountEnrollment') IS NOT NULL
            DROP TABLE #StgAccountEnrollment;

        SET @EndTime      = SYSDATETIME();
        SET @Duration     = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status       = 'FAILED';
        SET @ErrorMessage = ERROR_MESSAGE();

        INSERT INTO dbo.ETL_LOAD_LOG
            (TableName, ProcedureName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
        VALUES
            (@TableName, @ProcedureName, @StartTime, @EndTime, @Duration, @RowsAffected, @Status, @ErrorMessage);

        THROW;

    END CATCH
END
GO

-- ================================================================
-- FILE: 03_sp_Load_T_D_ORGANIZATION_STATUS.sql
-- ================================================================
/* ============================================================
   dbo.sp_Load_T_D_ORGANIZATION_STATUS
   Source : Stage.UIIDWP01_T_D_ORGANIZATION_STATUS
   Target : dbo.T_D_ORGANIZATION_STATUS
   Keys   : ORGANIZATION_STATUS_KEY

   Source -> Target type mapping applied on SELECT:
     NUMBER    -> DECIMAL(18,2)
     VARCHAR2  -> VARCHAR(MAX)
     TIMESTAMP(6) -> DATETIME2(6)
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_Load_T_D_ORGANIZATION_STATUS
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TableName     VARCHAR(200) = 'dbo.T_D_ORGANIZATION_STATUS';
    DECLARE @ProcedureName VARCHAR(200) = 'dbo.sp_Load_T_D_ORGANIZATION_STATUS';
    DECLARE @StartTime     DATETIME2(6) = SYSDATETIME();
    DECLARE @EndTime       DATETIME2(6);
    DECLARE @Duration      INT;
    DECLARE @ErrorMessage  VARCHAR(4000) = NULL;
    DECLARE @RowsAffected  BIGINT = 0;
    DECLARE @Status        VARCHAR(20) = 'STARTED';
    DECLARE @InsertedRows  BIGINT = 0;
    DECLARE @UpdatedRows   BIGINT = 0;

    INSERT INTO dbo.ETL_LOAD_LOG (TableName, ProcedureName, StartTime, Status)
    VALUES (@TableName, @ProcedureName, @StartTime, @Status);

    BEGIN TRY

        IF OBJECT_ID('tempdb..#StgOrgStatus') IS NOT NULL
            DROP TABLE #StgOrgStatus;

        SELECT
            CAST(DW_ETL_JOB_ID           AS DECIMAL(18,2)) AS DW_ETL_JOB_ID,
            CAST(ORGANIZATION_STATUS_KEY  AS DECIMAL(18,2)) AS ORGANIZATION_STATUS_KEY,
            CAST(ORGANIZATION_STATUS_DESCR AS VARCHAR(MAX)) AS ORGANIZATION_STATUS_DESCR,
            CAST(ORGANIZATION_STATUS_CODE  AS VARCHAR(MAX)) AS ORGANIZATION_STATUS_CODE,
            CAST(DW_CHANGE_ID             AS VARCHAR(MAX)) AS DW_CHANGE_ID,
            CAST(DW_UPD_DTTM              AS DATETIME2(6)) AS DW_UPD_DTTM,
            CAST(DW_INS_DTTM              AS DATETIME2(6)) AS DW_INS_DTTM
        INTO #StgOrgStatus
        FROM Stage.UIIDWP01_T_D_ORGANIZATION_STATUS;

        IF OBJECT_ID('dbo.T_D_ORGANIZATION_STATUS', 'U') IS NULL
        BEGIN
            CREATE TABLE dbo.T_D_ORGANIZATION_STATUS
            (
                DW_ETL_JOB_ID            DECIMAL(18,2),
                ORGANIZATION_STATUS_KEY   DECIMAL(18,2) NOT NULL,
                ORGANIZATION_STATUS_DESCR VARCHAR(MAX),
                ORGANIZATION_STATUS_CODE  VARCHAR(MAX),
                DW_CHANGE_ID              VARCHAR(MAX),
                DW_UPD_DTTM               DATETIME2(6),
                DW_INS_DTTM               DATETIME2(6),
                DW_LOAD_DTTM              DATETIME2(6) NOT NULL DEFAULT SYSDATETIME()
            );
        END

        UPDATE tgt
        SET
            tgt.DW_ETL_JOB_ID            = src.DW_ETL_JOB_ID,
            tgt.ORGANIZATION_STATUS_DESCR = src.ORGANIZATION_STATUS_DESCR,
            tgt.ORGANIZATION_STATUS_CODE  = src.ORGANIZATION_STATUS_CODE,
            tgt.DW_CHANGE_ID              = src.DW_CHANGE_ID,
            tgt.DW_UPD_DTTM               = src.DW_UPD_DTTM,
            tgt.DW_INS_DTTM               = src.DW_INS_DTTM,
            tgt.DW_LOAD_DTTM              = SYSDATETIME()
        FROM dbo.T_D_ORGANIZATION_STATUS AS tgt
        INNER JOIN #StgOrgStatus AS src
            ON tgt.ORGANIZATION_STATUS_KEY = src.ORGANIZATION_STATUS_KEY;

        SET @UpdatedRows = @@ROWCOUNT;

        INSERT INTO dbo.T_D_ORGANIZATION_STATUS
        (
            DW_ETL_JOB_ID, ORGANIZATION_STATUS_KEY, ORGANIZATION_STATUS_DESCR,
            ORGANIZATION_STATUS_CODE, DW_CHANGE_ID, DW_UPD_DTTM, DW_INS_DTTM, DW_LOAD_DTTM
        )
        SELECT
            src.DW_ETL_JOB_ID, src.ORGANIZATION_STATUS_KEY, src.ORGANIZATION_STATUS_DESCR,
            src.ORGANIZATION_STATUS_CODE, src.DW_CHANGE_ID, src.DW_UPD_DTTM, src.DW_INS_DTTM, SYSDATETIME()
        FROM #StgOrgStatus AS src
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.T_D_ORGANIZATION_STATUS AS tgt
            WHERE tgt.ORGANIZATION_STATUS_KEY = src.ORGANIZATION_STATUS_KEY
        );

        SET @InsertedRows = @@ROWCOUNT;
        SET @RowsAffected = @InsertedRows + @UpdatedRows;

        IF OBJECT_ID('tempdb..#StgOrgStatus') IS NOT NULL
            DROP TABLE #StgOrgStatus;

        SET @EndTime  = SYSDATETIME();
        SET @Duration = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status   = 'SUCCESS';

        INSERT INTO dbo.ETL_LOAD_LOG
            (TableName, ProcedureName, StartTime, EndTime, DurationSeconds, RowsAffected, Status)
        VALUES
            (@TableName, @ProcedureName, @StartTime, @EndTime, @Duration, @RowsAffected, @Status);

    END TRY
    BEGIN CATCH

        IF OBJECT_ID('tempdb..#StgOrgStatus') IS NOT NULL
            DROP TABLE #StgOrgStatus;

        SET @EndTime      = SYSDATETIME();
        SET @Duration     = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status       = 'FAILED';
        SET @ErrorMessage = ERROR_MESSAGE();

        INSERT INTO dbo.ETL_LOAD_LOG
            (TableName, ProcedureName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
        VALUES
            (@TableName, @ProcedureName, @StartTime, @EndTime, @Duration, @RowsAffected, @Status, @ErrorMessage);

        THROW;

    END CATCH
END
GO

-- ================================================================
-- FILE: 04_sp_Load_T_D_ORGANIZATION_TYPE.sql
-- ================================================================
/* ============================================================
   dbo.sp_Load_T_D_ORGANIZATION_TYPE
   Source : Stage.UIIDWP01_T_D_ORGANIZATION_TYPE
   Target : dbo.T_D_ORGANIZATION_TYPE
   Keys   : ORGANIZATION_TYPE_KEY

   Source -> Target type mapping applied on SELECT:
     NUMBER    -> DECIMAL(18,2)
     VARCHAR2  -> VARCHAR(MAX)
     TIMESTAMP(6) -> DATETIME2(6)
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_Load_T_D_ORGANIZATION_TYPE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TableName     VARCHAR(200) = 'dbo.T_D_ORGANIZATION_TYPE';
    DECLARE @ProcedureName VARCHAR(200) = 'dbo.sp_Load_T_D_ORGANIZATION_TYPE';
    DECLARE @StartTime     DATETIME2(6) = SYSDATETIME();
    DECLARE @EndTime       DATETIME2(6);
    DECLARE @Duration      INT;
    DECLARE @ErrorMessage  VARCHAR(4000) = NULL;
    DECLARE @RowsAffected  BIGINT = 0;
    DECLARE @Status        VARCHAR(20) = 'STARTED';
    DECLARE @InsertedRows  BIGINT = 0;
    DECLARE @UpdatedRows   BIGINT = 0;

    INSERT INTO dbo.ETL_LOAD_LOG (TableName, ProcedureName, StartTime, Status)
    VALUES (@TableName, @ProcedureName, @StartTime, @Status);

    BEGIN TRY

        IF OBJECT_ID('tempdb..#StgOrgType') IS NOT NULL
            DROP TABLE #StgOrgType;

        SELECT
            CAST(DW_ETL_JOB_ID         AS DECIMAL(18,2)) AS DW_ETL_JOB_ID,
            CAST(ORGANIZATION_TYPE_KEY  AS DECIMAL(18,2)) AS ORGANIZATION_TYPE_KEY,
            CAST(ORGANIZATION_TYPE_DESCR AS VARCHAR(MAX)) AS ORGANIZATION_TYPE_DESCR,
            CAST(ORGANIZATION_TYPE_CODE  AS VARCHAR(MAX)) AS ORGANIZATION_TYPE_CODE,
            CAST(DW_CHANGE_ID           AS VARCHAR(MAX)) AS DW_CHANGE_ID,
            CAST(DW_UPD_DTTM            AS DATETIME2(6)) AS DW_UPD_DTTM,
            CAST(DW_INS_DTTM            AS DATETIME2(6)) AS DW_INS_DTTM
        INTO #StgOrgType
        FROM Stage.UIIDWP01_T_D_ORGANIZATION_TYPE;

        IF OBJECT_ID('dbo.T_D_ORGANIZATION_TYPE', 'U') IS NULL
        BEGIN
            CREATE TABLE dbo.T_D_ORGANIZATION_TYPE
            (
                DW_ETL_JOB_ID          DECIMAL(18,2),
                ORGANIZATION_TYPE_KEY   DECIMAL(18,2) NOT NULL,
                ORGANIZATION_TYPE_DESCR VARCHAR(MAX),
                ORGANIZATION_TYPE_CODE  VARCHAR(MAX),
                DW_CHANGE_ID            VARCHAR(MAX),
                DW_UPD_DTTM             DATETIME2(6),
                DW_INS_DTTM             DATETIME2(6),
                DW_LOAD_DTTM            DATETIME2(6) NOT NULL DEFAULT SYSDATETIME()
            );
        END

        UPDATE tgt
        SET
            tgt.DW_ETL_JOB_ID          = src.DW_ETL_JOB_ID,
            tgt.ORGANIZATION_TYPE_DESCR = src.ORGANIZATION_TYPE_DESCR,
            tgt.ORGANIZATION_TYPE_CODE  = src.ORGANIZATION_TYPE_CODE,
            tgt.DW_CHANGE_ID            = src.DW_CHANGE_ID,
            tgt.DW_UPD_DTTM             = src.DW_UPD_DTTM,
            tgt.DW_INS_DTTM             = src.DW_INS_DTTM,
            tgt.DW_LOAD_DTTM            = SYSDATETIME()
        FROM dbo.T_D_ORGANIZATION_TYPE AS tgt
        INNER JOIN #StgOrgType AS src
            ON tgt.ORGANIZATION_TYPE_KEY = src.ORGANIZATION_TYPE_KEY;

        SET @UpdatedRows = @@ROWCOUNT;

        INSERT INTO dbo.T_D_ORGANIZATION_TYPE
        (
            DW_ETL_JOB_ID, ORGANIZATION_TYPE_KEY, ORGANIZATION_TYPE_DESCR,
            ORGANIZATION_TYPE_CODE, DW_CHANGE_ID, DW_UPD_DTTM, DW_INS_DTTM, DW_LOAD_DTTM
        )
        SELECT
            src.DW_ETL_JOB_ID, src.ORGANIZATION_TYPE_KEY, src.ORGANIZATION_TYPE_DESCR,
            src.ORGANIZATION_TYPE_CODE, src.DW_CHANGE_ID, src.DW_UPD_DTTM, src.DW_INS_DTTM, SYSDATETIME()
        FROM #StgOrgType AS src
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.T_D_ORGANIZATION_TYPE AS tgt
            WHERE tgt.ORGANIZATION_TYPE_KEY = src.ORGANIZATION_TYPE_KEY
        );

        SET @InsertedRows = @@ROWCOUNT;
        SET @RowsAffected = @InsertedRows + @UpdatedRows;

        IF OBJECT_ID('tempdb..#StgOrgType') IS NOT NULL
            DROP TABLE #StgOrgType;

        SET @EndTime  = SYSDATETIME();
        SET @Duration = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status   = 'SUCCESS';

        INSERT INTO dbo.ETL_LOAD_LOG
            (TableName, ProcedureName, StartTime, EndTime, DurationSeconds, RowsAffected, Status)
        VALUES
            (@TableName, @ProcedureName, @StartTime, @EndTime, @Duration, @RowsAffected, @Status);

    END TRY
    BEGIN CATCH

        IF OBJECT_ID('tempdb..#StgOrgType') IS NOT NULL
            DROP TABLE #StgOrgType;

        SET @EndTime      = SYSDATETIME();
        SET @Duration     = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status       = 'FAILED';
        SET @ErrorMessage = ERROR_MESSAGE();

        INSERT INTO dbo.ETL_LOAD_LOG
            (TableName, ProcedureName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
        VALUES
            (@TableName, @ProcedureName, @StartTime, @EndTime, @Duration, @RowsAffected, @Status, @ErrorMessage);

        THROW;

    END CATCH
END
GO

-- ================================================================
-- FILE: 05_sp_Load_T_F_ORGANIZATION_ACCOUNT.sql
-- ================================================================
/* ============================================================
   dbo.sp_Load_T_F_ORGANIZATION_ACCOUNT
   Source : Stage.UIIDWP01_T_F_ORGANIZATION_ACCOUNT
   Target : dbo.T_F_ORGANIZATION_ACCOUNT
   Keys   : ORGANIZATION_KEY, ACCOUNT_PROFILE_KEY, ACCOUNT_KEY, EFFECTIVE_DATE

   Source -> Target type mapping applied on SELECT:
     NUMBER       -> DECIMAL(18,2)
     VARCHAR2     -> VARCHAR(MAX)
     TIMESTAMP(6) -> DATETIME2(6)
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_Load_T_F_ORGANIZATION_ACCOUNT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TableName     VARCHAR(200) = 'dbo.T_F_ORGANIZATION_ACCOUNT';
    DECLARE @ProcedureName VARCHAR(200) = 'dbo.sp_Load_T_F_ORGANIZATION_ACCOUNT';
    DECLARE @StartTime     DATETIME2(6) = SYSDATETIME();
    DECLARE @EndTime       DATETIME2(6);
    DECLARE @Duration      INT;
    DECLARE @ErrorMessage  VARCHAR(4000) = NULL;
    DECLARE @RowsAffected  BIGINT = 0;
    DECLARE @Status        VARCHAR(20) = 'STARTED';
    DECLARE @InsertedRows  BIGINT = 0;
    DECLARE @UpdatedRows   BIGINT = 0;

    INSERT INTO dbo.ETL_LOAD_LOG (TableName, ProcedureName, StartTime, Status)
    VALUES (@TableName, @ProcedureName, @StartTime, @Status);

    BEGIN TRY

        IF OBJECT_ID('tempdb..#StgOrgAccount') IS NOT NULL
            DROP TABLE #StgOrgAccount;

        SELECT
            CAST(DW_ETL_JOB_ID              AS DECIMAL(18,2)) AS DW_ETL_JOB_ID,
            CAST(ACCOUNT_PROFILE_KEY         AS DECIMAL(18,2)) AS ACCOUNT_PROFILE_KEY,
            CAST(ACCOUNT_KEY                 AS DECIMAL(18,2)) AS ACCOUNT_KEY,
            CAST(ORGANIZATION_TYPE_KEY       AS DECIMAL(18,2)) AS ORGANIZATION_TYPE_KEY,
            CAST(ORGANIZATION_STATUS_KEY     AS DECIMAL(18,2)) AS ORGANIZATION_STATUS_KEY,
            CAST(EFFECTIVE_TIME_KEY          AS DECIMAL(18,2)) AS EFFECTIVE_TIME_KEY,
            CAST(ORGANIZATION_KEY            AS DECIMAL(18,2)) AS ORGANIZATION_KEY,
            CAST(PLAN_KEY                    AS DECIMAL(18,2)) AS PLAN_KEY,
            CAST(AUTH_INDIV_TYPE_CODE_DESCR  AS VARCHAR(MAX))  AS AUTH_INDIV_TYPE_CODE_DESCR,
            CAST(ORGANIZATION_TYPE_DESCR     AS VARCHAR(MAX))  AS ORGANIZATION_TYPE_DESCR,
            CAST(ORGANIZATION_STATUS_DESCR   AS VARCHAR(MAX))  AS ORGANIZATION_STATUS_DESCR,
            CAST(ORGANIZATION_TYPE_CODE      AS VARCHAR(MAX))  AS ORGANIZATION_TYPE_CODE,
            CAST(ORGANIZATION_STATUS_CODE    AS VARCHAR(MAX))  AS ORGANIZATION_STATUS_CODE,
            CAST(DW_CHANGE_ID                AS VARCHAR(MAX))  AS DW_CHANGE_ID,
            CAST(DW_UPD_DTTM                 AS DATETIME2(6))  AS DW_UPD_DTTM,
            CAST(DW_INS_DTTM                 AS DATETIME2(6))  AS DW_INS_DTTM,
            CAST(END_DATE                    AS DATETIME2(6))  AS END_DATE,
            CAST(EFFECTIVE_DATE              AS DATETIME2(6))  AS EFFECTIVE_DATE
        INTO #StgOrgAccount
        FROM Stage.UIIDWP01_T_F_ORGANIZATION_ACCOUNT;

        IF OBJECT_ID('dbo.T_F_ORGANIZATION_ACCOUNT', 'U') IS NULL
        BEGIN
            CREATE TABLE dbo.T_F_ORGANIZATION_ACCOUNT
            (
                DW_ETL_JOB_ID             DECIMAL(18,2),
                ACCOUNT_PROFILE_KEY        DECIMAL(18,2) NOT NULL,
                ACCOUNT_KEY                DECIMAL(18,2) NOT NULL,
                ORGANIZATION_TYPE_KEY      DECIMAL(18,2),
                ORGANIZATION_STATUS_KEY    DECIMAL(18,2),
                EFFECTIVE_TIME_KEY         DECIMAL(18,2),
                ORGANIZATION_KEY           DECIMAL(18,2) NOT NULL,
                PLAN_KEY                   DECIMAL(18,2),
                AUTH_INDIV_TYPE_CODE_DESCR VARCHAR(MAX),
                ORGANIZATION_TYPE_DESCR    VARCHAR(MAX),
                ORGANIZATION_STATUS_DESCR  VARCHAR(MAX),
                ORGANIZATION_TYPE_CODE     VARCHAR(MAX),
                ORGANIZATION_STATUS_CODE   VARCHAR(MAX),
                DW_CHANGE_ID               VARCHAR(MAX),
                DW_UPD_DTTM                DATETIME2(6),
                DW_INS_DTTM                DATETIME2(6),
                END_DATE                   DATETIME2(6),
                EFFECTIVE_DATE             DATETIME2(6) NOT NULL,
                DW_LOAD_DTTM               DATETIME2(6) NOT NULL DEFAULT SYSDATETIME()
            );
        END

        UPDATE tgt
        SET
            tgt.DW_ETL_JOB_ID              = src.DW_ETL_JOB_ID,
            tgt.ORGANIZATION_TYPE_KEY       = src.ORGANIZATION_TYPE_KEY,
            tgt.ORGANIZATION_STATUS_KEY     = src.ORGANIZATION_STATUS_KEY,
            tgt.EFFECTIVE_TIME_KEY          = src.EFFECTIVE_TIME_KEY,
            tgt.PLAN_KEY                    = src.PLAN_KEY,
            tgt.AUTH_INDIV_TYPE_CODE_DESCR  = src.AUTH_INDIV_TYPE_CODE_DESCR,
            tgt.ORGANIZATION_TYPE_DESCR     = src.ORGANIZATION_TYPE_DESCR,
            tgt.ORGANIZATION_STATUS_DESCR   = src.ORGANIZATION_STATUS_DESCR,
            tgt.ORGANIZATION_TYPE_CODE      = src.ORGANIZATION_TYPE_CODE,
            tgt.ORGANIZATION_STATUS_CODE    = src.ORGANIZATION_STATUS_CODE,
            tgt.DW_CHANGE_ID                = src.DW_CHANGE_ID,
            tgt.DW_UPD_DTTM                 = src.DW_UPD_DTTM,
            tgt.DW_INS_DTTM                 = src.DW_INS_DTTM,
            tgt.END_DATE                    = src.END_DATE,
            tgt.DW_LOAD_DTTM                = SYSDATETIME()
        FROM dbo.T_F_ORGANIZATION_ACCOUNT AS tgt
        INNER JOIN #StgOrgAccount AS src
            ON tgt.ORGANIZATION_KEY     = src.ORGANIZATION_KEY
           AND tgt.ACCOUNT_PROFILE_KEY  = src.ACCOUNT_PROFILE_KEY
           AND tgt.ACCOUNT_KEY          = src.ACCOUNT_KEY
           AND tgt.EFFECTIVE_DATE       = src.EFFECTIVE_DATE;

        SET @UpdatedRows = @@ROWCOUNT;

        INSERT INTO dbo.T_F_ORGANIZATION_ACCOUNT
        (
            DW_ETL_JOB_ID, ACCOUNT_PROFILE_KEY, ACCOUNT_KEY, ORGANIZATION_TYPE_KEY,
            ORGANIZATION_STATUS_KEY, EFFECTIVE_TIME_KEY, ORGANIZATION_KEY, PLAN_KEY,
            AUTH_INDIV_TYPE_CODE_DESCR, ORGANIZATION_TYPE_DESCR, ORGANIZATION_STATUS_DESCR,
            ORGANIZATION_TYPE_CODE, ORGANIZATION_STATUS_CODE, DW_CHANGE_ID,
            DW_UPD_DTTM, DW_INS_DTTM, END_DATE, EFFECTIVE_DATE, DW_LOAD_DTTM
        )
        SELECT
            src.DW_ETL_JOB_ID, src.ACCOUNT_PROFILE_KEY, src.ACCOUNT_KEY, src.ORGANIZATION_TYPE_KEY,
            src.ORGANIZATION_STATUS_KEY, src.EFFECTIVE_TIME_KEY, src.ORGANIZATION_KEY, src.PLAN_KEY,
            src.AUTH_INDIV_TYPE_CODE_DESCR, src.ORGANIZATION_TYPE_DESCR, src.ORGANIZATION_STATUS_DESCR,
            src.ORGANIZATION_TYPE_CODE, src.ORGANIZATION_STATUS_CODE, src.DW_CHANGE_ID,
            src.DW_UPD_DTTM, src.DW_INS_DTTM, src.END_DATE, src.EFFECTIVE_DATE, SYSDATETIME()
        FROM #StgOrgAccount AS src
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.T_F_ORGANIZATION_ACCOUNT AS tgt
            WHERE tgt.ORGANIZATION_KEY     = src.ORGANIZATION_KEY
              AND tgt.ACCOUNT_PROFILE_KEY  = src.ACCOUNT_PROFILE_KEY
              AND tgt.ACCOUNT_KEY          = src.ACCOUNT_KEY
              AND tgt.EFFECTIVE_DATE       = src.EFFECTIVE_DATE
        );

        SET @InsertedRows = @@ROWCOUNT;
        SET @RowsAffected = @InsertedRows + @UpdatedRows;

        IF OBJECT_ID('tempdb..#StgOrgAccount') IS NOT NULL
            DROP TABLE #StgOrgAccount;

        SET @EndTime  = SYSDATETIME();
        SET @Duration = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status   = 'SUCCESS';

        INSERT INTO dbo.ETL_LOAD_LOG
            (TableName, ProcedureName, StartTime, EndTime, DurationSeconds, RowsAffected, Status)
        VALUES
            (@TableName, @ProcedureName, @StartTime, @EndTime, @Duration, @RowsAffected, @Status);

    END TRY
    BEGIN CATCH

        IF OBJECT_ID('tempdb..#StgOrgAccount') IS NOT NULL
            DROP TABLE #StgOrgAccount;

        SET @EndTime      = SYSDATETIME();
        SET @Duration     = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status       = 'FAILED';
        SET @ErrorMessage = ERROR_MESSAGE();

        INSERT INTO dbo.ETL_LOAD_LOG
            (TableName, ProcedureName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
        VALUES
            (@TableName, @ProcedureName, @StartTime, @EndTime, @Duration, @RowsAffected, @Status, @ErrorMessage);

        THROW;

    END CATCH
END
GO

-- ================================================================
-- FILE: 06_sp_Load_T_F_ORGANIZATION_MEMBER_AFFILIATION.sql
-- ================================================================
/* ============================================================
   dbo.sp_Load_T_F_ORGANIZATION_MEMBER_AFFILIATION
   Source : Stage.UIIDWP01_T_F_ORGANIZATION_MEMBER_AFFILIATION
   Target : dbo.T_F_ORGANIZATION_MEMBER_AFFILIATION
   Keys   : ORGANIZATION_KEY, PROFILE_KEY, EFFECTIVE_DTTM

   Source -> Target type mapping applied on SELECT:
     NUMBER       -> DECIMAL(18,2)
     VARCHAR2     -> VARCHAR(MAX)
     DATE / TIMESTAMP(6) -> DATETIME2(6)   (EFFECTIVE_DTTM sourced as DATE, kept DATETIME2(6) for consistency)
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_Load_T_F_ORGANIZATION_MEMBER_AFFILIATION
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TableName     VARCHAR(200) = 'dbo.T_F_ORGANIZATION_MEMBER_AFFILIATION';
    DECLARE @ProcedureName VARCHAR(200) = 'dbo.sp_Load_T_F_ORGANIZATION_MEMBER_AFFILIATION';
    DECLARE @StartTime     DATETIME2(6) = SYSDATETIME();
    DECLARE @EndTime       DATETIME2(6);
    DECLARE @Duration      INT;
    DECLARE @ErrorMessage  VARCHAR(4000) = NULL;
    DECLARE @RowsAffected  BIGINT = 0;
    DECLARE @Status        VARCHAR(20) = 'STARTED';
    DECLARE @InsertedRows  BIGINT = 0;
    DECLARE @UpdatedRows   BIGINT = 0;

    INSERT INTO dbo.ETL_LOAD_LOG (TableName, ProcedureName, StartTime, Status)
    VALUES (@TableName, @ProcedureName, @StartTime, @Status);

    BEGIN TRY

        IF OBJECT_ID('tempdb..#StgOrgMemberAffl') IS NOT NULL
            DROP TABLE #StgOrgMemberAffl;

        SELECT
            CAST(MEMBER_STATUS_KEY     AS DECIMAL(18,2)) AS MEMBER_STATUS_KEY,
            CAST(SEC_ROLE_TYPE_KEY      AS DECIMAL(18,2)) AS SEC_ROLE_TYPE_KEY,
            CAST(MEMBER_PERM_TYPE_KEY   AS DECIMAL(18,2)) AS MEMBER_PERM_TYPE_KEY,
            CAST(MEMBER_ROLE_TYPE_KEY   AS DECIMAL(18,2)) AS MEMBER_ROLE_TYPE_KEY,
            CAST(DW_ETL_JOB_ID          AS DECIMAL(18,2)) AS DW_ETL_JOB_ID,
            CAST(EFFECTIVE_TIME_KEY     AS DECIMAL(18,2)) AS EFFECTIVE_TIME_KEY,
            CAST(PROFILE_KEY            AS DECIMAL(18,2)) AS PROFILE_KEY,
            CAST(ORGANIZATION_KEY       AS DECIMAL(18,2)) AS ORGANIZATION_KEY,
            CAST(PLAN_KEY               AS DECIMAL(18,2)) AS PLAN_KEY,
            CAST(EFFECTIVE_DTTM         AS DATETIME2(6))  AS EFFECTIVE_DTTM,
            CAST(SEC_ROLE_TYPE_DESCR    AS VARCHAR(MAX))  AS SEC_ROLE_TYPE_DESCR,
            CAST(MEMBER_PERM_TYPE_DESCR AS VARCHAR(MAX))  AS MEMBER_PERM_TYPE_DESCR,
            CAST(MEMBER_ROLE_TYPE_DESCR AS VARCHAR(MAX))  AS MEMBER_ROLE_TYPE_DESCR,
            CAST(DW_CHANGE_ID           AS VARCHAR(MAX))  AS DW_CHANGE_ID,
            CAST(MEMBER_STATUS_DESCR    AS VARCHAR(MAX))  AS MEMBER_STATUS_DESCR,
            CAST(MEMBER_STATUS_CODE     AS VARCHAR(MAX))  AS MEMBER_STATUS_CODE,
            CAST(SEC_ROLE_TYPE_CODE     AS VARCHAR(MAX))  AS SEC_ROLE_TYPE_CODE,
            CAST(MEMBER_PERM_TYPE_CODE  AS VARCHAR(MAX))  AS MEMBER_PERM_TYPE_CODE,
            CAST(MEMBER_ROLE_TYPE_CODE  AS VARCHAR(MAX))  AS MEMBER_ROLE_TYPE_CODE,
            CAST(DW_UPD_DTTM            AS DATETIME2(6))  AS DW_UPD_DTTM,
            CAST(DW_INS_DTTM            AS DATETIME2(6))  AS DW_INS_DTTM,
            CAST(END_DTTM                AS DATETIME2(6))  AS END_DTTM,
            CAST(SEQ_PERSON_ID           AS DECIMAL(18,2)) AS SEQ_PERSON_ID,
            CAST(UII_MEMBER_ID           AS DECIMAL(18,2)) AS UII_MEMBER_ID,
            CAST(SEQ_ORG_ID              AS DECIMAL(18,2)) AS SEQ_ORG_ID
        INTO #StgOrgMemberAffl
        FROM Stage.UIIDWP01_T_F_ORGANIZATION_MEMBER_AFFILIATION;

        IF OBJECT_ID('dbo.T_F_ORGANIZATION_MEMBER_AFFILIATION', 'U') IS NULL
        BEGIN
            CREATE TABLE dbo.T_F_ORGANIZATION_MEMBER_AFFILIATION
            (
                MEMBER_STATUS_KEY     DECIMAL(18,2),
                SEC_ROLE_TYPE_KEY      DECIMAL(18,2),
                MEMBER_PERM_TYPE_KEY   DECIMAL(18,2),
                MEMBER_ROLE_TYPE_KEY   DECIMAL(18,2),
                DW_ETL_JOB_ID          DECIMAL(18,2),
                EFFECTIVE_TIME_KEY     DECIMAL(18,2),
                PROFILE_KEY            DECIMAL(18,2) NOT NULL,
                ORGANIZATION_KEY       DECIMAL(18,2) NOT NULL,
                PLAN_KEY               DECIMAL(18,2),
                EFFECTIVE_DTTM         DATETIME2(6) NOT NULL,
                SEC_ROLE_TYPE_DESCR    VARCHAR(MAX),
                MEMBER_PERM_TYPE_DESCR VARCHAR(MAX),
                MEMBER_ROLE_TYPE_DESCR VARCHAR(MAX),
                DW_CHANGE_ID           VARCHAR(MAX),
                MEMBER_STATUS_DESCR    VARCHAR(MAX),
                MEMBER_STATUS_CODE     VARCHAR(MAX),
                SEC_ROLE_TYPE_CODE     VARCHAR(MAX),
                MEMBER_PERM_TYPE_CODE  VARCHAR(MAX),
                MEMBER_ROLE_TYPE_CODE  VARCHAR(MAX),
                DW_UPD_DTTM            DATETIME2(6),
                DW_INS_DTTM            DATETIME2(6),
                END_DTTM               DATETIME2(6),
                SEQ_PERSON_ID          DECIMAL(18,2),
                UII_MEMBER_ID          DECIMAL(18,2),
                SEQ_ORG_ID             DECIMAL(18,2),
                DW_LOAD_DTTM           DATETIME2(6) NOT NULL DEFAULT SYSDATETIME()
            );
        END

        UPDATE tgt
        SET
            tgt.MEMBER_STATUS_KEY     = src.MEMBER_STATUS_KEY,
            tgt.SEC_ROLE_TYPE_KEY      = src.SEC_ROLE_TYPE_KEY,
            tgt.MEMBER_PERM_TYPE_KEY   = src.MEMBER_PERM_TYPE_KEY,
            tgt.MEMBER_ROLE_TYPE_KEY   = src.MEMBER_ROLE_TYPE_KEY,
            tgt.DW_ETL_JOB_ID          = src.DW_ETL_JOB_ID,
            tgt.EFFECTIVE_TIME_KEY     = src.EFFECTIVE_TIME_KEY,
            tgt.PLAN_KEY               = src.PLAN_KEY,
            tgt.SEC_ROLE_TYPE_DESCR    = src.SEC_ROLE_TYPE_DESCR,
            tgt.MEMBER_PERM_TYPE_DESCR = src.MEMBER_PERM_TYPE_DESCR,
            tgt.MEMBER_ROLE_TYPE_DESCR = src.MEMBER_ROLE_TYPE_DESCR,
            tgt.DW_CHANGE_ID           = src.DW_CHANGE_ID,
            tgt.MEMBER_STATUS_DESCR    = src.MEMBER_STATUS_DESCR,
            tgt.MEMBER_STATUS_CODE     = src.MEMBER_STATUS_CODE,
            tgt.SEC_ROLE_TYPE_CODE     = src.SEC_ROLE_TYPE_CODE,
            tgt.MEMBER_PERM_TYPE_CODE  = src.MEMBER_PERM_TYPE_CODE,
            tgt.MEMBER_ROLE_TYPE_CODE  = src.MEMBER_ROLE_TYPE_CODE,
            tgt.DW_UPD_DTTM            = src.DW_UPD_DTTM,
            tgt.DW_INS_DTTM            = src.DW_INS_DTTM,
            tgt.END_DTTM               = src.END_DTTM,
            tgt.SEQ_PERSON_ID          = src.SEQ_PERSON_ID,
            tgt.UII_MEMBER_ID          = src.UII_MEMBER_ID,
            tgt.SEQ_ORG_ID             = src.SEQ_ORG_ID,
            tgt.DW_LOAD_DTTM           = SYSDATETIME()
        FROM dbo.T_F_ORGANIZATION_MEMBER_AFFILIATION AS tgt
        INNER JOIN #StgOrgMemberAffl AS src
            ON tgt.ORGANIZATION_KEY = src.ORGANIZATION_KEY
           AND tgt.PROFILE_KEY      = src.PROFILE_KEY
           AND tgt.EFFECTIVE_DTTM   = src.EFFECTIVE_DTTM;

        SET @UpdatedRows = @@ROWCOUNT;

        INSERT INTO dbo.T_F_ORGANIZATION_MEMBER_AFFILIATION
        (
            MEMBER_STATUS_KEY, SEC_ROLE_TYPE_KEY, MEMBER_PERM_TYPE_KEY, MEMBER_ROLE_TYPE_KEY,
            DW_ETL_JOB_ID, EFFECTIVE_TIME_KEY, PROFILE_KEY, ORGANIZATION_KEY, PLAN_KEY,
            EFFECTIVE_DTTM, SEC_ROLE_TYPE_DESCR, MEMBER_PERM_TYPE_DESCR, MEMBER_ROLE_TYPE_DESCR,
            DW_CHANGE_ID, MEMBER_STATUS_DESCR, MEMBER_STATUS_CODE, SEC_ROLE_TYPE_CODE,
            MEMBER_PERM_TYPE_CODE, MEMBER_ROLE_TYPE_CODE, DW_UPD_DTTM, DW_INS_DTTM, END_DTTM,
            SEQ_PERSON_ID, UII_MEMBER_ID, SEQ_ORG_ID, DW_LOAD_DTTM
        )
        SELECT
            src.MEMBER_STATUS_KEY, src.SEC_ROLE_TYPE_KEY, src.MEMBER_PERM_TYPE_KEY, src.MEMBER_ROLE_TYPE_KEY,
            src.DW_ETL_JOB_ID, src.EFFECTIVE_TIME_KEY, src.PROFILE_KEY, src.ORGANIZATION_KEY, src.PLAN_KEY,
            src.EFFECTIVE_DTTM, src.SEC_ROLE_TYPE_DESCR, src.MEMBER_PERM_TYPE_DESCR, src.MEMBER_ROLE_TYPE_DESCR,
            src.DW_CHANGE_ID, src.MEMBER_STATUS_DESCR, src.MEMBER_STATUS_CODE, src.SEC_ROLE_TYPE_CODE,
            src.MEMBER_PERM_TYPE_CODE, src.MEMBER_ROLE_TYPE_CODE, src.DW_UPD_DTTM, src.DW_INS_DTTM, src.END_DTTM,
            src.SEQ_PERSON_ID, src.UII_MEMBER_ID, src.SEQ_ORG_ID, SYSDATETIME()
        FROM #StgOrgMemberAffl AS src
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.T_F_ORGANIZATION_MEMBER_AFFILIATION AS tgt
            WHERE tgt.ORGANIZATION_KEY = src.ORGANIZATION_KEY
              AND tgt.PROFILE_KEY      = src.PROFILE_KEY
              AND tgt.EFFECTIVE_DTTM   = src.EFFECTIVE_DTTM
        );

        SET @InsertedRows = @@ROWCOUNT;
        SET @RowsAffected = @InsertedRows + @UpdatedRows;

        IF OBJECT_ID('tempdb..#StgOrgMemberAffl') IS NOT NULL
            DROP TABLE #StgOrgMemberAffl;

        SET @EndTime  = SYSDATETIME();
        SET @Duration = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status   = 'SUCCESS';

        INSERT INTO dbo.ETL_LOAD_LOG
            (TableName, ProcedureName, StartTime, EndTime, DurationSeconds, RowsAffected, Status)
        VALUES
            (@TableName, @ProcedureName, @StartTime, @EndTime, @Duration, @RowsAffected, @Status);

    END TRY
    BEGIN CATCH

        IF OBJECT_ID('tempdb..#StgOrgMemberAffl') IS NOT NULL
            DROP TABLE #StgOrgMemberAffl;

        SET @EndTime      = SYSDATETIME();
        SET @Duration     = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status       = 'FAILED';
        SET @ErrorMessage = ERROR_MESSAGE();

        INSERT INTO dbo.ETL_LOAD_LOG
            (TableName, ProcedureName, StartTime, EndTime, DurationSeconds, RowsAffected, Status, ErrorMessage)
        VALUES
            (@TableName, @ProcedureName, @StartTime, @EndTime, @Duration, @RowsAffected, @Status, @ErrorMessage);

        THROW;

    END CATCH
END
GO

-- ================================================================
-- FILE: 07_sp_Load_ALL_AA2_Tables.sql
-- ================================================================
/* ============================================================
   dbo.sp_Load_ALL_AA2_Tables
   Orchestrator - runs all 6 Stage -> dbo load procedures.
   Each child SP logs independently to dbo.ETL_LOAD_LOG.
   If one fails, error is logged and execution continues
   to the next table (change to re-throw if fail-fast desired).
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_Load_ALL_AA2_Tables
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        EXEC dbo.sp_Load_V_T_F_ACCOUNT_CLOSURE_AAV2;
    END TRY
    BEGIN CATCH
        PRINT 'sp_Load_V_T_F_ACCOUNT_CLOSURE_AAV2 failed: ' + ERROR_MESSAGE();
    END CATCH

    BEGIN TRY
        EXEC dbo.sp_Load_V_T_F_ACCOUNT_ENROLLMENT_AAV2;
    END TRY
    BEGIN CATCH
        PRINT 'sp_Load_V_T_F_ACCOUNT_ENROLLMENT_AAV2 failed: ' + ERROR_MESSAGE();
    END CATCH

    BEGIN TRY
        EXEC dbo.sp_Load_T_D_ORGANIZATION_STATUS;
    END TRY
    BEGIN CATCH
        PRINT 'sp_Load_T_D_ORGANIZATION_STATUS failed: ' + ERROR_MESSAGE();
    END CATCH

    BEGIN TRY
        EXEC dbo.sp_Load_T_D_ORGANIZATION_TYPE;
    END TRY
    BEGIN CATCH
        PRINT 'sp_Load_T_D_ORGANIZATION_TYPE failed: ' + ERROR_MESSAGE();
    END CATCH

    BEGIN TRY
        EXEC dbo.sp_Load_T_F_ORGANIZATION_ACCOUNT;
    END TRY
    BEGIN CATCH
        PRINT 'sp_Load_T_F_ORGANIZATION_ACCOUNT failed: ' + ERROR_MESSAGE();
    END CATCH

    BEGIN TRY
        EXEC dbo.sp_Load_T_F_ORGANIZATION_MEMBER_AFFILIATION;
    END TRY
    BEGIN CATCH
        PRINT 'sp_Load_T_F_ORGANIZATION_MEMBER_AFFILIATION failed: ' + ERROR_MESSAGE();
    END CATCH

    SELECT *
    FROM dbo.ETL_LOAD_LOG
    WHERE LogDate = CAST(GETDATE() AS DATE)
    ORDER BY LogId DESC;
END
GO

