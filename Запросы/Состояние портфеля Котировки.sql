SET @on_date = '2019-07-31';
SELECT MAX(quote_date) FROM bonds.quotes WHERE quote_date>=@on_date;

SELECT 
  security_id
  ,quote_date
  ,price 
  
FROM bonds.quotes 
 WHERE (SELECT MAX(date) FROM bonds.quotes WHERE date>=@on_date)
