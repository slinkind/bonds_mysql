SET @isin = 'RU000A0JVF64';
SET @amount  = 1;
SET @price  = 100.55;
SET @deal_datetime = cast('2019-03-16 00:00:00' AS datetime);


# delete from Bonds.Deals where test = 1

insert into Bonds.Deals(deal_id,security_id,deal_datetime,operation_type,amount,price,execute_date,test)
select 
 id as deal_id
,id as security_id
,@deal_datetime as deal_datetime
,'Buy' as operation_type
,@amount as amount
,@price as price
,@deal_datetime as execute_date
,1
from Securities where isin = @isin