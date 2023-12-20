--https://www.projectpro.io/article/sql-database-projects-for-data-analysis-to-practice/565
--https://archive.ics.uci.edu/dataset/352/online+retail
---------------------------------------------------------------------------------------------------
-- Initialization
CREATE TABLE IF NOT EXISTS OnlineRetail (
    InvoiceNo VARCHAR(255),
    StockCode VARCHAR(255),
    Description VARCHAR(255),
    Quantity INT,
    InvoiceDate DATE,
    UnitPrice FLOAT,
    CustomerID INT,
    Country VARCHAR(255)
);

-- Things done outside the editor:
    -- Change commas to dots in UnitPrice column 
    -- Convert xlsx to csv file
    -- Import csv to database

---------------------------------------------------------------------------------------------------
SELECT Description FROM OnlineRetail
WHERE 
    Description = LOWER(Description) --Whole description is lowercase
    OR (LEFT(Description, 1) = UPPER(LEFT(Description, 1)) 
    AND SUBSTRING(Description, 2) = LOWER(SUBSTRING(Description, 2))) --First letter is uppercase, the rest is lowercase
    OR Description IS NULL
GROUP BY Description LIMIT 10;


--Prepare Data
CREATE TEMPORARY TABLE IF NOT EXISTS temp_OnlineRetail (
    InvoiceNo VARCHAR(255),
    StockCode VARCHAR(255),
    Description VARCHAR(255),
    Quantity INT,
    InvoiceDate DATE,
    UnitPrice FLOAT,
    CustomerID INT,
    Country VARCHAR(255)
);

INSERT INTO temp_OnlineRetail (
    SELECT * FROM OnlineRetail
    WHERE 
        Description != LOWER(Description) --Whole description is not lowercase
        AND (LEFT(Description, 1) != UPPER(LEFT(Description, 1)) --Don't select desc. where the first letter is uppercase and the rest is lowercase
            OR SUBSTRING(Description, 2) != LOWER(SUBSTRING(Description, 2))) 
        AND Description IS NOT NULL
        AND StockCode NOT IN ('POST', 'DOT', 'AMAZONFEE', 'BANK CHARGES', 'S', 'CRUK', 'C2') --Don't include things that are not products
)

--What is the distribution of order values across all customers in the dataset?
--How many unique products has each customer purchased?
--Which customers have only made a single purchase from the company?
--Which products are most commonly purchased together by customers in the dataset?
--What product do customers buy most often?
--What product do customers without account buy most often?
--How many products were purchased in total? How much on average per customer?
--How many returns were there in total? How much on average per customer?

SELECT * FROM temp_OnlineRetail LIMIT 20;
---------------------------------------------------------------------------------------------------
--What is the distribution of order values across all customers in the dataset?

-- Mean
SELECT AVG(UnitPrice)::numeric(10, 2) FROM temp_OnlineRetail

-- Distribution below and over mean
WITH consts (avg) as (
    values ((SELECT AVG(UnitPrice) FROM temp_OnlineRetail))
)
SELECT UnitPrice, COUNT(*) FROM (
    SELECT CASE WHEN UnitPrice BETWEEN -100000 AND (SELECT avg FROM consts) THEN '1. (-INF, AVG)'
                WHEN UnitPrice BETWEEN (SELECT avg FROM consts) AND 100000 THEN '2. (AVG, INF)'     
    END AS UnitPrice
    FROM temp_OnlineRetail 
)
GROUP BY UnitPrice

-- Distribution of prices in ranges
SELECT UnitPrice, COUNT(*) FROM (
    SELECT CASE WHEN UnitPrice BETWEEN 0 AND 10 THEN '(0, 10)'
                WHEN UnitPrice BETWEEN 10 AND 100 THEN '(10, 100)' 
                WHEN UnitPrice BETWEEN 100 AND 1000 THEN '(100, 1000)' 
    END AS UnitPrice
    FROM temp_OnlineRetail
)
GROUP BY UnitPrice ORDER BY UnitPrice


-- Distribution of invoice value
WITH InvoiceAmount AS (
    SELECT InvoiceNo, SUM(UnitPrice) AS total FROM temp_OnlineRetail
    WHERE Quantity > 0
    GROUP BY InvoiceNo
)
SELECT total, COUNT(*) FROM (
    SELECT CASE WHEN total BETWEEN 0 AND 10 THEN '(0, 10)'
                WHEN total BETWEEN 10 AND 100 THEN '(10, 100)' 
                WHEN total BETWEEN 100 AND 1000 THEN '(100, 1000)' 
                WHEN total BETWEEN 1000 AND 10000 THEN '(1000, 10000)' 
    END AS total
    FROM InvoiceAmount
)
GROUP BY total ORDER BY total

-- Truncate data
SELECT AVG(UnitPrice)::numeric(10, 2)  FROM  (
    SELECT UnitPrice FROM temp_OnlineRetail WHERE UnitPrice >= 0 AND UnitPrice <= 1000
)

-- Distribution below and over mean
WITH consts (avg) as (
    values ((
        SELECT AVG(UnitPrice)::numeric(10, 2)  FROM  (
            SELECT UnitPrice FROM temp_OnlineRetail WHERE UnitPrice >= 0 AND UnitPrice <= 1000
        )
    ))
)
SELECT UnitPrice, COUNT(*) FROM (
    SELECT CASE WHEN UnitPrice BETWEEN -100000 AND (SELECT avg FROM consts) THEN '1. (-INF, AVG)'
                WHEN UnitPrice BETWEEN (SELECT avg FROM consts) AND 100000 THEN '2. (AVG, INF)'     
    END AS UnitPrice
    FROM (
        SELECT UnitPrice FROM temp_OnlineRetail WHERE UnitPrice >= 0 AND UnitPrice <= 1000
    )
)
GROUP BY UnitPrice 


---------------------------------------------------------------------------------------------------
--How many unique products has each customer purchased?
SELECT COUNT(DISTINCT Description) FROM temp_OnlineRetail;
SELECT COUNT(DISTINCT StockCode) FROM temp_OnlineRetail

--Example of same Stockcode but different description
SELECT DISTINCT CustomerID, StockCode, Description FROM temp_OnlineRetail 
WHERE CustomerID=14911 AND StockCode = '21243'

--Top 10 customers who purchased the most products. Each of them is unique. 
SELECT CustomerID, Count(DISTINCT StockCode) FROM temp_OnlineRetail
WHERE CustomerID IS NOT NULL
GROUP BY CustomerID ORDER BY Count(DISTINCT StockCode) DESC LIMIT 10;


---------------------------------------------------------------------------------------------------
--Which customers have only made a single purchase from the company?

SELECT CustomerID, StockCode, Quantity FROM temp_OnlineRetail
WHERE Quantity=1 AND 
CustomerID IN (
    SELECT CustomerID FROM temp_OnlineRetail
    WHERE Quantity=1 
    GROUP BY CustomerID
    HAVING Count(*)=1
)
ORDER BY CustomerID

---------------------------------------------------------------------------------------------------
--Which products are most commonly purchased together by customers in the dataset?

WITH CustomersBuyingMultipleProducts AS (
    SELECT CustomerID, Count(*) FROM (
        SELECT DISTINCT CustomerID, StockCode FROM temp_OnlineRetail
        ORDER BY CustomerID
    )
    WHERE CustomerID IS NOT NULL
    GROUP BY CustomerID
    HAVING Count(*) > 1
) 
SELECT StockCode, Description, Count(StockCode) AS incidence FROM temp_OnlineRetail
WHERE CustomerID in (SELECT CustomerID FROM CustomersBuyingMultipleProducts)
GROUP BY StockCode, Description
ORDER BY incidence DESC
LIMIT 10

---------------------------------------------------------------------------------------------------
--What product do customers buy most often?
SELECT StockCode, Description, SUM(Quantity) FROM temp_OnlineRetail  
WHERE Quantity > 0
GROUP BY StockCode, Description
ORDER BY SUM(Quantity) DESC LIMIT 10



---------------------------------------------------------------------------------------------------
--What product do customers without account buy most often?
SELECT StockCode, Description, SUM(Quantity) FROM temp_OnlineRetail  
WHERE Quantity > 0 AND CustomerID IS NULL
GROUP BY StockCode, Description
ORDER BY SUM(Quantity) DESC LIMIT 10





---------------------------------------------------------------------------------------------------
--How many products were purchased in total? How much on average per customer?


SELECT SUM(Quantity) AS TotalProductsSold, (SUM(Quantity) / Count(Quantity)) AS AveragePerCustomer 
FROM temp_OnlineRetail WHERE Quantity > 0 AND CustomerID IS NOT NULL  


---------------------------------------------------------------------------------------------------
--How many returns were there in total? How much on average per customer?

SELECT SUM(Quantity)*(-1) AS TotalProductsSold, (SUM(Quantity) / Count(Quantity))*(-1) AS AveragePerCustomer 
FROM temp_OnlineRetail WHERE Quantity < 0 AND CustomerID IS NOT NULL  