-- =========================================================
-- E-COMMERCE CUSTOMER ANALYSIS
-- Dataset: UCI Online Retail
-- Database: SQLite
-- =========================================================


-- =========================================================
-- 1. Which countries generate the most revenue?
-- =========================================================

SELECT
    Country,
    ROUND(SUM(Revenue), 2) AS Total_Revenue
FROM transactions
GROUP BY Country
ORDER BY Total_Revenue DESC;


-- =========================================================
-- 2. Which products generate the most revenue?
-- =========================================================

SELECT
    Description,
    ROUND(SUM(Revenue), 2) AS Total_Revenue
FROM transactions
WHERE Quantity > 0
GROUP BY Description
ORDER BY Total_Revenue DESC
LIMIT 10;


-- =========================================================
-- 3. Which products sell the most units?
-- =========================================================

SELECT
    Description,
    SUM(Quantity) AS Total_Quantity
FROM transactions
WHERE Quantity > 0
GROUP BY Description
ORDER BY Total_Quantity DESC
LIMIT 10;


-- =========================================================
-- 4. How does revenue change month-to-month?
-- =========================================================

SELECT
    Year,
    Month,
    ROUND(SUM(Revenue), 2) AS Total_Revenue
FROM transactions
GROUP BY Year, Month
ORDER BY Year, Month;


-- =========================================================
-- 5. Which days of the week generate the most revenue?
-- =========================================================

SELECT
    CASE
        WHEN DayOfWeek = 0 THEN 'Monday'
        WHEN DayOfWeek = 1 THEN 'Tuesday'
        WHEN DayOfWeek = 2 THEN 'Wednesday'
        WHEN DayOfWeek = 3 THEN 'Thursday'
        WHEN DayOfWeek = 4 THEN 'Friday'
        WHEN DayOfWeek = 5 THEN 'Saturday'
        WHEN DayOfWeek = 6 THEN 'Sunday'
    END AS Day_Of_Week,
    ROUND(SUM(Revenue), 2) AS Total_Revenue
FROM transactions
GROUP BY DayOfWeek
ORDER BY Total_Revenue DESC;


-- =========================================================
-- 6. What hours of the day generate the most revenue?
-- =========================================================

SELECT
    Hour,
    ROUND(SUM(Revenue), 2) AS Total_Revenue
FROM transactions
GROUP BY Hour
ORDER BY Total_Revenue DESC;


-- =========================================================
-- 7. Who are the highest-value customers?
-- =========================================================

SELECT
    CustomerID,
    ROUND(SUM(Revenue), 2) AS Total_Revenue
FROM transactions
GROUP BY CustomerID
ORDER BY Total_Revenue DESC
LIMIT 10;


-- =========================================================
-- 8. How concentrated is revenue among the top 10 customers?
-- =========================================================

WITH TopCustomers AS (
    SELECT
        CustomerID,
        SUM(Revenue) AS Total_Revenue
    FROM transactions
    GROUP BY CustomerID
    ORDER BY Total_Revenue DESC
    LIMIT 10
),

Top10Revenue AS (
    SELECT
        SUM(Total_Revenue) AS Top10_Revenue
    FROM TopCustomers
),

TotalRevenue AS (
    SELECT
        SUM(Revenue) AS Total_Revenue
    FROM transactions
)

SELECT
    ROUND(Total_Revenue, 2) AS Total_Revenue,
    ROUND(Top10_Revenue, 2) AS Top10_Revenue,
    ROUND(
        (Top10_Revenue * 1.0 / Total_Revenue) * 100,
        2
    ) AS Top10_Revenue_Percentage
FROM TotalRevenue
CROSS JOIN Top10Revenue;


-- =========================================================
-- 9. Which countries have the highest average order value?
-- =========================================================

WITH Orders AS (
    SELECT
        InvoiceNo,
        Country,
        SUM(Revenue) AS Order_Revenue
    FROM transactions
    WHERE Quantity > 0
    GROUP BY InvoiceNo, Country
)

SELECT
    Country,
    ROUND(AVG(Order_Revenue), 2) AS Average_Order_Value
FROM Orders
GROUP BY Country
ORDER BY Average_Order_Value DESC
LIMIT 10;


-- =========================================================
-- 10. What percentage of orders are returns/cancellations?
-- =========================================================

WITH TotalReturns AS (
    SELECT
        COUNT(DISTINCT InvoiceNo) AS Total_Returns
    FROM transactions
    WHERE Returns = TRUE
),

TotalTransactions AS (
    SELECT
        COUNT(DISTINCT InvoiceNo) AS Total_Transactions
    FROM transactions
)

SELECT
    Total_Returns,
    Total_Transactions,
    ROUND(
        (Total_Returns * 1.0 / Total_Transactions) * 100,
        2
    ) AS Return_Rate_Percentage
FROM TotalReturns
CROSS JOIN TotalTransactions;


-- =========================================================
-- 11. Which products are returned the most?
-- =========================================================

SELECT
    Description,
    COUNT(DISTINCT InvoiceNo) AS Total_Returns
FROM transactions
WHERE Returns = TRUE
GROUP BY Description
ORDER BY Total_Returns DESC
LIMIT 10;


-- =========================================================
-- 12. How much revenue is lost to returns?
-- =========================================================

SELECT
    ROUND(ABS(SUM(Revenue)), 2) AS Revenue_Lost_To_Returns
FROM transactions
WHERE Returns = TRUE;


-- =========================================================
-- 13. How many customers are repeat vs. one-time customers?
-- =========================================================

WITH CustomerOrders AS (
    SELECT
        CustomerID,
        COUNT(DISTINCT InvoiceNo) AS Order_Count
    FROM transactions
    GROUP BY CustomerID
)

SELECT
    CASE
        WHEN Order_Count > 1 THEN 'Repeat Customer'
        ELSE 'One-Time Customer'
    END AS Customer_Type,
    COUNT(CustomerID) AS Customer_Count
FROM CustomerOrders
GROUP BY Customer_Type;


-- =========================================================
-- 14. What percentage of revenue comes from repeat customers?
-- =========================================================

WITH CustomerOrders AS (
    SELECT
        CustomerID,
        COUNT(DISTINCT InvoiceNo) AS Order_Count
    FROM transactions
    GROUP BY CustomerID
),

TotalRepeatRevenue AS (
    SELECT
        SUM(transactions.Revenue) AS Repeat_Customer_Revenue
    FROM CustomerOrders
    JOIN transactions
        ON CustomerOrders.CustomerID = transactions.CustomerID
    WHERE CustomerOrders.Order_Count > 1
),

TotalRevenue AS (
    SELECT
        SUM(Revenue) AS Total_Revenue
    FROM transactions
)

SELECT
    ROUND(Repeat_Customer_Revenue, 2) AS Repeat_Customer_Revenue,
    ROUND(Total_Revenue, 2) AS Total_Revenue,
    ROUND(
        (Repeat_Customer_Revenue * 1.0 / Total_Revenue) * 100,
        2
    ) AS Repeat_Customer_Revenue_Percentage
FROM TotalRepeatRevenue
CROSS JOIN TotalRevenue;


-- =========================================================
-- 15. Customer metrics used for Pandas customer scoring
-- =========================================================

SELECT
    CustomerID,
    COUNT(DISTINCT InvoiceNo) AS Order_Count,
    ROUND(SUM(Revenue), 2) AS Total_Revenue
FROM transactions
GROUP BY CustomerID;


-- =========================================================
-- 16. Product metrics used for Pandas product scoring
-- =========================================================

-- Product sales metrics

SELECT
    Description,
    ROUND(SUM(Revenue), 2) AS Total_Revenue,
    SUM(Quantity) AS Total_Quantity
FROM transactions
WHERE Quantity > 0
GROUP BY Description;


-- Product return metrics

SELECT
    Description,
    COUNT(DISTINCT InvoiceNo) AS Total_Returns
FROM transactions
WHERE Returns = TRUE
GROUP BY Description;


-- =========================================================
-- 17. Which products are most popular among repeat customers?
-- Popularity measured by number of distinct repeat-customer orders.
-- =========================================================

WITH CustomerOrders AS (
    SELECT
        CustomerID,
        COUNT(DISTINCT InvoiceNo) AS Order_Count
    FROM transactions
    GROUP BY CustomerID
)

SELECT
    Description,
    COUNT(DISTINCT transactions.InvoiceNo) AS Repeat_Customer_Order_Count
FROM CustomerOrders
JOIN transactions
    ON CustomerOrders.CustomerID = transactions.CustomerID
WHERE CustomerOrders.Order_Count > 1
    AND transactions.Quantity > 0
GROUP BY Description
ORDER BY Repeat_Customer_Order_Count DESC
LIMIT 10;
