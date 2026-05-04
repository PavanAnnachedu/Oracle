
CREATE SCHEMA Nlog;
CREATE TABLE [WH_MetaData].[Nlog].[ETLBatchBronzeDetails]
(
	[BatchId] [int] NULL,
	[TableName] [varchar](255) NULL,
	[TableId] [int] NULL,
	[SchemaName] [varchar](255) NULL,
	[ExtractedRowCount] [bigint] NULL,
	[FilesProcessedCount] [int] NULL,
	[StartTime] [datetime2](6) NULL,
	[EndTime] [datetime2](6) NULL,
	[Status] [varchar](255) NULL,
	[ErrorMessage] [varchar](8000) NULL,
	[SourceName] [varchar](255) NULL
)
GO

CREATE TABLE [WH_MetaData].[Nlog].[ETLBatchHeader]
(
	[BatchId] [int] NOT NULL,
	[PipelineName] [varchar](255) NULL,
	[PipelineRunId] [varchar](255) NULL,
	[StartTime] [datetime2](6) NULL,
	[EndTime] [datetime2](6) NULL,
	[DurationInMinutes] [int] NULL,
	[Status] [varchar](255) NULL,
	[ErrorMessage] [varchar](600) NULL
)
GO

CREATE OR ALTER PROCEDURE Nlog.SP_ETLBatchBronzeDetails
	@BatchId                INT,
	@TableName              VARCHAR(255),
	@TableId                INT,
	@SchemaName             VARCHAR(255),
	@ExtractedRowCount      BIGINT          = NULL,
	@FilesProcessedCount    INT             = NULL,
	@StartTime              DATETIME2(6)    = NULL,
	@EndTime                DATETIME2(6)    = NULL,
	@Status                 VARCHAR(255)    = NULL,
	@ErrorMessage           VARCHAR(8000)   = NULL,
	@SourceName             VARCHAR(255)
AS
BEGIN
	INSERT INTO Nlog.ETLBatchBronzeDetails
	(BatchId, TableName, SchemaName, ExtractedRowCount, FilesProcessedCount,
		StartTime, EndTime, Status, ErrorMessage, SourceName, TableId)
	VALUES
	(@BatchId, @TableName, @SchemaName, @ExtractedRowCount, @FilesProcessedCount,
		@StartTime, @EndTime, @Status, @ErrorMessage, @SourceName, @TableId);
END

CREATE OR ALTER PROCEDURE Nlog.SP_ETLBatchHeader
    @PipelineName   VARCHAR(255),
    @PipelineRunId  VARCHAR(255),
    @StartTime      DATETIME2(6) = NULL,
    @EndTime        DATETIME2(6) = NULL,
    @Status         VARCHAR(255) = NULL,
    @ErrorMessage   VARCHAR(600) = NULL,
    @BatchId        INT          = NULL
AS
BEGIN
    DECLARE @DurationInMinutes   INT;
    DECLARE @ExistingStartTime   DATETIME2(6);
    DECLARE @NewBatchId          INT;

    IF @BatchId IS NOT NULL
    BEGIN
        SELECT @ExistingStartTime = StartTime
        FROM Nlog.ETLBatchHeader
        WHERE BatchId = @BatchId;

        IF @ExistingStartTime IS NULL
        BEGIN
            THROW 50000, 'Invalid BatchId', 1;
        END

        IF @EndTime IS NOT NULL
        BEGIN
            SET @DurationInMinutes = DATEDIFF(MINUTE, @ExistingStartTime, @EndTime);
        END

        UPDATE Nlog.ETLBatchHeader
        SET
            EndTime           = @EndTime,
            Status            = @Status,
            DurationInMinutes = @DurationInMinutes,
            ErrorMessage      = @ErrorMessage
        WHERE BatchId = @BatchId;

        SELECT @BatchId AS BatchId;
    END
    ELSE
    BEGIN
        SELECT @NewBatchId = COALESCE(MAX(BatchId), 0) + 1
        FROM Nlog.ETLBatchHeader;

        IF @StartTime IS NOT NULL AND @EndTime IS NOT NULL
        BEGIN
            SET @DurationInMinutes = DATEDIFF(MINUTE, @StartTime, @EndTime);
        END

        INSERT INTO Nlog.ETLBatchHeader
        (BatchId, PipelineName, PipelineRunId, StartTime, EndTime,
            DurationInMinutes, Status, ErrorMessage)
        VALUES
        (@NewBatchId, @PipelineName, @PipelineRunId, @StartTime, @EndTime,
            @DurationInMinutes, COALESCE(@Status, 'In-Progress'), @ErrorMessage);

        SELECT @NewBatchId AS BatchId;
    END
END

