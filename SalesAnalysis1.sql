USE PortfolioDB;

--Inspecting data
SELECT * FROM [dbo].[sales_data_sample]

--Checking unique values
SELECT DISTINCT STATUS FROM [dbo].[sales_data_sample] --NICE TO PLOT(6 UNIQUE)
SELECT DISTINCT YEAR_ID FROM [dbo].[sales_data_sample] --2003,2004,2005
SELECT DISTINCT PRODUCTLINE FROM [dbo].[sales_data_sample] --7 UNIQUE
SELECT DISTINCT COUNTRY FROM [dbo].[sales_data_sample] --NICE TO PLOT(19 UNIQUE)
SELECT DISTINCT DEALSIZE FROM [dbo].[sales_data_sample] --NICE TO PLOT(3 UNIQUE)
SELECT DISTINCT TERRITORY FROM [dbo].[sales_data_sample] --NICE TO PLOT(4 UNIQUE)

--ANALYSIS
--Let's start by grouping sales by 'PRODUCTLINE'
SELECT PRODUCTLINE, SUM(SALES) REVENUE FROM [dbo].[sales_data_sample]
GROUP BY PRODUCTLINE
ORDER BY 2 DESC;

--Let's start by grouping sales by 'YEAR_ID'
SELECT YEAR_ID, SUM(SALES) REVENUE FROM [dbo].[sales_data_sample]
GROUP BY YEAR_ID
ORDER BY 2 DESC;

--For 2005 our revenue is too low, we  need to check that.
SELECT DISTINCT MONTH_ID FROM [dbo].[sales_data_sample]
WHERE YEAR_ID = '2005';
--We have data 5 months for 2005, so the revenue for 2005 is too low
--Let's check for 2003 and 2004's datas
SELECT DISTINCT MONTH_ID FROM [dbo].[sales_data_sample]
WHERE YEAR_ID = '2004';
SELECT DISTINCT MONTH_ID FROM [dbo].[sales_data_sample]
WHERE YEAR_ID = '2003';
--Both seems normal

--Let's start by grouping sales by 'DEALSIZE'
SELECT DEALSIZE, SUM(SALES) REVENUE FROM [dbo].[sales_data_sample]
GROUP BY DEALSIZE
ORDER BY 2 DESC;
--Medium deals bring in the most revenue

--What was the best month in terms of total sales in the 3-years data?
SELECT YEAR_ID, MONTH_ID, SUM(SALES) REVENUE, COUNT(ORDERNUMBER) FREQUENCY FROM [dbo].[sales_data_sample]
GROUP BY YEAR_ID, MONTH_ID
ORDER BY 3 DESC;

--What was the best month for sales in a specific year? How much was earned that month?
SELECT MONTH_ID, SUM(SALES) REVENUE, COUNT(ORDERNUMBER) FREQUENCY FROM [dbo].[sales_data_sample]
WHERE YEAR_ID = 2003 --change the year to see other year's data(2004 and 2005)
GROUP BY MONTH_ID
ORDER BY 2 DESC;

--November seems to the best month, what product do they sell in November?
--In 2003 and 2004 November was the best month.
SELECT MONTH_ID, PRODUCTLINE, SUM(SALES) REVENUE, COUNT(ORDERNUMBER) FREQUENCY FROM [dbo].[sales_data_sample]
WHERE YEAR_ID = 2003 AND MONTH_ID = 11 --change the year to see other year's data(2004 and 2005)
GROUP BY MONTH_ID, PRODUCTLINE
ORDER BY 3 DESC;

--Review of 2 years of November total data(No November data in 2005)
SELECT MONTH_ID, PRODUCTLINE, SUM(SALES) REVENUE, COUNT(ORDERNUMBER) FREQUENCY FROM [dbo].[sales_data_sample]
WHERE MONTH_ID = 11
GROUP BY MONTH_ID, PRODUCTLINE
ORDER BY 3 DESC;


--Who s the best customer?(This could be answered with RFM analysis)
DROP TABLE IF EXISTS #RFM
;WITH RFM AS(
	SELECT CUSTOMERNAME, 
		SUM(SALES) MONETARY, 
		AVG(SALES) AVGMONETARY, 
		COUNT(ORDERNUMBER) FREQUENCY, 
		MAX(ORDERDATE) LAST_ORDER_DATE_CUST,
	  (SELECT MAX(ORDERDATE) FROM [dbo].[sales_data_sample]) MAX_ORDER_DATE_GENERAL,
	  DATEDIFF(DD, MAX(ORDERDATE), (SELECT MAX(ORDERDATE) FROM [dbo].[sales_data_sample])) RECENCY
	  FROM [dbo].[sales_data_sample]
	GROUP BY CUSTOMERNAME
),
rfm_calc as(
SELECT *, 
NTILE(4) OVER (ORDER BY RECENCY DESC) rfm_recency,
NTILE(4) OVER (ORDER BY FREQUENCY) rfm_frequency,
NTILE(4) OVER (ORDER BY MONETARY) rfm_monetary
FROM RFM
)
SELECT *, 
rfm_recency+rfm_frequency+rfm_monetary RFM,
CAST(rfm_recency AS VARCHAR)+CAST(rfm_frequency AS VARCHAR)+CAST(rfm_monetary AS VARCHAR) RFM_String
INTO #RFM
FROM rfm_calc
-- Alos we can use to concat (rfm_recency, rfm_frequency, rfm_monetary) these values using by concat function
--CONCAT(rfm_recency, rfm_frequency, rfm_monetary)

SELECT CUSTOMERNAME, rfm_recency, rfm_frequency, rfm_monetary,
	CASE
		WHEN RFM_String  IN (111, 112, 121, 122, 123, 132, 211, 212, 114, 141) THEN 'lost_customer' --lost customer
		WHEN RFM_String  IN (133, 134, 143, 144, 244, 334, 343, 344) THEN 'sleeping away, connot lose' --(big spenders who haven't purchased lately) sleepin away
		WHEN RFM_String  IN (311, 411, 412) THEN 'new customer'
		WHEN RFM_String  IN (221, 222, 223, 232, 233, 234, 322) THEN 'potential churners'
		WHEN RFM_String  IN (321, 322, 323, 331, 332, 333, 343, 421, 422, 423, 432) THEN 'active'
		WHEN RFM_String  IN (433, 434, 443, 444) THEN 'loyal'
	END RFM_SEGMENT
FROM #RFM

--What products are most often sold together?

SELECT DISTINCT ORDERNUMBER, STUFF(
(SELECT ','+ PRODUCTCODE FROM [dbo].[sales_data_sample] P
WHERE ORDERNUMBER IN (
SELECT ORDERNUMBER 
FROM (SELECT ORDERNUMBER, COUNT(*) RN FROM [dbo].[sales_data_sample]
	WHERE STATUS = 'Shipped'
	GROUP BY ORDERNUMBER) S
WHERE RN = 3) --'RN=n' shows how many products sold together.
AND P.ORDERNUMBER = F.ORDERNUMBER
FOR XML PATH ('')), 1, 1,'') ProductCodes
FROM [dbo].[sales_data_sample] F
ORDER BY 2 DESC;
--Using this code we can analyise wihch orders have exactly the same products.