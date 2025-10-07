


-- Creating the db in SQL and schema 
CREATE DATABASE AV_Gaming;
USE AV_Gaming;
CREATE SCHEMA av;

SELECT name, create_date 
FROM sys.databases
WHERE name = 'AV_Gaming';

-- Checking the data was properly inserted
SELECT TOP 10 * FROM av.Demographics;
SELECT TOP 10 * FROM av.Actigraph;
SELECT TOP 10 * FROM av.[ACTS_MG];
SELECT TOP 10 * FROM av.BARSE;
SELECT TOP 10 * FROM av.BREQ;
SELECT TOP 10 * FROM av.CSAPPA;
SELECT TOP 10 * FROM av.Liking;
SELECT TOP 10 * FROM av.Recall;
SELECT TOP 10 * FROM av.Total_Actigraph;

SELECT 
    TABLE_SCHEMA AS SchemaName,
    TABLE_NAME AS TableName
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY SchemaName, TableName;

-- Renaming the table, this way I won't have to use '[]'
EXEC sp_rename 'av.[ACTS-MG]', 'ACTS_MG', 'OBJECT';

-- 1 row per participant in the Demographics table
IF COL_LENGTH('av.Demographics','Responder_ID') IS NOT NULL
  ALTER TABLE av.Demographics ALTER COLUMN Responder_ID NVARCHAR(50) NOT NULL;
  IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name='PK_Demographics')
    ALTER TABLE av.Demographics ADD CONSTRAINT PK_Demographics PRIMARY KEY (Responder_ID);

-- Make Responder_ID NOT NULL wherever present
IF COL_LENGTH('av.Actigraph','Responder_ID') IS NOT NULL ALTER TABLE av.Actigraph ALTER COLUMN Responder_ID NVARCHAR(50) NOT NULL;
IF COL_LENGTH('av.BARSE','Responder_ID')    IS NOT NULL ALTER TABLE av.BARSE    ALTER COLUMN Responder_ID NVARCHAR(50) NOT NULL;
IF COL_LENGTH('av.BREQ','Responder_ID')     IS NOT NULL ALTER TABLE av.BREQ     ALTER COLUMN Responder_ID NVARCHAR(50) NOT NULL;
IF COL_LENGTH('av.CSAPPA','Responder_ID')   IS NOT NULL ALTER TABLE av.CSAPPA   ALTER COLUMN Responder_ID NVARCHAR(50) NOT NULL;
IF COL_LENGTH('av.Liking','Responder_ID')   IS NOT NULL ALTER TABLE av.Liking   ALTER COLUMN Responder_ID NVARCHAR(50) NOT NULL;
IF COL_LENGTH('av.Recall','Responder_ID')   IS NOT NULL ALTER TABLE av.Recall   ALTER COLUMN Responder_ID NVARCHAR(50) NOT NULL;
IF COL_LENGTH('av.Total_Actigraph','Responder_ID') IS NOT NULL ALTER TABLE av.Total_Actigraph ALTER COLUMN Responder_ID NVARCHAR(50) NOT NULL;
IF OBJECT_ID('av.[ACTS-MG]','U') IS NOT NULL EXEC sp_rename 'av.[ACTS-MG]', 'ACTS_MG', 'OBJECT';
IF COL_LENGTH('av.ACTS_MG','Responder_ID')  IS NOT NULL ALTER TABLE av.ACTS_MG  ALTER COLUMN Responder_ID NVARCHAR(50) NOT NULL;


-- Add row IDs (if missing)
IF OBJECT_ID('av.Recall','U')     IS NOT NULL AND COL_LENGTH('av.Recall','Recall_ID')     IS NULL ALTER TABLE av.Recall     ADD Recall_ID   INT IDENTITY(1,1);
IF OBJECT_ID('av.CSAPPA','U')     IS NOT NULL AND COL_LENGTH('av.CSAPPA','CSAPPA_ID')     IS NULL ALTER TABLE av.CSAPPA     ADD CSAPPA_ID   INT IDENTITY(1,1);
IF OBJECT_ID('av.Liking','U')     IS NOT NULL AND COL_LENGTH('av.Liking','Liking_ID')     IS NULL ALTER TABLE av.Liking     ADD Liking_ID   INT IDENTITY(1,1);
IF OBJECT_ID('av.BARSE','U')      IS NOT NULL AND COL_LENGTH('av.BARSE','BARSE_ID')       IS NULL ALTER TABLE av.BARSE      ADD BARSE_ID    INT IDENTITY(1,1);
IF OBJECT_ID('av.ACTS_MG','U')    IS NOT NULL AND COL_LENGTH('av.ACTS_MG','ACTS_MG_ID')   IS NULL ALTER TABLE av.ACTS_MG    ADD ACTS_MG_ID  INT IDENTITY(1,1);
IF OBJECT_ID('av.BREQ','U')       IS NOT NULL AND COL_LENGTH('av.BREQ','BREQ_ID')         IS NULL ALTER TABLE av.BREQ       ADD BREQ_ID     INT IDENTITY(1,1);


--Normalizing Type in BREQ, de-dupe and UNIQUE
IF OBJECT_ID('av.BREQ','U') IS NOT NULL AND COL_LENGTH('av.BREQ','Type') IS NOT NULL
BEGIN
  UPDATE av.BREQ SET [Type] = 'PA'  WHERE [Type] IN ('P','PA','Phys','Physical');
  UPDATE av.BREQ SET [Type] = 'AVG' WHERE [Type] IN ('AVG','AG','ActiveVG','Active');
  UPDATE av.BREQ SET [Type] = 'SED' WHERE [Type] IN ('SED','S','Sed','SedVG','Sedentary');

  ;WITH winners AS (
    SELECT Responder_ID, Week, [Type], MAX(BREQ_ID) AS keep_id
    FROM av.BREQ
    GROUP BY Responder_ID, Week, [Type])

  DELETE b
  FROM av.BREQ b
  JOIN winners w
    ON w.Responder_ID=b.Responder_ID AND w.Week=b.Week AND w.[Type]=b.[Type]
   AND w.keep_id<>b.BREQ_ID;

  IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name='UQ_BREQ')
    ALTER TABLE av.BREQ ADD CONSTRAINT UQ_BREQ UNIQUE (Responder_ID, Week, [Type]);
END

-- Recall: de-dupe to (Responder_ID,Week,Date), add UNIQUE */
IF OBJECT_ID('av.Recall','U') IS NOT NULL AND COL_LENGTH('av.Recall','Date') IS NOT NULL
BEGIN
  ;WITH winners AS (
    SELECT Responder_ID, Week, [Date], MAX(Recall_ID) AS keep_id
    FROM av.Recall
    GROUP BY Responder_ID, Week, [Date]
  )
  DELETE r
  FROM av.Recall r
  JOIN winners w
    ON w.Responder_ID=r.Responder_ID AND w.Week=r.Week AND w.[Date]=r.[Date]
   AND w.keep_id<>r.Recall_ID;

  IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name='UQ_Recall')
    ALTER TABLE av.Recall ADD CONSTRAINT UQ_Recall UNIQUE (Responder_ID, Week, [Date]);
END

-- CSAPPA / Liking / BARSE / ACTS_MG: de-dupe to (Responder_ID,Week), add UNIQUEs
IF OBJECT_ID('av.CSAPPA','U') IS NOT NULL
BEGIN
  ;WITH winners AS (
    SELECT Responder_ID, Week, MAX(CSAPPA_ID) AS keep_id
    FROM av.CSAPPA GROUP BY Responder_ID, Week
  )
  DELETE c FROM av.CSAPPA c
  JOIN winners w ON w.Responder_ID=c.Responder_ID AND w.Week=c.Week AND w.keep_id<>c.CSAPPA_ID;

  IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name='UQ_CSAPPA')
    ALTER TABLE av.CSAPPA ADD CONSTRAINT UQ_CSAPPA UNIQUE (Responder_ID, Week);
END

IF OBJECT_ID('av.Liking','U') IS NOT NULL
BEGIN
  ;WITH winners AS (
    SELECT Responder_ID, Week, MAX(Liking_ID) AS keep_id
    FROM av.Liking GROUP BY Responder_ID, Week
  )
  DELETE l FROM av.Liking l
  JOIN winners w ON w.Responder_ID=l.Responder_ID AND w.Week=l.Week AND w.keep_id<>l.Liking_ID;

  IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name='UQ_Liking')
    ALTER TABLE av.Liking ADD CONSTRAINT UQ_Liking UNIQUE (Responder_ID, Week);
END

IF OBJECT_ID('av.BARSE','U') IS NOT NULL
BEGIN
  ;WITH winners AS (
    SELECT Responder_ID, Week, MAX(BARSE_ID) AS keep_id
    FROM av.BARSE GROUP BY Responder_ID, Week
  )
  DELETE b FROM av.BARSE b
  JOIN winners w ON w.Responder_ID=b.Responder_ID AND w.Week=b.Week AND w.keep_id<>b.BARSE_ID;

  IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name='UQ_BARSE')
    ALTER TABLE av.BARSE ADD CONSTRAINT UQ_BARSE UNIQUE (Responder_ID, Week);
END

IF OBJECT_ID('av.ACTS_MG','U') IS NOT NULL
BEGIN
  ;WITH winners AS (
    SELECT Responder_ID, Week, MAX(ACTS_MG_ID) AS keep_id
    FROM av.ACTS_MG GROUP BY Responder_ID, Week
  )
  DELETE a FROM av.ACTS_MG a
  JOIN winners w ON w.Responder_ID=a.Responder_ID AND w.Week=a.Week AND w.keep_id<>a.ACTS_MG_ID;

  IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name='UQ_ACTS')
    ALTER TABLE av.ACTS_MG ADD CONSTRAINT UQ_ACTS UNIQUE (Responder_ID, Week);
END

-- Actigraph → Demographics (Responder_ID) */
IF OBJECT_ID('av.Actigraph','U') IS NOT NULL
AND OBJECT_ID('av.Demographics','U') IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM av.Actigraph a
                LEFT JOIN av.Demographics d ON d.Responder_ID=a.Responder_ID
                WHERE d.Responder_ID IS NULL)
AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_Actigraph_Demo')
BEGIN
  ALTER TABLE av.Actigraph
    WITH CHECK ADD CONSTRAINT FK_Actigraph_Demo
    FOREIGN KEY (Responder_ID) REFERENCES av.Demographics(Responder_ID);

-- Helpful indexes (guarded)
IF OBJECT_ID('av.Recall','U') IS NOT NULL
  IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_Recall_ResponderWeekDate' AND object_id=OBJECT_ID('av.Recall'))
    CREATE INDEX IX_Recall_ResponderWeekDate   ON av.Recall(Responder_ID, Week, [Date]);

IF OBJECT_ID('av.CSAPPA','U') IS NOT NULL
  IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_CSAPPA_ResponderWeek' AND object_id=OBJECT_ID('av.CSAPPA'))
    CREATE INDEX IX_CSAPPA_ResponderWeek       ON av.CSAPPA(Responder_ID, Week);

IF OBJECT_ID('av.Liking','U') IS NOT NULL
  IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_Liking_ResponderWeek' AND object_id=OBJECT_ID('av.Liking'))
    CREATE INDEX IX_Liking_ResponderWeek       ON av.Liking(Responder_ID, Week);

IF OBJECT_ID('av.BARSE','U') IS NOT NULL
  IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_BARSE_ResponderWeek' AND object_id=OBJECT_ID('av.BARSE'))
    CREATE INDEX IX_BARSE_ResponderWeek        ON av.BARSE(Responder_ID, Week);

IF OBJECT_ID('av.ACTS_MG','U') IS NOT NULL
  IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_ACTS_ResponderWeek' AND object_id=OBJECT_ID('av.ACTS_MG'))
    CREATE INDEX IX_ACTS_ResponderWeek         ON av.ACTS_MG(Responder_ID, Week);

IF OBJECT_ID('av.BREQ','U') IS NOT NULL
  IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_BREQ_ResponderWeekType' AND object_id=OBJECT_ID('av.BREQ'))
    CREATE INDEX IX_BREQ_ResponderWeekType     ON av.BREQ(Responder_ID, Week, [Type]);
GO

-- Creating timepoint
IF OBJECT_ID('av.dim_timepoint','U') IS NULL
BEGIN
  CREATE TABLE av.dim_timepoint(
    week SMALLINT PRIMARY KEY,
    label NVARCHAR(30) NOT NULL,
    is_post BIT NOT NULL
  );

  INSERT INTO av.dim_timepoint(week,label,is_post)
  VALUES (0,'Baseline',0),(1,'Week 1',1),(3,'Week 3',1),(6,'Week 6',1),(10,'Week 10',1);
END


-- Long view for Total_Actigraph (weeks)
IF OBJECT_ID('dbo.dim_timepoint','U') IS NOT NULL
AND OBJECT_ID('av.dim_timepoint','U')  IS NULL
  ALTER SCHEMA av TRANSFER dbo.dim_timepoint;

CREATE OR ALTER VIEW av.v_total_actigraph_long AS
SELECT
    ta.Responder_ID,
    dp.week        AS Week,       -- 0, 6, 10
    dt.label       AS WeekLabel,  -- 'Baseline', 'Week 6', 'Week 10'
    dp.mvpa        AS MVPA,
    dp.light       AS Light,
    dp.sed         AS Sedentary,
    dp.timeworn    AS TimeWorn
FROM av.Total_Actigraph ta
CROSS APPLY (VALUES
   (0,  [bsl_MVPA],   [bsl_light],   [bsl_sed],   CASE WHEN COL_LENGTH('av.Total_Actigraph','bsl_timeworn')    IS NOT NULL THEN [bsl_timeworn]    ELSE NULL END),
   (6,  [_6wk_MVPA],  [_6wk_light],  [_6wk_sed],  CASE WHEN COL_LENGTH('av.Total_Actigraph','_6wk_timeworn')  IS NOT NULL THEN [_6wk_timeworn]  ELSE NULL END),
   (10, [_10wk_MVPA], [_10wk_light], [_10wk_sed], CASE WHEN COL_LENGTH('av.Total_Actigraph','_10wk_timeworn') IS NOT NULL THEN [_10wk_timeworn] ELSE NULL END)
) AS dp(week, mvpa, light, sed, timeworn)
LEFT JOIN av.dim_timepoint dt ON dt.week = dp.week
WHERE dp.mvpa IS NOT NULL OR dp.light IS NOT NULL OR dp.sed IS NOT NULL;

-- Quick Sanity Checks
-- Tables
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA='av'
ORDER BY TABLE_NAME;

-- Views
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA='av';

SELECT * FROM av.dim_timepoint ORDER BY week;

-- Uniqueness constraints
-- Recall must be unique by (Responder_ID, Week, Date)
SELECT Responder_ID, Week, [Date], COUNT(*) c
FROM av.Recall
GROUP BY Responder_ID, Week, [Date]
HAVING COUNT(*) > 1;

-- One row per (Responder_ID, Week) for these:
SELECT 'CSAPPA' src, COUNT(*) c FROM (
  SELECT Responder_ID, Week, COUNT(*) c
  FROM av.CSAPPA GROUP BY Responder_ID, Week HAVING COUNT(*)>1
) x
UNION ALL
SELECT 'Liking', COUNT(*) FROM (
  SELECT Responder_ID, Week, COUNT(*) c
  FROM av.Liking GROUP BY Responder_ID, Week HAVING COUNT(*)>1
) y
UNION ALL
SELECT 'BARSE', COUNT(*) FROM (
  SELECT Responder_ID, Week, COUNT(*) c
  FROM av.BARSE GROUP BY Responder_ID, Week HAVING COUNT(*)>1
) z
UNION ALL
SELECT 'ACTS_MG', COUNT(*) FROM (
  SELECT Responder_ID, Week, COUNT(*) c
  FROM av.ACTS_MG GROUP BY Responder_ID, Week HAVING COUNT(*)>1
) w;

-- BREQ unique by (Responder_ID, Week, Type)
SELECT Responder_ID, Week, [Type], COUNT(*) c
FROM av.BREQ
GROUP BY Responder_ID, Week, [Type]
HAVING COUNT(*) > 1;


SELECT kc.name AS constraint_name, t.name AS table_name, kc.type_desc
FROM sys.key_constraints kc
JOIN sys.tables t ON t.object_id = kc.parent_object_id
WHERE t.schema_id = SCHEMA_ID('av')
  AND kc.name IN ('PK_Demographics','UQ_Recall','UQ_CSAPPA','UQ_Liking','UQ_BARSE','UQ_ACTS','UQ_BREQ')
ORDER BY table_name, constraint_name;

SELECT TOP 10 * FROM av.v_total_actigraph_long ORDER BY Responder_ID, Week;

-- Now I can start asking questions about my data. 

-- I want to compare intrinsic vs extrinsic motivation
CREATE OR ALTER VIEW av.v_motivation_activity AS
SELECT
    a.Responder_ID, act.Week,act.WeekLabel,act.MVPA,a.IntrinsicM,a.ExternalM,
    CASE 
        WHEN a.IntrinsicM > a.ExternalM THEN 'Intrinsic'
        WHEN a.ExternalM > a.IntrinsicM THEN 'Extrinsic'
        ELSE 'Balanced'
    END AS MotivationType
FROM av.BREQ a
JOIN av.v_total_actigraph_long act
  ON act.Responder_ID = a.Responder_ID
 AND act.Week = a.Week
WHERE a.[Type] = 'PA';  -- Physical Activity type only


-- Average MVPA by Motivation Type and Week
SELECT
    MotivationType,
    WeekLabel,
    AVG(MVPA) AS Avg_MVPA,
    COUNT(DISTINCT Responder_ID) AS Participants
FROM av.v_motivation_activity
GROUP BY MotivationType, WeekLabel
ORDER BY MotivationType, MIN(Week);

-- Self-perception query
CREATE OR ALTER VIEW av.v_selfperception_activity AS
SELECT
    c.Responder_ID,
    c.Week,
    act.WeekLabel,
    c.Scale_M AS SelfPerceptionScore,
    act.MVPA
FROM av.CSAPPA c
JOIN av.v_total_actigraph_long act
  ON act.Responder_ID = c.Responder_ID
 AND act.Week = c.Week;

-- Correlation-like comparison between self-perception and activity
SELECT
    WeekLabel,
    ROUND(AVG(SelfPerceptionScore),2) AS Avg_SelfPerception,
    ROUND(AVG(MVPA),2) AS Avg_MVPA,
    COUNT(DISTINCT Responder_ID) AS Participants
FROM av.v_selfperception_activity
GROUP BY WeekLabel
ORDER BY MIN(Week);

-- creating total hours of sleep 

CREATE OR ALTER VIEW av.v_recall_daily_summary AS
SELECT
  r.Responder_ID,
  r.Week,
  r.[Date],
  CAST(
    CASE 
      WHEN r.Time_Go_Bed IS NOT NULL AND r.Time_Getup_Bed IS NOT NULL THEN
        CASE 
          WHEN DATEDIFF(minute, CAST('00:00:00' AS time), r.Time_Go_Bed)
             <= DATEDIFF(minute, CAST('00:00:00' AS time), r.Time_Getup_Bed)
          THEN 
            (DATEDIFF(minute, CAST('00:00:00' AS time), r.Time_Getup_Bed)
             - DATEDIFF(minute, CAST('00:00:00' AS time), r.Time_Go_Bed)) / 60.0
          ELSE 
            ((1440 - DATEDIFF(minute, CAST('00:00:00' AS time), r.Time_Go_Bed))
             + DATEDIFF(minute, CAST('00:00:00' AS time), r.Time_Getup_Bed)) / 60.0
        END
      ELSE NULL
    END
    AS DECIMAL(10,2)
  ) AS SleepHours,
  (COALESCE(TRY_CONVERT(float, r.[Hours_AV]), 0.0)              + COALESCE(TRY_CONVERT(float, r.[Minutes_AV]), 0.0)/60.0)              AS ActiveVG_Hours,
  (COALESCE(TRY_CONVERT(float, r.[Hours_NAV]), 0.0)             + COALESCE(TRY_CONVERT(float, r.[Minutes_NAV]), 0.0)/60.0)             AS NonActiveVG_Hours,
  (COALESCE(TRY_CONVERT(float, r.[Hours_TV]), 0.0)              + COALESCE(TRY_CONVERT(float, r.[Minutes_TV]), 0.0)/60.0)              AS TV_Hours,
  (COALESCE(TRY_CONVERT(float, r.[Hours_Computer]), 0.0)        + COALESCE(TRY_CONVERT(float, r.[Minutes_Computer]), 0.0)/60.0)        AS Computer_Hours,
  (COALESCE(TRY_CONVERT(float, r.[Hours_HW]), 0.0)              + COALESCE(TRY_CONVERT(float, r.[Minutes_HW]), 0.0)/60.0)              AS Homework_Hours,
  (COALESCE(TRY_CONVERT(float, r.[Hours_Social]), 0.0)          + COALESCE(TRY_CONVERT(float, r.[Minutes_Social]), 0.0)/60.0)          AS Social_Hours,
  (COALESCE(TRY_CONVERT(float, r.[Hours_Hobbies]), 0.0)         + COALESCE(TRY_CONVERT(float, r.[Minutes_Hobbies]), 0.0)/60.0)         AS Hobbies_Hours,
  (COALESCE(TRY_CONVERT(float, r.[Hours_Transportation]), 0.0)  + COALESCE(TRY_CONVERT(float, r.[Minutes_Transportation]), 0.0)/60.0)  AS Transport_Hours,
  (COALESCE(TRY_CONVERT(float, r.[Hours_School]), 0.0)          + COALESCE(TRY_CONVERT(float, r.[Minutes_School]), 0.0)/60.0)          AS School_Hours,
  (COALESCE(TRY_CONVERT(float, r.[Hours_Sports]), 0.0)          + COALESCE(TRY_CONVERT(float, r.[Minutes_Sports]), 0.0)/60.0)          AS Sports_Hours,
  (COALESCE(TRY_CONVERT(float, r.[Hours_Walking_Bike]), 0.0)    + COALESCE(TRY_CONVERT(float, r.[Minutes_Walking_Bike]), 0.0)/60.0)    AS WalkBike_Hours,
  (COALESCE(TRY_CONVERT(float, r.[Hours_Chores]), 0.0)          + COALESCE(TRY_CONVERT(float, r.[Minutes_Chores]), 0.0)/60.0)          AS Chores_Hours,
  (COALESCE(TRY_CONVERT(float, r.[Hours_PE]), 0.0)              + COALESCE(TRY_CONVERT(float, r.[Minutes_PE]), 0.0)/60.0)              AS PE_Hours,
  (
    COALESCE(TRY_CONVERT(float, r.[Hours_AV]), 0.0)              + COALESCE(TRY_CONVERT(float, r.[Minutes_AV]), 0.0)/60.0
    + COALESCE(TRY_CONVERT(float, r.[Hours_NAV]), 0.0)           + COALESCE(TRY_CONVERT(float, r.[Minutes_NAV]), 0.0)/60.0
    + COALESCE(TRY_CONVERT(float, r.[Hours_TV]), 0.0)            + COALESCE(TRY_CONVERT(float, r.[Minutes_TV]), 0.0)/60.0
    + COALESCE(TRY_CONVERT(float, r.[Hours_Computer]), 0.0)      + COALESCE(TRY_CONVERT(float, r.[Minutes_Computer]), 0.0)/60.0
  ) AS Total_Screen_Hours,
  (
    COALESCE(TRY_CONVERT(float, r.[Hours_Sports]), 0.0)          + COALESCE(TRY_CONVERT(float, r.[Minutes_Sports]), 0.0)/60.0
    + COALESCE(TRY_CONVERT(float, r.[Hours_Walking_Bike]), 0.0)  + COALESCE(TRY_CONVERT(float, r.[Minutes_Walking_Bike]), 0.0)/60.0
    + COALESCE(TRY_CONVERT(float, r.[Hours_PE]), 0.0)            + COALESCE(TRY_CONVERT(float, r.[Minutes_PE]), 0.0)/60.0
  ) AS Total_Physical_Hours
FROM av.Recall r;
