-- ============================================================
-- AEMR ENERGY RELIABILITY ANALYSIS
-- SQL Portfolio File
-- ============================================================
-- Source table: AEMR_Outage_Table
-- Analysis period: 2016-2017
-- Primary scope: Approved outage events
--
-- This file contains the SQL queries used during the analysis
-- that informed the AEMR Energy Reliability Analysis in Tableau.
-- Queries are organized by analytical purpose for portfolio review.
-- ============================================================


-- ============================================================
-- 1. APPROVED OUTAGES BY TYPE AND YEAR
-- Counts approved outage events by outage reason for 2016 and 2017.
-- ============================================================

SELECT
    COUNT(EventID) AS Total_Number_Outages,
    Outage_Reason,
    Year
FROM AEMR_Outage_Table
WHERE Status = 'Approved'
    AND Year IN (2016, 2017)
GROUP BY Outage_Reason, Year
ORDER BY Outage_Reason, Year;


-- ============================================================
-- 2. MONTHLY APPROVED OUTAGE TOTALS
-- Summarizes all approved outage events by year and month.
-- ============================================================

WITH Approved_Outages AS (
    SELECT
        EventID,
        Year,
        Month,
        Outage_Reason
    FROM AEMR_Outage_Table
    WHERE Status = 'Approved'
      AND Year IN (2016, 2017)
)

SELECT
    Year,
    Month,
    COUNT(EventID) AS Total_Number_Outages
FROM Approved_Outages
GROUP BY Year, Month
ORDER BY
    Year,
    Month,
    Total_Number_Outages DESC;


-- ============================================================
-- 3. MONTHLY OUTAGE TOTALS BY OUTAGE TYPE
-- Breaks monthly outage activity down by outage reason.
-- ============================================================

WITH Approved_Outages AS (
    SELECT
        EventID,
        Year,
        Month,
        Outage_Reason
    FROM AEMR_Outage_Table
    WHERE Status = 'Approved'
      AND Year IN (2016, 2017)
)

SELECT
    Outage_Reason AS Outage_Type,
    Year,
    Month,
    COUNT(EventID) AS Total_Number_Outages
FROM Approved_Outages
GROUP BY
    Outage_Reason,
    Year,
    Month
ORDER BY
    Outage_Reason,
    Month,
    Year;


-- ============================================================
-- 4. PARTICIPANT OUTAGE FREQUENCY AND AVERAGE DURATION
-- Calculates event counts and average outage duration in days
-- by participant, outage reason, and year.
-- ============================================================

SELECT
    Participant_Code,
    Outage_Reason,
    Year,
    COUNT(EventID) AS Total_Number_Outage_Events,
    ROUND(
        AVG(
            ABS(
                JULIANDAY(End_Time) - JULIANDAY(Start_Time)
            )
        ),
        2
    ) AS Average_Duration_Days
FROM AEMR_Outage_Table
WHERE Status = 'Approved'
  AND Year IN (2016, 2017)
GROUP BY
    Participant_Code,
    Outage_Reason,
    Year
ORDER BY
    Total_Number_Outage_Events DESC,
    Outage_Reason,
    Year;


-- ============================================================
-- 5. PARTICIPANT RISK CLASSIFICATION BY AVERAGE DURATION
-- Classifies participants as High, Medium, or Low Risk based
-- on their average approved outage duration.
-- ============================================================

WITH Participant_Average_Duration AS (
    SELECT
        Participant_Code,
        AVG(
            ABS(
                JULIANDAY(End_Time) - JULIANDAY(Start_Time)
            )
        ) AS Average_Duration_Days
    FROM AEMR_Outage_Table
    WHERE Status = 'Approved'
      AND Year IN (2016, 2017)
    GROUP BY Participant_Code
)

SELECT
    Participant_Code,
    ROUND(Average_Duration_Days, 2) AS Average_Duration_Time_In_Days,
    CASE
        WHEN Average_Duration_Days > 1 THEN 'High Risk'
        WHEN Average_Duration_Days >= 0.5 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS Risk_Classification
FROM Participant_Average_Duration
ORDER BY Average_Duration_Days DESC;


-- ============================================================
-- 6. PARTICIPANT RISK CLASSIFICATION BY DURATION AND FREQUENCY
-- Applies a combined risk framework using average duration
-- and event frequency, with non-forced outages marked N/A.
-- ============================================================

WITH Participant_Outage_Summary AS (
    SELECT
        Participant_Code,
        Outage_Reason,
        COUNT(EventID) AS Total_Number_Outage_Events,
        AVG(
            ABS(
                JULIANDAY(End_Time) - JULIANDAY(Start_Time)
            )
        ) AS Average_Duration_Days
    FROM AEMR_Outage_Table
    WHERE Status = 'Approved'
      AND Year IN (2016, 2017)
    GROUP BY
        Participant_Code,
        Outage_Reason
)

SELECT
    Participant_Code,
    Outage_Reason,
    Total_Number_Outage_Events,
    ROUND(Average_Duration_Days, 2)
        AS Average_Duration_Time_In_Days,
    CASE
        WHEN Outage_Reason <> 'Forced'
            THEN 'N/A'

        WHEN Average_Duration_Days > 1
             OR Total_Number_Outage_Events > 20
            THEN 'High Risk'

        WHEN Average_Duration_Days >= 0.5
             OR Total_Number_Outage_Events >= 10
            THEN 'Medium Risk'

        ELSE 'Low Risk'
    END AS Risk_Classification

FROM Participant_Outage_Summary
ORDER BY Average_Duration_Days DESC;


-- ============================================================
-- 7. OUTAGE TYPE SHARE BY YEAR
-- Calculates each outage reason's percentage of approved
-- outage events within each year.
-- ============================================================

WITH Outage_Counts AS (
    SELECT
        Year,
        Outage_Reason,
        COUNT(EventID) AS Total_Number_Outages
    FROM AEMR_Outage_Table
    WHERE Status = 'Approved'
      AND Year IN (2016, 2017)
    GROUP BY
        Year,
        Outage_Reason
),

Yearly_Outage_Totals AS (
    SELECT
        Year,
        SUM(Total_Number_Outages) AS Total_Outages_Per_Year
    FROM Outage_Counts
    GROUP BY Year
)

SELECT
    o.Year,
    o.Outage_Reason,
    o.Total_Number_Outages,
    ROUND(
        100.0 * o.Total_Number_Outages
        / y.Total_Outages_Per_Year,
        2
    ) AS Proportion_Of_Outages_Percent
FROM Outage_Counts AS o
JOIN Yearly_Outage_Totals AS y
    ON o.Year = y.Year
ORDER BY
    o.Year,
    Proportion_Of_Outages_Percent DESC;


-- ============================================================
-- 8. FACILITY-LEVEL OUTAGE AND ENERGY-LOSS SUMMARY
-- Calculates outage counts, total duration, and total energy
-- lost by participant, facility, and year for approved outages.
-- ============================================================

SELECT
    Year,
    Participant_Code,
    Facility_Code,
    COUNT(EventID) AS Total_Number_Of_Outages,
    ROUND(
        SUM(
            ABS(
                JULIANDAY(End_Time) - JULIANDAY(Start_Time)
            )
        ),
        2
    ) AS Total_Duration_In_Days,
    ROUND(
        SUM(COALESCE(Energy_Lost_MW, 0)),
        2
    ) AS Total_Energy_Lost_MW
FROM AEMR_Outage_Table
WHERE Status = 'Approved'
  AND Year IN (2016, 2017)
GROUP BY
    Year,
    Participant_Code,
    Facility_Code
ORDER BY
    Year,
    Total_Energy_Lost_MW DESC;


-- ============================================================
-- 9. FORCED-OUTAGE FACILITY SEVERITY
-- Calculates average duration and average energy lost for
-- forced outages by participant, facility, and year.
-- ============================================================

SELECT
    Year,
    Participant_Code,
    Facility_Code,
    ROUND(
        AVG(
            ABS(
                JULIANDAY(End_Time) - JULIANDAY(Start_Time)
            )
        ),
        2
    ) AS Average_Duration_In_Days,
    ROUND(
        AVG(Energy_Lost_MW),
        2
    ) AS Average_Energy_Lost_MW
FROM AEMR_Outage_Table
WHERE Status = 'Approved'
  AND Outage_Reason = 'Forced'
  AND Year IN (2016, 2017)
GROUP BY
    Year,
    Participant_Code,
    Facility_Code
ORDER BY
    Year,
    Average_Energy_Lost_MW DESC;


-- ============================================================
-- 10. FORCED ENERGY-LOSS CONCENTRATION BY FACILITY
-- Calculates average energy lost, total energy lost, and each
-- facility's share of all forced-outage energy loss.
-- ============================================================

WITH Forced_Outages AS (
    SELECT
        Participant_Code,
        Facility_Code,
        Energy_Lost_MW
    FROM AEMR_Outage_Table
    WHERE Status = 'Approved'
      AND Outage_Reason = 'Forced'
      AND Year IN (2016, 2017)
      AND Energy_Lost_MW IS NOT NULL
),

Facility_Energy_Summary AS (
    SELECT
        Participant_Code,
        Facility_Code,
        AVG(Energy_Lost_MW) AS Average_Energy_Lost_MW,
        SUM(Energy_Lost_MW) AS Total_Energy_Lost_MW
    FROM Forced_Outages
    GROUP BY
        Participant_Code,
        Facility_Code
)

SELECT
    Participant_Code,
    Facility_Code,
    ROUND(Average_Energy_Lost_MW, 2)
        AS Average_Energy_Lost_MW,
    ROUND(Total_Energy_Lost_MW, 2)
        AS Total_Energy_Lost_MW,
    ROUND(
        100.0 * Total_Energy_Lost_MW
        / (
            SELECT SUM(Energy_Lost_MW)
            FROM Forced_Outages
        ),
        2
    ) AS Percentage_Of_Forced_Energy_Lost
FROM Facility_Energy_Summary
ORDER BY Total_Energy_Lost_MW DESC;


-- ============================================================
-- 11. HIGHEST-IMPACT FORCED-OUTAGE CAUSES
-- For GW, MELK, and AURICON, identifies the outage description
-- responsible for the greatest energy loss within each facility
-- and calculates its share of that facility's energy loss.
-- ============================================================

WITH Description_Energy_Loss AS (
    SELECT
        Participant_Code,
        Facility_Code,
        Description_Of_Outage,
        SUM(COALESCE(Energy_Lost_MW, 0))
            AS Description_Total_Energy_Lost
    FROM AEMR_Outage_Table
    WHERE Status = 'Approved'
      AND Outage_Reason = 'Forced'
      AND Year IN (2016, 2017)
      AND Participant_Code IN ('GW', 'MELK', 'AURICON')
    GROUP BY
        Participant_Code,
        Facility_Code,
        Description_Of_Outage
),

Ranked_Descriptions AS (
    SELECT
        Participant_Code,
        Facility_Code,
        Description_Of_Outage,
        Description_Total_Energy_Lost,

        SUM(Description_Total_Energy_Lost) OVER (
            PARTITION BY Participant_Code, Facility_Code
        ) AS Total_Energy_Lost,

        ROW_NUMBER() OVER (
            PARTITION BY Participant_Code, Facility_Code
            ORDER BY Description_Total_Energy_Lost DESC
        ) AS Energy_Loss_Rank

    FROM Description_Energy_Loss
)

SELECT
    Participant_Code,
    Facility_Code,

    ROUND(Total_Energy_Lost, 2)
        AS Total_Energy_Lost,

    Description_Of_Outage
        AS Highest_Energy_Loss_Description,

    ROUND(Description_Total_Energy_Lost, 2)
        AS Energy_Lost_For_Description,

    ROUND(
        100.0 * Description_Total_Energy_Lost
        / NULLIF(Total_Energy_Lost, 0),
        2
    ) AS Percentage_Of_Energy_Loss

FROM Ranked_Descriptions
WHERE Energy_Loss_Rank = 1
ORDER BY Total_Energy_Lost DESC;
