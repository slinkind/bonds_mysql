/*Загрузка ставки ЦБ*/
USE bonds;

truncate table bonds.CB_Rate;
insert into CB_Rate(from_date, to_date, rate)
	SELECT 
	  STR_TO_DATE(`Дата начала`,'%Y-%m-%d %k:%i:%S'),	
	  STR_TO_DATE(ifnull(`Дата конца`,'01.01.2019'),'%d.%m.%Y %k:%i:%S'), 	
	 `% годовых`
	FROM bonds._temp_cb_rate;



DROP TABLE IF EXISTS deals_load;
CREATE TEMPORARY TABLE deals_load 
SELECT 
	 `Дата и время заключения сделки` as `deal_datetime`,
	 `Код бумаги` as `security_code`,
	 `Номер сделки`	as `deal_id`,   
	 case 
		  when `Направление` = 'Купля' then 'Buy'
		  when `Направление` = 'Продажа' then 'Sell'
		  else null
	  end as `operation_type`,
	 `Кол-во ЦБ` as amount,
	 `Цена` as price,
	 `Объём` as value,
	 `НКД` as nkd,
	 `Комиссия Брокера` as `broker_comission`,
	 `Суммарная комиссия ТС` as `stock_comission`,
	 `Дата расчётов` as `execute_date`
	
	FROM bonds._temp_deals

  union all
	/*Данные по пополнению/снятию денежных средств*/
	SELECT 
	deal_datetime,
	security_code,
	deal_id,   
	operation_type,
	amount,
	price,
	value,
	nkd,
	broker_comission,
	stock_comission,
	execute_date  
  
FROM 
(
  select STR_TO_DATE('2019-01-10','%Y-%m-%d') AS deal_datetime,'SUR' AS security_code,1 AS deal_id,'Sell' AS operation_type,5000 AS amount,1 AS price,5000 AS value,0 AS nkd,0 AS broker_comission,0 AS stock_comission,STR_TO_DATE('2019-01-07','%Y-%m-%d') AS execute_date  UNION ALL
	 select STR_TO_DATE('2019-01-17','%Y-%m-%d'),'SUR',2,'Sell',50020,1,50000,0,0,0,STR_TO_DATE('2019-01-18','%Y-%m-%d') UNION ALL
	 select STR_TO_DATE('2019-02-05','%Y-%m-%d'),'SUR',3,'Sell',10000,1,10000,0,0,0,STR_TO_DATE('2019-01-18','%Y-%m-%d') UNION ALL
	 select STR_TO_DATE('2019-05-30','%Y-%m-%d'),'SUR',4,'Sell',100000,1,100000,0,0,0,STR_TO_DATE('2019-05-30','%Y-%m-%d') UNION ALL
	 select STR_TO_DATE('2019-05-30','%Y-%m-%d'),'SUR',5,'Sell',150000,1,100000,0,0,0,STR_TO_DATE('2019-06-03','%Y-%m-%d') 
) r;


INSERT INTO deals(deal_id, security_id, deal_datetime, operation_type, amount, price, value, nkd, broker_comission, stock_comission, execute_date)
  SELECT * from
  (select 
     t1.deal_id 
		,t2.id as security_id
		,t1.deal_datetime
		,t1.operation_type
		,t1.amount
		,t1.price
		,t1.value
		,t1.nkd
		,t1.broker_comission
		,t1.stock_comission
		,t1.execute_date
	from deals_load t1
	inner join Securities t2 on t1.security_code= t2.code) k1
ON DUPLICATE KEY UPDATE
  deal_datetime=k1.deal_datetime
  ,operation_type=k1.operation_type
  ,amount=k1.amount
  ,price=k1.price
  ,value=k1.value
  ,nkd=k1.nkd
  ,broker_comission=k1.broker_comission
  ,stock_comission=k1.stock_comission
  ,execute_date=k1.execute_date;