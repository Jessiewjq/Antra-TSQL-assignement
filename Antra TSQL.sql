-- 1. List of Persons’ full name, all their fax and phone numbers, as well as the phone number and fax of the company they are working for (if any).
SELECT Fullname, p.PhoneNumber, p.FaxNumber, c.PhoneNumber, c.FaxNumber 
FROM Application.People p
JOIN Sales.Customers c
On p.PersonID=c.PrimaryContactPersonID Or p.PersonID= c.AlternateContactPersonID



-- 2. If the customer's primary contact person has the same phone number as the customer’s phone number, list the customer companies.
SELECT c.CustomerName, c.PhoneNumber AS CustomerPhoneNumber, p.PhoneNumber AS PrimaryContact
FROM Sales.Customers c
JOIN Application.People p 
ON c.PrimaryContactPersonID = p.PersonID
WHERE c.PhoneNumber = p.PhoneNumber


-- 3. List of customers to whom we made a sale prior to 2016 but no sale since 2016-01-01
SELECT distinct c.CustomerID,c.CustomerName
FROM Sales.Orders o
JOIN Sales.Customers c
ON o.CustomerID=c.CustomerID
WHERE o.OrderDate<'2016-01-01'

--4. List of Stock Items and total quantity for each stock item in Purchase Orders in Year 2013.
WITH cte as(
SELECT s.StockItemID,s.StockItemName,p.SupplierID, s.QuantityPerOuter
FROM Warehouse.StockItems s
RIGHT JOIN Purchasing.PurchaseOrders p
ON s.SupplierID=p.SupplierID
WHERE year(p.OrderDate)=2013)
SELECT StockItemID,StockItemName,COUNT(StockItemID)*QuantityPerOuter as total_quantity
FROM cte
GROUP BY StockItemID,StockItemName,QuantityPerOuter

--5. List of stock items that have at least 10 characters in description.
SELECT StockItemID,StockItemName
FROM(
SELECT StockItemID,StockItemName, SUBSTRING(SearchDetails,CHARINDEX('-',SearchDetails)+1,LEN(SearchDetails)) as string, len(SUBSTRING(SearchDetails,CHARINDEX('-',SearchDetails)+1,LEN(SearchDetails))) as length
FROM Warehouse.StockItems) a
WHERE length>=10

--6. List of stock items that are not sold to the state of Alabama and Georgia in 2014.
WITH cte AS(
SELECT o.OrderID, o.OrderDate,sp.StateProvinceName
FROM Sales.Orders o
JOIN Sales.Customers c
ON o.CustomerID=c.CustomerID
JOIN Application.Cities ac
ON c.DeliveryCityID = ac.CityID
JOIN Application.StateProvinces sp
ON ac.StateProvinceID = sp.StateProvinceID
WHERE year(o.OrderDate)=2014 AND sp.StateProvinceName != 'Alabama' AND sp.StateProvinceName != 'Georgia')
SELECT distinct ol.StockItemID
FROM cte
LEFT JOIN Sales.OrderLines ol
ON cte.OrderID=ol.OrderID

--7. List of States and Avg dates for processing (confirmed delivery date – order date).
With cte AS(
SELECT o.OrderDate, CONVERT(date, i.ConfirmedDeliveryTime) as ConfirmedDeliveryTime, sp.StateProvinceName, DATEDIFF(day,o.OrderDate, CONVERT(date, i.ConfirmedDeliveryTime)) as diff
FROM Sales.Orders o
JOIN Sales.Customers c
ON o.CustomerID=c.CustomerID
JOIN Application.Cities ac
ON c.DeliveryCityID = ac.CityID
JOIN Application.StateProvinces sp
ON ac.StateProvinceID = sp.StateProvinceID
JOIN Sales.Invoices i
ON o.OrderID = i.OrderID)
SELECT StateProvinceName, AVG(diff) as avgdates
FROM cte
GROUP BY StateProvinceName;

--8. List of States and Avg dates for processing (confirmed delivery date – order date) by month.
With cte AS(
SELECT o.OrderDate, CONVERT(date, i.ConfirmedDeliveryTime) as ConfirmedDeliveryTime, CONCAT(year(OrderDate),'-',month(OrderDate)) as orderdatenew, sp.StateProvinceName, DATEDIFF(day,o.OrderDate, CONVERT(date, i.ConfirmedDeliveryTime)) as diff
FROM Sales.Orders o
JOIN Sales.Customers c
ON o.CustomerID=c.CustomerID
JOIN Application.Cities ac
ON c.DeliveryCityID = ac.CityID
JOIN Application.StateProvinces sp
ON ac.StateProvinceID = sp.StateProvinceID
JOIN Sales.Invoices i
ON o.OrderID = i.OrderID)
SELECT distinct StateProvinceName, orderdatenew, AVG(diff)over(Partition by StateProvinceName, orderdatenew)
FROM cte
order by 1,2

--9. List of StockItems that the company purchased more than sold in the year of 2015.
SELECT pol.StockItemID
FROM Purchasing.PurchaseOrderLines pol
JOIN Sales.OrderLines sol
ON pol.StockItemID=sol.StockItemID
WHERE year(pol.LastReceiptDate)=2015
GROUP BY pol.StockItemID
HAVING sum(pol.OrderedOuters)>sum(sol.Quantity)


--10. List of Customers and their phone number, together with the primary contact person’s name, to whom we did not sell more than 10 mugs (search by name) in the year 2016.
WITH cte AS(
SELECT c.CustomerName,c.PhoneNumber,c.PrimaryContactPersonID,p.FullName,ol.Quantity,si.StockItemName,o.OrderDate
FROM Sales.orders o
JOIN Sales.OrderLines ol
ON o.OrderID=ol.OrderID
JOIN Warehouse.StockItems si
ON si.StockItemID=ol.StockItemID
JOIN sales.Customers c
ON o.CustomerID=c.CustomerID
JOIN Application.People p
ON c.PrimaryContactPersonID=p.PersonID
WHERE year(o.OrderDate)=2016 AND si.StockItemName LIKE '%mug%')
SELECT CustomerName, PhoneNumber, FullName as PrimaryContactName, sum(Quantity) as sum
FROM cte
GROUP BY CustomerName, PhoneNumber, FullName
HAVING sum(Quantity)<10

-- 11. List all the cities that were updated after 2015-01-01.
SELECT *
FROM Application.Cities
WHERE ValidFrom>'2015-01-01'


-- 12. List all the Order Detail (Stock Item name, delivery address, delivery state, city, country, customer name, customer contact person name, customer phone, quantity) for the date of 2014-07-01. Info should be relevant to that date.
SELECT si.StockItemName, CONCAT(c.DeliveryAddressLine1,' ',c.DeliveryAddressLine2) as DeliveryAddress, 
sp.StateProvinceName as state, ci.CityName as city, co.CountryName as country, c.CustomerName, p.FullName as ContactName,
c.PhoneNumber as CustomerPhone, ol.Quantity
FROM Sales.orders o
JOIN Sales.OrderLines ol
ON o.OrderID=ol.OrderID
JOIN Warehouse.StockItems si
ON si.StockItemID=ol.StockItemID
JOIN Sales.Customers c
ON o.CustomerID=c.CustomerID
JOIN Application.Cities ci
ON c.DeliveryCityID=ci.CityID
JOIN Application.StateProvinces sp
ON ci.StateProvinceID=sp.StateProvinceID
JOIN Application.Countries co
ON sp.CountryID=co.CountryID
JOIN Application.People p
ON c.PrimaryContactPersonID=p.PersonID
WHERE o.OrderDate='2014-07-01'


-- 13. List of stock item groups and total quantity purchased, total quantity sold, and the remaining stock quantity (quantity purchased – quantity sold)
WITH cte1 AS(
SELECT sg.StockGroupName, sum(pol.OrderedOuters) as TotalQuantityPurchased
FROM Warehouse.StockItems si
JOIN Warehouse.StockItemStockGroups sisg
ON si.StockItemID=sisg.StockItemID
JOIN Warehouse.StockGroups sg
ON sisg.StockGroupID=sg.StockGroupID
JOIN Purchasing.PurchaseOrderLines pol
ON si.StockItemID=pol.StockItemID
GROUP BY sg.StockGroupName),
cte2 AS(
SELECT sg.StockGroupName, sum(sol.Quantity) as TotalQuantitySold
FROM Warehouse.StockItems si
JOIN Warehouse.StockItemStockGroups sisg
ON si.StockItemID=sisg.StockItemID
JOIN Warehouse.StockGroups sg
ON sisg.StockGroupID=sg.StockGroupID
JOIN Sales.OrderLines sol
ON si.StockItemID=sol.StockItemID
GROUP BY sg.StockGroupName)
SELECT cte1.StockGroupName,cte1.TotalQuantityPurchased,cte2.TotalQuantitySold, (cte1.TotalQuantityPurchased-cte2.TotalQuantitySold) as RemainingStockQuantity
FROM cte1
JOIN cte2
ON cte1.StockGroupName=cte2.StockGroupName


-- 14. List of Cities in the US and the stock item that the city got the most deliveries in 2016. If the city did not purchase any stock items in 2016, print “No Sales”.
WITH cte as(
SELECT ci.CityName, si.StockItemName, sum(il.Quantity) as quantity
FROM Application.Cities ci
LEFT JOIN Sales.Customers cu
ON ci.CityID=cu.DeliveryCityID
JOIN Sales.Invoices i
ON cu.CustomerID=i.CustomerID
JOIN Warehouse.StockItemTransactions sit
ON i.InvoiceID=sit.InvoiceID
JOIN Warehouse.StockItems si
ON sit.StockItemID=si.StockItemID
JOIN sales.Orders o
ON cu.CustomerID=o.CustomerID
JOIN sales.InvoiceLines il
ON i.InvoiceID=il.InvoiceID
WHERE year(o.OrderDate)=2016
GROUP BY CityName, StockItemName),
cte2 as(
SELECT CityName, StockItemName
FROM(
SELECT CityName, StockItemName, quantity, rank()over(partition by cityname order by quantity DESC) as rnk
FROM cte) a
WHERE rnk=1)
SELECT distinct c.CityName, CASE WHEN StockItemName IS NULL THEN 'No Sales' ELSE StockItemName END as mostdelivereditem
FROM cte2
RIGHT JOIN Application.Cities c
ON c.CityName=cte2.CityName
order by 1

-- 15. List any orders that had more than one delivery attempt (located in invoice table).
SELECT OrderID
FROM sales.Invoices
WHERE JSON_VALUE(ReturnedDeliveryData,'$.Events[1].Comment') IS NOT NULL

-- 16. List all stock items that are manufactured in China. (Country of Manufacture) (NO China??)
SELECT StockItemID,StockItemName
FROM Warehouse.StockItems
WHERE CustomFields LIKE '%China%'

-- 17. Total quantity of stock items sold in 2015, group by country of manufacturing.
With cte AS(
SELECT StockItemID, SUBSTRING(ab,CHARINDEX(':',ab)+3,LEN(ab)) as manufacture
FROM(
SELECT StockItemID, left(CustomFields, charindex(',', CustomFields) -2) ab 
FROM Warehouse.StockItems) a)
SELECT manufacture, SUM(ol.Quantity) as quantity
FROM cte
JOIN sales.OrderLines ol
ON cte.StockItemID=ol.StockItemID
JOIN Sales.Orders o
ON ol.OrderID=o.OrderID
WHERE year(o.OrderDate)=2015
GROUP BY manufacture

-- 18. Create a view that shows the total quantity of stock items of each stock group sold (in orders) by year 2013-2017. [Stock Group Name, 2013, 2014, 2015, 2016, 2017]
GO
CREATE VIEW question18
AS
WITH cte AS(
SELECT sg.StockGroupName,sum(ol.Quantity) as quantity,year(o.OrderDate) as year
FROM Sales.OrderLines ol
JOIN Warehouse.StockItems si
ON ol.StockItemID=si.StockItemID
JOIN Warehouse.StockItemStockGroups sisg
ON si.StockItemID=sisg.StockItemID
JOIN Warehouse.StockGroups sg
ON sisg.StockGroupID=sg.StockGroupID
JOIN sales.Orders o
ON ol.OrderID=o.OrderID
GROUP BY sg.StockGroupName, year(o.OrderDate))

SELECT StockGroupName as stockgroupname, [2013],[2014],[2015],[2016],[2017]
FROM
(
    SELECT StockGroupName,quantity,year
    FROM cte
) AS Sourcetable
PIVOT
(
    sum(quantity) 
    FOR year IN ([2013],[2014],[2015],[2016],[2017])
) AS PivotTable;

-- 19. Create a view that shows the total quantity of stock items of each stock group sold (in orders) by year 2013-2017. [Year, Stock Group Name1, Stock Group Name2, Stock Group Name3, ... , Stock Group Name10]
GO
CREATE VIEW question19
AS
WITH cte AS(
SELECT sg.StockGroupName,sum(ol.Quantity) as quantity,year(o.OrderDate) as year
FROM Sales.OrderLines ol
JOIN Warehouse.StockItems si
ON ol.StockItemID=si.StockItemID
JOIN Warehouse.StockItemStockGroups sisg
ON si.StockItemID=sisg.StockItemID
JOIN Warehouse.StockGroups sg
ON sisg.StockGroupID=sg.StockGroupID
JOIN sales.Orders o
ON ol.OrderID=o.OrderID
GROUP BY sg.StockGroupName, year(o.OrderDate))

SELECT year as year, [Airline Novelties],[Clothing],[Computing Novelties],[Furry Footwear],[Mugs],[Novelty Items],[Packaging Materals],[Toys],[T-Shirts],[USB Novelties]
FROM
(
    SELECT StockGroupName,quantity,year
    FROM cte
) AS Sourcetable
PIVOT
(
    sum(quantity) 
    FOR stockgroupname IN ([Airline Novelties],[Clothing],[Computing Novelties],[Furry Footwear],[Mugs],[Novelty Items],[Packaging Materals],[Toys],[T-Shirts],[USB Novelties])
) AS PivotTable;
GO

-- 20. Create a function, input: order id; return: total of that order. List invoices and use that function to attach the order total to the other fields of invoices.
DROP FUNCTION IF EXISTS Question20;
GO
CREATE FUNCTION Question20 (@orderid int)
RETURNS TABLE
AS
RETURN
(
    SELECT il.Quantity*il.UnitPrice+il.TaxAmount+il.ExtendedPrice as total
    FROM Sales.Orders o
    JOIN sales.Invoices i
    ON o.OrderID=i.OrderID
    JOIN Sales.InvoiceLines il
    ON i.InvoiceID=il.InvoiceID
    WHERE o.OrderID=@orderid
);
GO
SELECT *
FROM Question20(1)

-- 21.Create a new table called ods.Orders. Create a stored procedure, with proper error handling and transactions, that input is a date; when executed, it would find orders of that day, calculate order total, and save the information (order id, order date, order total, customer id) into the new table. If a given date is already existing in the new table, throw an error and roll back. Execute the stored procedure 5 times using different dates.









-- 22. Create a new table called ods.StockItem. It has following columns: [StockItemID], [StockItemName] ,[SupplierID] ,[ColorID] ,[UnitPackageID] ,[OuterPackageID] ,[Brand] ,[S ize] ,[LeadTimeDays] ,[QuantityPerOuter] ,[IsChillerStock] ,[Barcode] ,[TaxRate] ,[UnitPri ce],[RecommendedRetailPrice] ,[TypicalWeightPerUnit] ,[MarketingComments] ,[Intern alComments], [CountryOfManufacture], [Range], [Shelflife]. Migrate all the data in the original stock item table.
DROP TABLE IF EXISTS ods.Orders;
CREATE schema ods
GO
SELECT [StockItemID], [StockItemName] ,[SupplierID] ,[ColorID] ,[UnitPackageID] ,[OuterPackageID] ,[Brand] ,[Size] ,[LeadTimeDays] ,[QuantityPerOuter] ,[IsChillerStock] ,[Barcode] ,[TaxRate] ,[UnitPrice],[RecommendedRetailPrice] ,[TypicalWeightPerUnit] ,[MarketingComments] ,[InternalComments], JSON_VALUE(CustomFields, '$.CountryOfManufacture') AS CountryOfManufacture,JSON_VALUE(CustomFields,'$.Range') AS Range, JSON_VALUE(CustomFields,'$.ShelfLife') AS ShelfLife
INTO ods.StockItem
FROM Warehouse.StockItems;
SELECT *
FROM ods.StockItem

-- 23. Rewrite your stored procedure in (21). Now with a given date, it should wipe out all the order data prior to the input date and load the order data that was placed in the next 7 days following the input date.





-- 24. 






--25. Revisit your answer in (19). Convert the result in JSON string and save it to the server using TSQL FOR JSON PATH.
SELECT *
FROM dbo.question19
FOR JSON AUTO

-- 26. Revisit your answer in (19). Convert the result into an XML string and save it to the server using TSQL FOR XML PATH.
SELECT *
FROM dbo.question19
FOR XML AUTO,ELEMENTS;

--27. Create a new table called ods.ConfirmedDeviveryJson with 3 columns (id, date, value) . Create a stored procedure, input is a date. The logic would load invoice information (all columns) as well as invoice line information (all columns) and forge them into a JSON string and then insert into the new table just created. Then write a query to run the stored procedure for each DATE that customer id 1 got something delivered to him.





-- 28.  Write a short essay talking about your understanding of transactions, locks and isolation levels.
-- Transaction is the logical work unit that performs one or more activities, it is like SQL's save or undo button. 
-- It needs to follow 4 principles: Atomicity, Consistency, Isolation, and Durability.
-- Also, transaction can have two outcomes which are committed and rolled back. The committed means it got saved permanently and rolled back means it can be rolled back to the beginning of the transaction or a savepoint in the transaction.
-- There are different types of transactions such as autocommit transaction, implicit transaction, explicit transaction, and batch-scoped transaction.

-- Locks object in Microsoft SQL Server provides information about SQL Server locks on individual resource types. 
-- Locks are held on SQL Server resources, such as rows read or modified during a transaction, to prevent concurrent use of resources by different transactions. For example, if an exclusive (X) lock is held on a row within a table by a transaction, no other transaction can modify that row until the lock is released. Minimizing locks increases concurrency, which can improve performance. Multiple instances of the Locks object can be monitored at the same time, with each instance representing a lock on a resource type.

-- 









-- 29. Write a short essay, plus screenshots talking about performance tuning in SQL Server. Must include Tuning Advisor, Extended Events, DMV, Logs and Execution Plan.





