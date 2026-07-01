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
