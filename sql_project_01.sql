-- creating a new schema for this project
CREATE DATABASE sql_project_001;

-- select all records after table is imported as csv with mysql table import wizard
SELECT * FROM sql_project_001.salesdata;

-- checking data types. order_date,unit_price and unit_cost are the wrong data type
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.columns
WHERE TABLE_NAME = 'salesdata';

/*correcting order_date from a varchar to date for my analysis.
This took me a while to figure out because CAST() and CONVERT() threw an error because
they do not have arguments to specifiy your date fromat*/
SELECT str_to_date(order_date, '%d %m %Y') order_date 
FROM sql_project_001.salesdata;

-- now to the questions>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Q1 top 10 products by revenue across each zone
/* I couldn't use the alias of the window fumction in the where clause
and that is why i put the window function in a subquery*/
SELECT zone, product_name, total_revenue, row_no
FROM (SELECT zone, product_name, sum(unit_price * order_qty) AS total_revenue,
			ROW_NUMBER() over (partition by zone order by sum(unit_price * order_qty) desc) AS row_no
	  FROM sql_project_001.salesdata
	  GROUP BY zone,Product_Name) tabl
WHERE row_no <=10;

-- Q2 channels that generated the most revenue in each state
-- Used a subquery here becuase max(sum()) won't work. It throws an error every time
SELECT 
    state, channel, ROUND(max(revenue),2) revenue
FROM(SELECT state, channel, sum(unit_price * order_qty) revenue
    FROM sql_project_001.salesdata
    GROUP BY State,Channel) tabl
GROUP BY state
ORDER BY revenue desc;

-- Q3 sales made per year
SELECT YEAR(STR_TO_DATE(order_date, '%d %m %Y')) yr,
		ROUND(SUM(unit_price * order_qty),2) total_sales
FROM sql_project_001.salesdata		
GROUP BY yr
ORDER BY total_sales desc;

-- Q4 profit per year
SELECT YEAR(STR_TO_DATE(order_date, '%d %m %Y')) yr,
	(ROUND (SUM(unit_price * order_qty) - SUM(unit_cost * order_qty) , 2)) as profit 
FROM sql_project_001.salesdata
GROUP BY yr
ORDER BY profit desc;

--  Q5 profit_margin by year
SELECT YEAR(STR_TO_DATE(order_date, '%d %m %Y')) yr, SUM(unit_price * order_qty) total_sales,
	(ROUND (SUM(unit_price * order_qty) - SUM(unit_cost * order_qty) , 2)) as profit, 
    (SUM(unit_price * order_qty) - SUM(unit_cost * order_qty))/
    SUM(unit_price * order_qty) * 100 as profit_margin
FROM sql_project_001.salesdata
GROUP BY yr
ORDER BY profit_margin desc;

-- Q6 products that sold the most in each zone in each year
SELECT 
    zone, product_name, MAX(order_qty) qty, yr
FROM(SELECT zone,
            product_name,
            SUM(order_qty) order_qty,
            YEAR(STR_TO_DATE(order_date, '%d %m %Y')) yr
    FROM
        sql_project_001.salesdata
    GROUP BY zone,yr,Product_Name
    ORDER BY order_qty DESC) tabl
GROUP BY zone,yr
ORDER BY yr;

-- Q7 sales made when there is discount v no discount
-- I will use a common table expression(cte) for this
WITH 
	T1 AS
		(SELECT SUM(unit_price * order_qty) discount_sales
		FROM sql_project_001.salesdata
		WHERE promotion_name LIKE '%Promotion%'),
    
    T2 AS 
		(SELECT SUM(unit_price * order_qty) no_discount_sales
        FROM sql_project_001.salesdata
        WHERE promotion_name = 'No Discount')
        
SELECT 
    ROUND(discount_sales, 2) total_sales_with_discount,
    ROUND(no_discount_sales, 2) total_sales_without_discount
FROM
    T1,T2;
    
-- Q8 profit made when there is discount vs no discount
-- here comes the cte again
WITH 
	T1 AS 
		(SELECT (SUM(unit_price * order_qty) - SUM(unit_cost * order_qty)) profit_with_discount
        FROM sql_project_001.salesdata
        WHERE promotion_name LIKE '%Promotion%'),
        
	T2 AS 
		(SELECT (SUM(unit_price * order_qty) - SUM(unit_cost * order_qty)) profit_with_no_discount
        FROM sql_project_001.salesdata
        WHERE promotion_name = 'No Discount')
        
        SELECT ROUND(profit_with_discount, 2) profit_with_discount,
			   ROUND(profit_with_no_discount, 2) profit_with_no_discount
		FROM T1,T2;
        
-- Q9 revenue by product category
SELECT product_category, ROUND(SUM(unit_price * order_qty),2) total_revenue
FROM sql_project_001.salesdata
GROUP BY product_category
ORDER BY total_revenue desc;

-- Q10 order quantity by product category and zone
SELECT product_category, zone, sum(order_qty) order_qty
FROM sql_project_001.salesdata
GROUP BY product_category,zone
ORDER BY Order_Qty desc;

-- Q11 top product category(sales) by quarter in each year
SELECT product_category,YEAR(dt) yr, QUARTER(dt) qtr, max(total_sales) max_sales
FROM (SELECT product_category, 
	STR_TO_DATE(order_date, '%d %m %Y') dt, 
	  SUM(unit_price * order_qty) total_sales
	  FROM sql_project_001.salesdata
      GROUP BY product_category,dt) t1
GROUP BY yr, qtr
ORDER BY yr;

-- Q12 products that are never out of stock
SELECT product_name,
	   count(DISTINCT YEAR(STR_TO_DATE(order_date, '%d %m %Y'))) AS number_of_years,
	   count(DISTINCT MONTH(STR_TO_DATE(order_date, '%d %m %Y'))) AS number_of_months
FROM sql_project_001.salesdata
GROUP BY product_name
HAVING number_of_months = 12 AND number_of_years = 4
ORDER BY number_of_months, product_name;

 -- Q13 products that are out of stock sometimes      
SELECT product_name, 
	   count(DISTINCT YEAR(STR_TO_DATE(order_date, '%d %m %Y'))) AS number_of_years, 
	   count(DISTINCT MONTH(STR_TO_DATE(order_date, '%d %m %Y'))) AS number_of_months
FROM sql_project_001.salesdata
GROUP BY product_name
HAVING number_of_months < 12 OR number_of_years < 4
ORDER BY number_of_months, product_name;

-- Q14 profit margins by category
SELECT product_category, 
		ROUND(((total_revenue-total_cost)/total_revenue)*100,2) AS profit_margin,
		CASE 
			WHEN ROUND(((total_revenue-total_cost)/total_revenue)*100,2) >= 60 THEN 'High'
			WHEN ROUND(((total_revenue-total_cost)/total_revenue)*100,2) >= 50 THEN 'Mid'
			ELSE 'Low' 
			END AS profit_level
FROM (SELECT product_category, 
		SUM(unit_price* order_qty) total_revenue, 
		SUM(unit_cost * order_qty) total_cost
        FROM sql_project_001.salesdata
        GROUP BY product_category) tabl
ORDER BY profit_margin DESC;
