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
-- There is data to clear [Cell 1]
SELECT Description FROM OnlineRetail
WHERE 
    Description = LOWER(Description) -- Whole description is lowercase
    OR (LEFT(Description, 1) = UPPER(LEFT(Description, 1)) 
    AND SUBSTRING(Description, 2) = LOWER(SUBSTRING(Description, 2))) -- First letter is uppercase, the rest is lowercase
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
        Description != LOWER(Description) -- Whole description is not lowercase
        AND (LEFT(Description, 1) != UPPER(LEFT(Description, 1)) -- Don't select desc. where the first letter is uppercase and the rest is lowercase
            OR SUBSTRING(Description, 2) != LOWER(SUBSTRING(Description, 2))) 
        AND Description IS NOT NULL
        AND StockCode NOT IN ('POST', 'DOT', 'AMAZONFEE', 'BANK CHARGES', 'S', 'CRUK', 'C2') -- Don't include things that are not products
);

-- How does cleared data look like [Cell 2]
SELECT * FROM temp_OnlineRetail LIMIT 20;

---------------------------------------------------------------------------------------------------
-- Let's answer to some questions:

-- What is the distribution of prices across dataset?
-- What is the distribution of order values across all customers in the dataset?
-- Which countries are our most significant customers?
-- How many unique products has each customer purchased?
-- Which customers have only made a single purchase from the company?
-- Which products are most commonly purchased together by customers in the dataset?
-- What product do customers buy most often?
-- What product do customers without account buy most often?
-- How many products were purchased in total? How much on average per customer?
-- How many returns were there in total? How much on average per customer?

---------------------------------------------------------------------------------------------------
-- Mean [Cell 3]
SELECT AVG(UnitPrice)::numeric(10, 2) FROM temp_OnlineRetail;

-- Distribution of prices below and over mean [Cell 4]
WITH consts (avg) as (
    values ((SELECT AVG(UnitPrice) FROM temp_OnlineRetail))
)
SELECT UnitPrice, COUNT(*) FROM (
    SELECT CASE WHEN UnitPrice BETWEEN -100000 AND (SELECT avg FROM consts) THEN '(-INF, AVG)'
                WHEN UnitPrice BETWEEN (SELECT avg FROM consts) AND 100000 THEN '(AVG, INF)'     
    END AS UnitPrice
    FROM temp_OnlineRetail 
)
GROUP BY UnitPrice;

-- Distribution of prices in ranges [Cell 5]
SELECT UnitPrice, COUNT(*) FROM (
    SELECT CASE WHEN UnitPrice BETWEEN 0 AND 10 THEN '(0, 10)'
                WHEN UnitPrice BETWEEN 10 AND 100 THEN '(10, 100)' 
                WHEN UnitPrice BETWEEN 100 AND 1000 THEN '(100, 1000)' 
    END AS UnitPrice
    FROM temp_OnlineRetail
)
GROUP BY UnitPrice ORDER BY UnitPrice;

---------------------------------------------------------------------------------------------------
-- What is the distribution of order values across all customers in the dataset? [Cell 6]
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
GROUP BY total ORDER BY total;

---------------------------------------------------------------------------------------------------
-- Which countries are our most significant customers? [Cell 7]
SELECT Country, SUM(UnitPrice)::numeric(10, 2) AS total FROM temp_OnlineRetail
WHERE Quantity > 0
GROUP BY Country
ORDER BY total DESC LIMIT 5;

---------------------------------------------------------------------------------------------------
-- How many unique products has each customer purchased? [Cell 8] 
SELECT CustomerID, Count(DISTINCT StockCode) FROM temp_OnlineRetail
WHERE CustomerID IS NOT NULL
GROUP BY CustomerID ORDER BY Count(DISTINCT StockCode) DESC LIMIT 10;

---------------------------------------------------------------------------------------------------
-- Which customers have only made a single purchase from the company? [Cell 9]
SELECT CustomerID, StockCode, Quantity FROM temp_OnlineRetail
WHERE Quantity=1 AND 
CustomerID IN (
    SELECT CustomerID FROM temp_OnlineRetail
    WHERE Quantity=1 
    GROUP BY CustomerID
    HAVING Count(*)=1
)
ORDER BY CustomerID;

---------------------------------------------------------------------------------------------------
-- Which products are most commonly purchased together by customers in the dataset? [Cell 10]
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
LIMIT 10;

---------------------------------------------------------------------------------------------------
-- What product do customers buy most often? [Cell 11]
SELECT StockCode, Description, SUM(Quantity) FROM temp_OnlineRetail  
WHERE Quantity > 0
GROUP BY StockCode, Description
ORDER BY SUM(Quantity) DESC LIMIT 10;

---------------------------------------------------------------------------------------------------
-- What product do customers without account buy most often? [Cell 12]
SELECT StockCode, Description, SUM(Quantity) FROM temp_OnlineRetail  
WHERE Quantity > 0 AND CustomerID IS NULL
GROUP BY StockCode, Description
ORDER BY SUM(Quantity) DESC LIMIT 10;

---------------------------------------------------------------------------------------------------
-- How many products were purchased in total? How much on average per customer? [Cell 13]
SELECT SUM(Quantity) AS TotalProductsSold, (SUM(Quantity) / Count(Quantity)) AS AveragePerCustomer 
FROM temp_OnlineRetail WHERE Quantity > 0 AND CustomerID IS NOT NULL;

---------------------------------------------------------------------------------------------------
-- How many returns were there in total? How much on average per customer? [Cell 14]
SELECT SUM(Quantity)*(-1) AS TotalProductsSold, (SUM(Quantity) / Count(Quantity))*(-1) AS AveragePerCustomer 
FROM temp_OnlineRetail WHERE Quantity < 0 AND CustomerID IS NOT NULL;