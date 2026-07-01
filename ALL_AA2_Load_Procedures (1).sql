/* ================================================================
   AA2.0 STAGE -> DBO LOAD PROCEDURES (Fabric Warehouse / T-SQL)
   Combined script.
   NOTE: Run 00_CREATE_TABLES section FIRST and separately
   (this combined file includes it at the top for reference,
   but table creation should be executed once, standalone).
   ================================================================ */

-- ================================================================
-- FILE: 00_CREATE_TABLES.sql
-- ================================================================
/* ================================================================
   CREATE TABLE SCRIPT - Fabric Warehouse
   Run this once to create all target dbo tables and the log table.
   Type mapping applied (per source Oracle types):
     NUMBER        -> DECIMAL(18,2)
     VARCHAR2/CHAR/CLOB/RAW/ROWID -> VARCHAR(MAX)
     DATE / TIMESTAMP(6) -> kept as-is (native Stage type, no cast)
   ================================================================ */

/* ----------------------------------------------------------------
   1. dbo.V_T_F_ACCOUNT_CLOSURE_AAV2
   ---------------------------------------------------------------- */
CREATE TABLE dbo.V_T_F_ACCOUNT_CLOSURE_AAV2
(
    PLAN_KEY                DECIMAL(18,2)   NULL,
    ACCOUNT_PROFILE_KEY      DECIMAL(18,2)   NULL,
    ACCOUNT_CLOSURE_TIME_KEY DECIMAL(18,2)   NULL,
    BENE_AGE_KEY             DECIMAL(18,2)   NULL,
    CLOSURE_DATE             DATE            NULL,
    DW_INS_DTTM              TIMESTAMP(6)    NULL,
    DW_UPD_DTTM               TIMESTAMP(6)    NULL
);
GO

/* ----------------------------------------------------------------
   2. dbo.V_T_F_ACCOUNT_ENROLLMENT_AAV2
   ---------------------------------------------------------------- */
CREATE TABLE dbo.V_T_F_ACCOUNT_ENROLLMENT_AAV2
(
    PLAN_KEY                    DECIMAL(18,2)  NULL,
    ACCOUNT_PROFILE_KEY          DECIMAL(18,2)  NULL,
    ACCOUNT_TC_ACCEPTED_TIME_KEY DECIMAL(18,2)  NULL,
    ACCOUNT_ENROLL_TIME_KEY      DECIMAL(18,2)  NULL,
    INITIAL_CONTRIB_AMOUNT       DECIMAL(18,2)  NULL,
    BENE_AGE_KEY                 DECIMAL(18,2)  NULL,
    ENROLLMENT_DATE              DATE           NULL,
    SRC_UPD_TS                   TIMESTAMP(6)   NULL,
    SRC_INS_TS                   TIMESTAMP(6)   NULL
);
GO

/* ----------------------------------------------------------------
   3. dbo.T_D_ORGANIZATION_STATUS
   ---------------------------------------------------------------- */
CREATE TABLE dbo.T_D_ORGANIZATION_STATUS
(
    DW_ETL_JOB_ID            DECIMAL(18,2)  NULL,
    ORGANIZATION_STATUS_KEY   DECIMAL(18,2)  NULL,
    ORGANIZATION_STATUS_DESCR VARCHAR(MAX)   NULL,
    ORGANIZATION_STATUS_CODE  VARCHAR(MAX)   NULL,
    DW_CHANGE_ID              VARCHAR(MAX)   NULL,
    DW_UPD_DTTM               TIMESTAMP(6)   NULL,
    DW_INS_DTTM               TIMESTAMP(6)   NULL
);
GO

/* ----------------------------------------------------------------
   4. dbo.T_D_ORGANIZATION_TYPE
   ---------------------------------------------------------------- */
CREATE TABLE dbo.T_D_ORGANIZATION_TYPE
(
    DW_ETL_JOB_ID          DECIMAL(18,2)  NULL,
    ORGANIZATION_TYPE_KEY   DECIMAL(18,2)  NULL,
    ORGANIZATION_TYPE_DESCR VARCHAR(MAX)   NULL,
    ORGANIZATION_TYPE_CODE  VARCHAR(MAX)   NULL,
    DW_CHANGE_ID            VARCHAR(MAX)   NULL,
    DW_UPD_DTTM             TIMESTAMP(6)   NULL,
    DW_INS_DTTM             TIMESTAMP(6)   NULL
);
GO

/* ----------------------------------------------------------------
   5. dbo.T_F_ORGANIZATION_ACCOUNT
   ---------------------------------------------------------------- */
CREATE TABLE dbo.T_F_ORGANIZATION_ACCOUNT
(
    DW_ETL_JOB_ID             DECIMAL(18,2)  NULL,
    ACCOUNT_PROFILE_KEY        DECIMAL(18,2)  NULL,
    ACCOUNT_KEY                DECIMAL(18,2)  NULL,
    ORGANIZATION_TYPE_KEY      DECIMAL(18,2)  NULL,
    ORGANIZATION_STATUS_KEY    DECIMAL(18,2)  NULL,
    EFFECTIVE_TIME_KEY         DECIMAL(18,2)  NULL,
    ORGANIZATION_KEY           DECIMAL(18,2)  NULL,
    PLAN_KEY                   DECIMAL(18,2)  NULL,
    AUTH_INDIV_TYPE_CODE_DESCR VARCHAR(MAX)   NULL,
    ORGANIZATION_TYPE_DESCR    VARCHAR(MAX)   NULL,
    ORGANIZATION_STATUS_DESCR  VARCHAR(MAX)   NULL,
    ORGANIZATION_TYPE_CODE     VARCHAR(MAX)   NULL,
    ORGANIZATION_STATUS_CODE   VARCHAR(MAX)   NULL,
    DW_CHANGE_ID               VARCHAR(MAX)   NULL,
    DW_UPD_DTTM                TIMESTAMP(6)   NULL,
    DW_INS_DTTM                TIMESTAMP(6)   NULL,
    END_DATE                   TIMESTAMP(6)   NULL,
    EFFECTIVE_DATE              TIMESTAMP(6)   NULL
);
GO

/* ----------------------------------------------------------------
   6. dbo.T_F_ORGANIZATION_MEMBER_AFFILIATION
   ---------------------------------------------------------------- */
CREATE TABLE dbo.T_F_ORGANIZATION_MEMBER_AFFILIATION
(
    MEMBER_STATUS_KEY     DECIMAL(18,2)  NULL,
    SEC_ROLE_TYPE_KEY      DECIMAL(18,2)  NULL,
    MEMBER_PERM_TYPE_KEY   DECIMAL(18,2)  NULL,
    MEMBER_ROLE_TYPE_KEY   DECIMAL(18,2)  NULL,
    DW_ETL_JOB_ID          DECIMAL(18,2)  NULL,
    EFFECTIVE_TIME_KEY     DECIMAL(18,2)  NULL,
    PROFILE_KEY            DECIMAL(18,2)  NULL,
    ORGANIZATION_KEY       DECIMAL(18,2)  NULL,
    PLAN_KEY               DECIMAL(18,2)  NULL,
    EFFECTIVE_DTTM         DATE           NULL,
    SEC_ROLE_TYPE_DESCR    VARCHAR(MAX)   NULL,
    MEMBER_PERM_TYPE_DESCR VARCHAR(MAX)   NULL,
    MEMBER_ROLE_TYPE_DESCR VARCHAR(MAX)   NULL,
    DW_CHANGE_ID           VARCHAR(MAX)   NULL,
    MEMBER_STATUS_DESCR    VARCHAR(MAX)   NULL,
    MEMBER_STATUS_CODE     VARCHAR(MAX)   NULL,
    SEC_ROLE_TYPE_CODE     VARCHAR(MAX)   NULL,
    MEMBER_PERM_TYPE_CODE  VARCHAR(MAX)   NULL,
    MEMBER_ROLE_TYPE_CODE  VARCHAR(MAX)   NULL,
    DW_UPD_DTTM            TIMESTAMP(6)   NULL,
    DW_INS_DTTM            TIMESTAMP(6)   NULL,
    END_DTTM               TIMESTAMP(6)   NULL,
    SEQ_PERSON_ID          DECIMAL(18,2)  NULL,
    UII_MEMBER_ID          DECIMAL(18,2)  NULL,
    SEQ_ORG_ID             DECIMAL(18,2)  NULL
);
GO

/* ----------------------------------------------------------------
   7. WH_MetaData.Log.Up_sert  (logging table - all columns nullable)
   ---------------------------------------------------------------- */
CREATE TABLE WH_MetaData.Log.Up_sert
(
    TableName       VARCHAR(200)   NULL,
    ProcedureName   VARCHAR(200)   NULL,
    StartTime       DATETIME2(6)   NULL,
    EndTime         DATETIME2(6)   NULL,
    DurationSeconds INT            NULL,
    RowsAffected    BIGINT         NULL,
    Status          VARCHAR(20)    NULL,
    ErrorMessage    VARCHAR(4000)  NULL,
    LogDate         DATE           NULL
);
GO

-- ================================================================
-- FILE: 01_sp_Load_V_T_F_ACCOUNT_CLOSURE_AAV2.sql
-- ================================================================
/* ============================================================
   dbo.sp_Load_V_T_F_ACCOUNT_CLOSURE_AAV2
   Source : Stage.DW_BI_DEV_V_T_F_ACCOUNT_CLOSURE_AAV2
   Target : dbo.V_T_F_ACCOUNT_CLOSURE_AAV2
   Keys   : ACCOUNT_PROFILE_KEY, ACCOUNT_CLOSURE_TIME_KEY
   Reads directly from Stage (no temp table / no SELECT INTO).
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

    INSERT INTO WH_MetaData.Log.Up_sert (TableName, ProcedureName, StartTime, Status)
    VALUES (@TableName, @ProcedureName, @StartTime, @Status);

    BEGIN TRY

        UPDATE tgt
        SET
            tgt.PLAN_KEY     = CAST(src.PLAN_KEY AS DECIMAL(18,2)),
            tgt.BENE_AGE_KEY = CAST(src.BENE_AGE_KEY AS DECIMAL(18,2)),
            tgt.CLOSURE_DATE = src.CLOSURE_DATE,
            tgt.DW_INS_DTTM  = src.DW_INS_DTTM,
            tgt.DW_UPD_DTTM  = src.DW_UPD_DTTM
        FROM dbo.V_T_F_ACCOUNT_CLOSURE_AAV2 AS tgt
        INNER JOIN Stage.DW_BI_DEV_V_T_F_ACCOUNT_CLOSURE_AAV2 AS src
            ON tgt.ACCOUNT_PROFILE_KEY      = CAST(src.ACCOUNT_PROFILE_KEY AS DECIMAL(18,2))
           AND tgt.ACCOUNT_CLOSURE_TIME_KEY = CAST(src.ACCOUNT_CLOSURE_TIME_KEY AS DECIMAL(18,2));

        SET @UpdatedRows = @@ROWCOUNT;

        INSERT INTO dbo.V_T_F_ACCOUNT_CLOSURE_AAV2
        (
            PLAN_KEY, ACCOUNT_PROFILE_KEY, ACCOUNT_CLOSURE_TIME_KEY,
            BENE_AGE_KEY, CLOSURE_DATE, DW_INS_DTTM, DW_UPD_DTTM
        )
        SELECT
            CAST(src.PLAN_KEY AS DECIMAL(18,2)),
            CAST(src.ACCOUNT_PROFILE_KEY AS DECIMAL(18,2)),
            CAST(src.ACCOUNT_CLOSURE_TIME_KEY AS DECIMAL(18,2)),
            CAST(src.BENE_AGE_KEY AS DECIMAL(18,2)),
            src.CLOSURE_DATE,
            src.DW_INS_DTTM,
            src.DW_UPD_DTTM
        FROM Stage.DW_BI_DEV_V_T_F_ACCOUNT_CLOSURE_AAV2 AS src
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.V_T_F_ACCOUNT_CLOSURE_AAV2 AS tgt
            WHERE tgt.ACCOUNT_PROFILE_KEY      = CAST(src.ACCOUNT_PROFILE_KEY AS DECIMAL(18,2))
              AND tgt.ACCOUNT_CLOSURE_TIME_KEY = CAST(src.ACCOUNT_CLOSURE_TIME_KEY AS DECIMAL(18,2))
        );

        SET @InsertedRows = @@ROWCOUNT;
        SET @RowsAffected = @InsertedRows + @UpdatedRows;

        SET @EndTime  = SYSDATETIME();
        SET @Duration = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status   = 'SUCCESS';

        INSERT INTO WH_MetaData.Log.Up_sert
            (TableName, ProcedureName, StartTime, EndTime, DurationSeconds, RowsAffected, Status)
        VALUES
            (@TableName, @ProcedureName, @StartTime, @EndTime, @Duration, @RowsAffected, @Status);

    END TRY
    BEGIN CATCH

        SET @EndTime      = SYSDATETIME();
        SET @Duration     = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status       = 'FAILED';
        SET @ErrorMessage = ERROR_MESSAGE();

        INSERT INTO WH_MetaData.Log.Up_sert
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
   Reads directly from Stage (no temp table / no SELECT INTO).
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

    INSERT INTO WH_MetaData.Log.Up_sert (TableName, ProcedureName, StartTime, Status)
    VALUES (@TableName, @ProcedureName, @StartTime, @Status);

    BEGIN TRY

        UPDATE tgt
        SET
            tgt.PLAN_KEY                = CAST(src.PLAN_KEY AS DECIMAL(18,2)),
            tgt.ACCOUNT_ENROLL_TIME_KEY = CAST(src.ACCOUNT_ENROLL_TIME_KEY AS DECIMAL(18,2)),
            tgt.INITIAL_CONTRIB_AMOUNT  = CAST(src.INITIAL_CONTRIB_AMOUNT AS DECIMAL(18,2)),
            tgt.BENE_AGE_KEY            = CAST(src.BENE_AGE_KEY AS DECIMAL(18,2)),
            tgt.ENROLLMENT_DATE         = src.ENROLLMENT_DATE,
            tgt.SRC_UPD_TS              = src.SRC_UPD_TS,
            tgt.SRC_INS_TS              = src.SRC_INS_TS
        FROM dbo.V_T_F_ACCOUNT_ENROLLMENT_AAV2 AS tgt
        INNER JOIN Stage.DW_BI_DEV_V_T_F_ACCOUNT_ENROLLMENT_AAV2 AS src
            ON tgt.ACCOUNT_PROFILE_KEY          = CAST(src.ACCOUNT_PROFILE_KEY AS DECIMAL(18,2))
           AND tgt.ACCOUNT_TC_ACCEPTED_TIME_KEY = CAST(src.ACCOUNT_TC_ACCEPTED_TIME_KEY AS DECIMAL(18,2));

        SET @UpdatedRows = @@ROWCOUNT;

        INSERT INTO dbo.V_T_F_ACCOUNT_ENROLLMENT_AAV2
        (
            PLAN_KEY, ACCOUNT_PROFILE_KEY, ACCOUNT_TC_ACCEPTED_TIME_KEY, ACCOUNT_ENROLL_TIME_KEY,
            INITIAL_CONTRIB_AMOUNT, BENE_AGE_KEY, ENROLLMENT_DATE, SRC_UPD_TS, SRC_INS_TS
        )
        SELECT
            CAST(src.PLAN_KEY AS DECIMAL(18,2)),
            CAST(src.ACCOUNT_PROFILE_KEY AS DECIMAL(18,2)),
            CAST(src.ACCOUNT_TC_ACCEPTED_TIME_KEY AS DECIMAL(18,2)),
            CAST(src.ACCOUNT_ENROLL_TIME_KEY AS DECIMAL(18,2)),
            CAST(src.INITIAL_CONTRIB_AMOUNT AS DECIMAL(18,2)),
            CAST(src.BENE_AGE_KEY AS DECIMAL(18,2)),
            src.ENROLLMENT_DATE,
            src.SRC_UPD_TS,
            src.SRC_INS_TS
        FROM Stage.DW_BI_DEV_V_T_F_ACCOUNT_ENROLLMENT_AAV2 AS src
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.V_T_F_ACCOUNT_ENROLLMENT_AAV2 AS tgt
            WHERE tgt.ACCOUNT_PROFILE_KEY          = CAST(src.ACCOUNT_PROFILE_KEY AS DECIMAL(18,2))
              AND tgt.ACCOUNT_TC_ACCEPTED_TIME_KEY = CAST(src.ACCOUNT_TC_ACCEPTED_TIME_KEY AS DECIMAL(18,2))
        );

        SET @InsertedRows = @@ROWCOUNT;
        SET @RowsAffected = @InsertedRows + @UpdatedRows;

        SET @EndTime  = SYSDATETIME();
        SET @Duration = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status   = 'SUCCESS';

        INSERT INTO WH_MetaData.Log.Up_sert
            (TableName, ProcedureName, StartTime, EndTime, DurationSeconds, RowsAffected, Status)
        VALUES
            (@TableName, @ProcedureName, @StartTime, @EndTime, @Duration, @RowsAffected, @Status);

    END TRY
    BEGIN CATCH

        SET @EndTime      = SYSDATETIME();
        SET @Duration     = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status       = 'FAILED';
        SET @ErrorMessage = ERROR_MESSAGE();

        INSERT INTO WH_MetaData.Log.Up_sert
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
   Reads directly from Stage (no temp table / no SELECT INTO).
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

    INSERT INTO WH_MetaData.Log.Up_sert (TableName, ProcedureName, StartTime, Status)
    VALUES (@TableName, @ProcedureName, @StartTime, @Status);

    BEGIN TRY

        UPDATE tgt
        SET
            tgt.DW_ETL_JOB_ID            = CAST(src.DW_ETL_JOB_ID AS DECIMAL(18,2)),
            tgt.ORGANIZATION_STATUS_DESCR = CAST(src.ORGANIZATION_STATUS_DESCR AS VARCHAR(MAX)),
            tgt.ORGANIZATION_STATUS_CODE  = CAST(src.ORGANIZATION_STATUS_CODE AS VARCHAR(MAX)),
            tgt.DW_CHANGE_ID              = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
            tgt.DW_UPD_DTTM               = src.DW_UPD_DTTM,
            tgt.DW_INS_DTTM               = src.DW_INS_DTTM
        FROM dbo.T_D_ORGANIZATION_STATUS AS tgt
        INNER JOIN Stage.UIIDWP01_T_D_ORGANIZATION_STATUS AS src
            ON tgt.ORGANIZATION_STATUS_KEY = CAST(src.ORGANIZATION_STATUS_KEY AS DECIMAL(18,2));

        SET @UpdatedRows = @@ROWCOUNT;

        INSERT INTO dbo.T_D_ORGANIZATION_STATUS
        (
            DW_ETL_JOB_ID, ORGANIZATION_STATUS_KEY, ORGANIZATION_STATUS_DESCR,
            ORGANIZATION_STATUS_CODE, DW_CHANGE_ID, DW_UPD_DTTM, DW_INS_DTTM
        )
        SELECT
            CAST(src.DW_ETL_JOB_ID AS DECIMAL(18,2)),
            CAST(src.ORGANIZATION_STATUS_KEY AS DECIMAL(18,2)),
            CAST(src.ORGANIZATION_STATUS_DESCR AS VARCHAR(MAX)),
            CAST(src.ORGANIZATION_STATUS_CODE AS VARCHAR(MAX)),
            CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
            src.DW_UPD_DTTM,
            src.DW_INS_DTTM
        FROM Stage.UIIDWP01_T_D_ORGANIZATION_STATUS AS src
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.T_D_ORGANIZATION_STATUS AS tgt
            WHERE tgt.ORGANIZATION_STATUS_KEY = CAST(src.ORGANIZATION_STATUS_KEY AS DECIMAL(18,2))
        );

        SET @InsertedRows = @@ROWCOUNT;
        SET @RowsAffected = @InsertedRows + @UpdatedRows;

        SET @EndTime  = SYSDATETIME();
        SET @Duration = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status   = 'SUCCESS';

        INSERT INTO WH_MetaData.Log.Up_sert
            (TableName, ProcedureName, StartTime, EndTime, DurationSeconds, RowsAffected, Status)
        VALUES
            (@TableName, @ProcedureName, @StartTime, @EndTime, @Duration, @RowsAffected, @Status);

    END TRY
    BEGIN CATCH

        SET @EndTime      = SYSDATETIME();
        SET @Duration     = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status       = 'FAILED';
        SET @ErrorMessage = ERROR_MESSAGE();

        INSERT INTO WH_MetaData.Log.Up_sert
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
   Reads directly from Stage (no temp table / no SELECT INTO).
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

    INSERT INTO WH_MetaData.Log.Up_sert (TableName, ProcedureName, StartTime, Status)
    VALUES (@TableName, @ProcedureName, @StartTime, @Status);

    BEGIN TRY

        UPDATE tgt
        SET
            tgt.DW_ETL_JOB_ID          = CAST(src.DW_ETL_JOB_ID AS DECIMAL(18,2)),
            tgt.ORGANIZATION_TYPE_DESCR = CAST(src.ORGANIZATION_TYPE_DESCR AS VARCHAR(MAX)),
            tgt.ORGANIZATION_TYPE_CODE  = CAST(src.ORGANIZATION_TYPE_CODE AS VARCHAR(MAX)),
            tgt.DW_CHANGE_ID            = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
            tgt.DW_UPD_DTTM             = src.DW_UPD_DTTM,
            tgt.DW_INS_DTTM             = src.DW_INS_DTTM
        FROM dbo.T_D_ORGANIZATION_TYPE AS tgt
        INNER JOIN Stage.UIIDWP01_T_D_ORGANIZATION_TYPE AS src
            ON tgt.ORGANIZATION_TYPE_KEY = CAST(src.ORGANIZATION_TYPE_KEY AS DECIMAL(18,2));

        SET @UpdatedRows = @@ROWCOUNT;

        INSERT INTO dbo.T_D_ORGANIZATION_TYPE
        (
            DW_ETL_JOB_ID, ORGANIZATION_TYPE_KEY, ORGANIZATION_TYPE_DESCR,
            ORGANIZATION_TYPE_CODE, DW_CHANGE_ID, DW_UPD_DTTM, DW_INS_DTTM
        )
        SELECT
            CAST(src.DW_ETL_JOB_ID AS DECIMAL(18,2)),
            CAST(src.ORGANIZATION_TYPE_KEY AS DECIMAL(18,2)),
            CAST(src.ORGANIZATION_TYPE_DESCR AS VARCHAR(MAX)),
            CAST(src.ORGANIZATION_TYPE_CODE AS VARCHAR(MAX)),
            CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
            src.DW_UPD_DTTM,
            src.DW_INS_DTTM
        FROM Stage.UIIDWP01_T_D_ORGANIZATION_TYPE AS src
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.T_D_ORGANIZATION_TYPE AS tgt
            WHERE tgt.ORGANIZATION_TYPE_KEY = CAST(src.ORGANIZATION_TYPE_KEY AS DECIMAL(18,2))
        );

        SET @InsertedRows = @@ROWCOUNT;
        SET @RowsAffected = @InsertedRows + @UpdatedRows;

        SET @EndTime  = SYSDATETIME();
        SET @Duration = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status   = 'SUCCESS';

        INSERT INTO WH_MetaData.Log.Up_sert
            (TableName, ProcedureName, StartTime, EndTime, DurationSeconds, RowsAffected, Status)
        VALUES
            (@TableName, @ProcedureName, @StartTime, @EndTime, @Duration, @RowsAffected, @Status);

    END TRY
    BEGIN CATCH

        SET @EndTime      = SYSDATETIME();
        SET @Duration     = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status       = 'FAILED';
        SET @ErrorMessage = ERROR_MESSAGE();

        INSERT INTO WH_MetaData.Log.Up_sert
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
   Reads directly from Stage (no temp table / no SELECT INTO).
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

    INSERT INTO WH_MetaData.Log.Up_sert (TableName, ProcedureName, StartTime, Status)
    VALUES (@TableName, @ProcedureName, @StartTime, @Status);

    BEGIN TRY

        UPDATE tgt
        SET
            tgt.DW_ETL_JOB_ID              = CAST(src.DW_ETL_JOB_ID AS DECIMAL(18,2)),
            tgt.ORGANIZATION_TYPE_KEY       = CAST(src.ORGANIZATION_TYPE_KEY AS DECIMAL(18,2)),
            tgt.ORGANIZATION_STATUS_KEY     = CAST(src.ORGANIZATION_STATUS_KEY AS DECIMAL(18,2)),
            tgt.EFFECTIVE_TIME_KEY          = CAST(src.EFFECTIVE_TIME_KEY AS DECIMAL(18,2)),
            tgt.PLAN_KEY                    = CAST(src.PLAN_KEY AS DECIMAL(18,2)),
            tgt.AUTH_INDIV_TYPE_CODE_DESCR  = CAST(src.AUTH_INDIV_TYPE_CODE_DESCR AS VARCHAR(MAX)),
            tgt.ORGANIZATION_TYPE_DESCR     = CAST(src.ORGANIZATION_TYPE_DESCR AS VARCHAR(MAX)),
            tgt.ORGANIZATION_STATUS_DESCR   = CAST(src.ORGANIZATION_STATUS_DESCR AS VARCHAR(MAX)),
            tgt.ORGANIZATION_TYPE_CODE      = CAST(src.ORGANIZATION_TYPE_CODE AS VARCHAR(MAX)),
            tgt.ORGANIZATION_STATUS_CODE    = CAST(src.ORGANIZATION_STATUS_CODE AS VARCHAR(MAX)),
            tgt.DW_CHANGE_ID                = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
            tgt.DW_UPD_DTTM                 = src.DW_UPD_DTTM,
            tgt.DW_INS_DTTM                 = src.DW_INS_DTTM,
            tgt.END_DATE                    = src.END_DATE
        FROM dbo.T_F_ORGANIZATION_ACCOUNT AS tgt
        INNER JOIN Stage.UIIDWP01_T_F_ORGANIZATION_ACCOUNT AS src
            ON tgt.ORGANIZATION_KEY     = CAST(src.ORGANIZATION_KEY AS DECIMAL(18,2))
           AND tgt.ACCOUNT_PROFILE_KEY  = CAST(src.ACCOUNT_PROFILE_KEY AS DECIMAL(18,2))
           AND tgt.ACCOUNT_KEY          = CAST(src.ACCOUNT_KEY AS DECIMAL(18,2))
           AND tgt.EFFECTIVE_DATE       = src.EFFECTIVE_DATE;

        SET @UpdatedRows = @@ROWCOUNT;

        INSERT INTO dbo.T_F_ORGANIZATION_ACCOUNT
        (
            DW_ETL_JOB_ID, ACCOUNT_PROFILE_KEY, ACCOUNT_KEY, ORGANIZATION_TYPE_KEY,
            ORGANIZATION_STATUS_KEY, EFFECTIVE_TIME_KEY, ORGANIZATION_KEY, PLAN_KEY,
            AUTH_INDIV_TYPE_CODE_DESCR, ORGANIZATION_TYPE_DESCR, ORGANIZATION_STATUS_DESCR,
            ORGANIZATION_TYPE_CODE, ORGANIZATION_STATUS_CODE, DW_CHANGE_ID,
            DW_UPD_DTTM, DW_INS_DTTM, END_DATE, EFFECTIVE_DATE
        )
        SELECT
            CAST(src.DW_ETL_JOB_ID AS DECIMAL(18,2)),
            CAST(src.ACCOUNT_PROFILE_KEY AS DECIMAL(18,2)),
            CAST(src.ACCOUNT_KEY AS DECIMAL(18,2)),
            CAST(src.ORGANIZATION_TYPE_KEY AS DECIMAL(18,2)),
            CAST(src.ORGANIZATION_STATUS_KEY AS DECIMAL(18,2)),
            CAST(src.EFFECTIVE_TIME_KEY AS DECIMAL(18,2)),
            CAST(src.ORGANIZATION_KEY AS DECIMAL(18,2)),
            CAST(src.PLAN_KEY AS DECIMAL(18,2)),
            CAST(src.AUTH_INDIV_TYPE_CODE_DESCR AS VARCHAR(MAX)),
            CAST(src.ORGANIZATION_TYPE_DESCR AS VARCHAR(MAX)),
            CAST(src.ORGANIZATION_STATUS_DESCR AS VARCHAR(MAX)),
            CAST(src.ORGANIZATION_TYPE_CODE AS VARCHAR(MAX)),
            CAST(src.ORGANIZATION_STATUS_CODE AS VARCHAR(MAX)),
            CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
            src.DW_UPD_DTTM,
            src.DW_INS_DTTM,
            src.END_DATE,
            src.EFFECTIVE_DATE
        FROM Stage.UIIDWP01_T_F_ORGANIZATION_ACCOUNT AS src
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.T_F_ORGANIZATION_ACCOUNT AS tgt
            WHERE tgt.ORGANIZATION_KEY     = CAST(src.ORGANIZATION_KEY AS DECIMAL(18,2))
              AND tgt.ACCOUNT_PROFILE_KEY  = CAST(src.ACCOUNT_PROFILE_KEY AS DECIMAL(18,2))
              AND tgt.ACCOUNT_KEY          = CAST(src.ACCOUNT_KEY AS DECIMAL(18,2))
              AND tgt.EFFECTIVE_DATE       = src.EFFECTIVE_DATE
        );

        SET @InsertedRows = @@ROWCOUNT;
        SET @RowsAffected = @InsertedRows + @UpdatedRows;

        SET @EndTime  = SYSDATETIME();
        SET @Duration = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status   = 'SUCCESS';

        INSERT INTO WH_MetaData.Log.Up_sert
            (TableName, ProcedureName, StartTime, EndTime, DurationSeconds, RowsAffected, Status)
        VALUES
            (@TableName, @ProcedureName, @StartTime, @EndTime, @Duration, @RowsAffected, @Status);

    END TRY
    BEGIN CATCH

        SET @EndTime      = SYSDATETIME();
        SET @Duration     = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status       = 'FAILED';
        SET @ErrorMessage = ERROR_MESSAGE();

        INSERT INTO WH_MetaData.Log.Up_sert
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
   Reads directly from Stage (no temp table / no SELECT INTO).
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

    INSERT INTO WH_MetaData.Log.Up_sert (TableName, ProcedureName, StartTime, Status)
    VALUES (@TableName, @ProcedureName, @StartTime, @Status);

    BEGIN TRY

        UPDATE tgt
        SET
            tgt.MEMBER_STATUS_KEY     = CAST(src.MEMBER_STATUS_KEY AS DECIMAL(18,2)),
            tgt.SEC_ROLE_TYPE_KEY      = CAST(src.SEC_ROLE_TYPE_KEY AS DECIMAL(18,2)),
            tgt.MEMBER_PERM_TYPE_KEY   = CAST(src.MEMBER_PERM_TYPE_KEY AS DECIMAL(18,2)),
            tgt.MEMBER_ROLE_TYPE_KEY   = CAST(src.MEMBER_ROLE_TYPE_KEY AS DECIMAL(18,2)),
            tgt.DW_ETL_JOB_ID          = CAST(src.DW_ETL_JOB_ID AS DECIMAL(18,2)),
            tgt.EFFECTIVE_TIME_KEY     = CAST(src.EFFECTIVE_TIME_KEY AS DECIMAL(18,2)),
            tgt.PLAN_KEY               = CAST(src.PLAN_KEY AS DECIMAL(18,2)),
            tgt.SEC_ROLE_TYPE_DESCR    = CAST(src.SEC_ROLE_TYPE_DESCR AS VARCHAR(MAX)),
            tgt.MEMBER_PERM_TYPE_DESCR = CAST(src.MEMBER_PERM_TYPE_DESCR AS VARCHAR(MAX)),
            tgt.MEMBER_ROLE_TYPE_DESCR = CAST(src.MEMBER_ROLE_TYPE_DESCR AS VARCHAR(MAX)),
            tgt.DW_CHANGE_ID           = CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
            tgt.MEMBER_STATUS_DESCR    = CAST(src.MEMBER_STATUS_DESCR AS VARCHAR(MAX)),
            tgt.MEMBER_STATUS_CODE     = CAST(src.MEMBER_STATUS_CODE AS VARCHAR(MAX)),
            tgt.SEC_ROLE_TYPE_CODE     = CAST(src.SEC_ROLE_TYPE_CODE AS VARCHAR(MAX)),
            tgt.MEMBER_PERM_TYPE_CODE  = CAST(src.MEMBER_PERM_TYPE_CODE AS VARCHAR(MAX)),
            tgt.MEMBER_ROLE_TYPE_CODE  = CAST(src.MEMBER_ROLE_TYPE_CODE AS VARCHAR(MAX)),
            tgt.DW_UPD_DTTM            = src.DW_UPD_DTTM,
            tgt.DW_INS_DTTM            = src.DW_INS_DTTM,
            tgt.END_DTTM               = src.END_DTTM,
            tgt.SEQ_PERSON_ID          = CAST(src.SEQ_PERSON_ID AS DECIMAL(18,2)),
            tgt.UII_MEMBER_ID          = CAST(src.UII_MEMBER_ID AS DECIMAL(18,2)),
            tgt.SEQ_ORG_ID             = CAST(src.SEQ_ORG_ID AS DECIMAL(18,2))
        FROM dbo.T_F_ORGANIZATION_MEMBER_AFFILIATION AS tgt
        INNER JOIN Stage.UIIDWP01_T_F_ORGANIZATION_MEMBER_AFFILIATION AS src
            ON tgt.ORGANIZATION_KEY = CAST(src.ORGANIZATION_KEY AS DECIMAL(18,2))
           AND tgt.PROFILE_KEY      = CAST(src.PROFILE_KEY AS DECIMAL(18,2))
           AND tgt.EFFECTIVE_DTTM   = src.EFFECTIVE_DTTM;

        SET @UpdatedRows = @@ROWCOUNT;

        INSERT INTO dbo.T_F_ORGANIZATION_MEMBER_AFFILIATION
        (
            MEMBER_STATUS_KEY, SEC_ROLE_TYPE_KEY, MEMBER_PERM_TYPE_KEY, MEMBER_ROLE_TYPE_KEY,
            DW_ETL_JOB_ID, EFFECTIVE_TIME_KEY, PROFILE_KEY, ORGANIZATION_KEY, PLAN_KEY,
            EFFECTIVE_DTTM, SEC_ROLE_TYPE_DESCR, MEMBER_PERM_TYPE_DESCR, MEMBER_ROLE_TYPE_DESCR,
            DW_CHANGE_ID, MEMBER_STATUS_DESCR, MEMBER_STATUS_CODE, SEC_ROLE_TYPE_CODE,
            MEMBER_PERM_TYPE_CODE, MEMBER_ROLE_TYPE_CODE, DW_UPD_DTTM, DW_INS_DTTM, END_DTTM,
            SEQ_PERSON_ID, UII_MEMBER_ID, SEQ_ORG_ID
        )
        SELECT
            CAST(src.MEMBER_STATUS_KEY AS DECIMAL(18,2)),
            CAST(src.SEC_ROLE_TYPE_KEY AS DECIMAL(18,2)),
            CAST(src.MEMBER_PERM_TYPE_KEY AS DECIMAL(18,2)),
            CAST(src.MEMBER_ROLE_TYPE_KEY AS DECIMAL(18,2)),
            CAST(src.DW_ETL_JOB_ID AS DECIMAL(18,2)),
            CAST(src.EFFECTIVE_TIME_KEY AS DECIMAL(18,2)),
            CAST(src.PROFILE_KEY AS DECIMAL(18,2)),
            CAST(src.ORGANIZATION_KEY AS DECIMAL(18,2)),
            CAST(src.PLAN_KEY AS DECIMAL(18,2)),
            src.EFFECTIVE_DTTM,
            CAST(src.SEC_ROLE_TYPE_DESCR AS VARCHAR(MAX)),
            CAST(src.MEMBER_PERM_TYPE_DESCR AS VARCHAR(MAX)),
            CAST(src.MEMBER_ROLE_TYPE_DESCR AS VARCHAR(MAX)),
            CAST(src.DW_CHANGE_ID AS VARCHAR(MAX)),
            CAST(src.MEMBER_STATUS_DESCR AS VARCHAR(MAX)),
            CAST(src.MEMBER_STATUS_CODE AS VARCHAR(MAX)),
            CAST(src.SEC_ROLE_TYPE_CODE AS VARCHAR(MAX)),
            CAST(src.MEMBER_PERM_TYPE_CODE AS VARCHAR(MAX)),
            CAST(src.MEMBER_ROLE_TYPE_CODE AS VARCHAR(MAX)),
            src.DW_UPD_DTTM,
            src.DW_INS_DTTM,
            src.END_DTTM,
            CAST(src.SEQ_PERSON_ID AS DECIMAL(18,2)),
            CAST(src.UII_MEMBER_ID AS DECIMAL(18,2)),
            CAST(src.SEQ_ORG_ID AS DECIMAL(18,2))
        FROM Stage.UIIDWP01_T_F_ORGANIZATION_MEMBER_AFFILIATION AS src
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.T_F_ORGANIZATION_MEMBER_AFFILIATION AS tgt
            WHERE tgt.ORGANIZATION_KEY = CAST(src.ORGANIZATION_KEY AS DECIMAL(18,2))
              AND tgt.PROFILE_KEY      = CAST(src.PROFILE_KEY AS DECIMAL(18,2))
              AND tgt.EFFECTIVE_DTTM   = src.EFFECTIVE_DTTM
        );

        SET @InsertedRows = @@ROWCOUNT;
        SET @RowsAffected = @InsertedRows + @UpdatedRows;

        SET @EndTime  = SYSDATETIME();
        SET @Duration = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status   = 'SUCCESS';

        INSERT INTO WH_MetaData.Log.Up_sert
            (TableName, ProcedureName, StartTime, EndTime, DurationSeconds, RowsAffected, Status)
        VALUES
            (@TableName, @ProcedureName, @StartTime, @EndTime, @Duration, @RowsAffected, @Status);

    END TRY
    BEGIN CATCH

        SET @EndTime      = SYSDATETIME();
        SET @Duration     = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @Status       = 'FAILED';
        SET @ErrorMessage = ERROR_MESSAGE();

        INSERT INTO WH_MetaData.Log.Up_sert
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
   Each child SP logs independently to WH_MetaData.Log.Up_sert.
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
    FROM WH_MetaData.Log.Up_sert
    WHERE LogDate = CAST(GETDATE() AS DATE)
    ORDER BY StartTime DESC;
END
GO

