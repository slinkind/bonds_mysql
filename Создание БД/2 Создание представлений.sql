USE bonds
use Bonds
DROP VIEW IF EXISTS total_pays;
DROP VIEW IF EXISTS total_coupon_pays;
DROP VIEW IF EXISTS port_on_day;
DROP VIEW IF EXISTS deals_view;
DROP VIEW IF EXISTS security_cb_rate;
DROP VIEW IF EXISTS coupon_pay;

/*Сделки*/
create view deals_view as 
SELECT 
	t1.security_id
  ,t11.isin
 	,date(t1.deal_datetime) as date
	,t1.operation_type
	,t1.price
	,t1.amount
	,case 
		when t11.type = 'Облигации' then (1-ifnull(t2.total_percent,0)/100)*t11.value*(t1.price/100)*t1.amount
		when t11.type = 'Ценные бумаги' then t12.lot*t1.price*t1.amount
		when t11.type = 'Денежные средства' then t1.price*t1.amount
	else null end  as value
 	,(t11.value*(t3.rate/(100*365))*(-datediff(t3.from_date,date(t1.deal_datetime))+1))*t1.amount*(1-ifnull(t2.total_percent,0)/100) as nkd 			  
	,t1.broker_comission
	,t1.stock_comission
 	,(1-ifnull(t2.total_percent,0)/100)*t11.value as amortization_nominal
  ,IFNULL(t12.lot,1) AS lot
			
FROM Deals t1
inner join Securities t11 on t11.id = t1.security_id
left join Shares t12 on t12.security_id = t1.security_id
left join Amortization t2 on t2.bond_id = t1.security_id and date(t1.deal_datetime) between t2.from_date and t2.end_date
left join Coupons t3 on t3.bond_id = t1.security_id and date(t1.deal_datetime) between t3.from_date and t3.coupon_date;
-- where t1.security_id = 1137
-- order by date(t1.deal_datetime)

/*Выборка всех возможных платежей*/
create view total_pays as 
select 
	 t3.security_id
	,t4.name
	,t4.isin
	,t3.date as from_date
	,ifnull(date_add(lead(t3.date,1) over(partition by t3.security_id order by t3.date),interval -1 day),'2099-01-01') as to_date 
	,t3.buy_amount 
	,t3.sell_amount
	,t3.buy_value
	,t3.sell_value
	,t3.total_amount as day_total_amount
	,t3.total_value as day_total_value
	,sum(t3.total_amount) over(partition by t3.security_id order by t3.date) as total_amount
	,sum(t3.total_value) over(partition by t3.security_id order by t3.date) as total_value
	,sum(t3.broker_comission) over(partition by t3.security_id order by t3.date) as broker_comission
	,sum(t3.stock_comission) over(partition by t3.security_id order by t3.date) as stock_comission
	,t3.broker_comission as broker_comission_on_period
	,t3.stock_comission as stock_comission_on_period
	,sum(t3.buy_nkd) over(partition by t3.security_id order by t3.date) as buy_nkd
	,sum(t3.sell_nkd) over(partition by t3.security_id order by t3.date) as sell_nkd
	,t3.buy_nkd as buy_nkd_on_period
	,t3.sell_nkd as sell_nkd_on_period
	,t3.buy_deal_profit
	,t3.sell_deal_profit
  ,IFNULL(t41.lot,1) AS lot

from
(	
	select
	 t2.security_id
	,t2.date 
	,sum(t2.buy_amount) as buy_amount 
	,sum(t2.sell_amount) as sell_amount
	,sum(t2.buy_value) as buy_value
	,sum(t2.sell_value) as sell_value
	,sum(t2.buy_amount)+sum(t2.sell_amount) as total_amount
	,sum(t2.buy_value)+sum(t2.sell_value) as total_value
	,sum(t2.broker_comission) as broker_comission
	,sum(t2.stock_comission) as stock_comission
	,sum(buy_nkd) as buy_nkd
	,sum(sell_nkd) as sell_nkd
	,sum(buy_deal_profit) as buy_deal_profit
	,sum(sell_deal_profit) as sell_deal_profit
	from
	(
		SELECT 
			   t1.security_id
			  ,t1.date
			  ,if(t1.operation_type = 'Buy', t1.amount,0) as buy_amount 
			  ,if(t1.operation_type = 'Sell',-t1.amount,0) as sell_amount 
			  ,if(t1.operation_type = 'Buy',-t1.value,0) as buy_value 
			  ,if(t1.operation_type = 'Sell',t1.value,0) as sell_value
			  ,if(t1.operation_type = 'Buy', -t1.nkd,0) as buy_nkd 
			  ,if(t1.operation_type = 'Sell', t1.nkd,0) as sell_nkd 
-- 			 -- ,case 
-- 				-- when t1.operation_type = 'Buy' then   t1.amount
-- 				-- when t1.operation_type = 'Sell' then -t1.amount
-- 				--end as operation_amount
			  ,t1.broker_comission
			  ,t1.stock_comission
			  ,if(t1.operation_type = 'Buy', amount*amortization_nominal-value,0) as buy_deal_profit
			  ,if(t1.operation_type = 'Sell', -(amount*amortization_nominal-value),0) as sell_deal_profit
       

		 FROM Bonds.Deals_View t1
	) t2 
	group by t2.security_id, t2.date
) t3
inner join Securities t4 on t4.id = t3.security_id
left join Shares t41 on t41.security_id = t4.id;

/*Выплаты по всем купонам*/
create view total_coupon_pays as 
SELECT t1.id
      ,t1.bond_id
	  ,t1.from_date
      ,t1.coupon_date  
	  ,-datediff(t1.from_date,t1.coupon_date)+1 as coupon_days
	  ,(-datediff(t1.from_date,t1.coupon_date)+1)*(1000*(t1.rate/(100*365))) as coupon_sum 	  
      ,t1.rate
	  ,if(-datediff(t1.from_date,t1.coupon_date)+1>0,(-datediff(t1.from_date,t1.coupon_date)+1)*(1000*(t1.rate/(100*365)))/(-datediff(t1.from_date,t1.coupon_date)+1),-1) as profit_per_day
FROM Bonds.Coupons t1;
-- --where bond_id = 935
-- --order by bond_id, from_date

create view security_cb_rate as 
SELECT distinct
	  t1.security_id
	 ,t2.from_date
	 ,t2.to_date
	 ,t2.rate
FROM total_pays t1
cross join CB_Rate t2 
where t2.from_date>='2018-01-01'; 

/*Срез портфеля на дату*/
create view port_on_day as
select  

 k1.security_id 
,k1.from_date
,k1.to_date
,k1.name
,k1.isin
,k1.value
,k1.buy_amount
,k1.sell_amount
,k1.buy_value
,k1.sell_value
,k1.day_total_amount
,k1.day_total_value
,k1.total_amount
,k1.total_value
,k1.last_coupon_date
,k1.coupon_rate
,k1.amortization_percent
,k1.broker_comission
,k1.stock_comission
,k1.buy_nkd
,k1.sell_nkd
,k1.profit_per_day
,k1.lot

from

(
	select  

		 k1.security_id 
		,k1.date as from_date
		,ifnull(date_add(lead(k1.date,1) over(partition by k1.security_id order by k1.date),interval -1 day),'2099-01-01') as to_date
		,k1.name
		,k1.isin
		,k1.value
		,k1.buy_amount
		,k1.sell_amount
		,k1.buy_value
		,k1.sell_value
		,k1.day_total_amount
		,k1.day_total_value
		,k1.total_amount
		,k1.total_value
		,k1.last_coupon_date
		,k1.coupon_rate
		,k1.amortization_percent
		,k1.broker_comission
		,k1.stock_comission
		,k1.buy_nkd
		,k1.sell_nkd
		,k1.profit_per_day
    ,k1.lot

	from

	(
		select 

		 m1.security_id 
		,m1.date
		,m0.name
		,m0.isin
		,m0.value
		,m2.buy_amount
		,m2.sell_amount
		,m2.buy_value
		,m2.sell_value
		,m2.day_total_amount
		,m2.day_total_value
		,m2.total_amount
		,m2.total_value
		,m3.from_date as last_coupon_date
		,m3.rate as coupon_rate
		,m4.total_percent as amortization_percent
		,m2.broker_comission
		,m2.stock_comission
		,m2.buy_nkd
		,m2.sell_nkd
		,m3.profit_per_day
    ,m2.lot

		from
		(
			select t1.security_id, t1.from_date as date from total_pays t1
			union
			select t1.security_id, date_add(t1.to_date,interval 1 day) from total_pays t1
			union
			select t1.bond_id, t1.from_date from total_coupon_pays t1
			union
			select t1.bond_id, date_add(t1.coupon_date,interval 1 day) from total_coupon_pays t1
			union
			select t1.bond_id, t1.from_date from Amortization t1
			union
			select t1.bond_id, date_add(t1.end_date,interval 1 day) from Amortization t1
	
		) m1

		inner join Securities m0 on m0.id = m1.security_id
		left join total_pays m2 on m1.security_id = m2.security_id and m1.date between m2.from_date and m2.to_date 
		left join total_coupon_pays m3 on m1.security_id = m3.bond_id and m1.date between m3.from_date and m3.coupon_date 
		left join Amortization m4 on m4.bond_id = m1.security_id and  m1.date between m4.from_date and m4.end_date 
		where m2.buy_amount is not null
-- 		--exists(SELECT 1 FROM Bonds.Deals t1 where t1.security_id = m1.security_id)
-- 		--and m0.id = 1137
		
	) k1
-- 	--order by date

) k1
where k1.to_date is not null;

create view coupon_pay as 
select  
	 k1.bond_id
	,k1.from_date
	,k1.to_date
	,k1.cb_rate
	,k1.coupon_rate
	,k1.last_coupon_date
	,k1.amort_total_percent 
	,sum(k1.coupon_pay) over (partition by k1.bond_id, k1.last_coupon_date order by k1.from_date) as coupon_pay
	,sum(k1.cb_coupon_pay) over (partition by k1.bond_id, k1.last_coupon_date order by k1.from_date) as cb_coupon_pay 
	,if(k1.cb_rate+5<k1.coupon_rate  or k1.is_ofz=0  #--если ставка по купону меньше чем ставка ЦБ+5% или облигация ОФЗ то налог не берем 
	,sum(k1.clean_coupon_pay) over (partition by k1.bond_id, k1.last_coupon_date order by k1.from_date) #--берем купон с налогом
	,sum(k1.coupon_pay) over (partition by k1.bond_id, k1.last_coupon_date order by k1.from_date) #--берем купон без налога
	)as clean_coupon_pay 		
from

(
	select 

	 k1.bond_id
	,k1.from_date
	,k1.to_date
	,k1.cb_rate
	,k1.coupon_rate
	,k1.last_coupon_date
	,k1.amort_total_percent 
	,k2.value*(coupon_rate/(100*365))*(-datediff(from_date,date(k1.to_date))+1)*((100-ifnull(amort_total_percent,0))/100) as coupon_pay
	,k2.value*((cb_rate+5)/(100*365))*(-datediff(from_date,date(k1.to_date))+1)*((100-ifnull(amort_total_percent,0))/100) as cb_coupon_pay
	,k2.value*(coupon_rate/(100*365))*(-datediff(from_date,date(k1.to_date))+1)*((100-ifnull(amort_total_percent,0))/100) 
	-
	(
	 k2.value*(coupon_rate/(100*365))*(-datediff(from_date,date(k1.to_date))+1)*((100-ifnull(amort_total_percent,0))/100) 
	-k2.value*((cb_rate+5)/(100*365))*(-datediff(from_date,date(k1.to_date))+1)*((100-ifnull(amort_total_percent,0))/100)
	)*0.35 as clean_coupon_pay
	,if(k2.name like '%ОФЗ%',1,0) as is_ofz
	from
	(
		select 
		 t1.bond_id
		,t1.from_date
		,date_add(lead(t1.from_date,1) over(partition by t1.bond_id order by t1.from_date),interval -1 day) as to_date
		,t2.rate as cb_rate
		,t3.rate as coupon_rate
		,t3.from_date as last_coupon_date
		,t4.total_percent as amort_total_percent 

		from
		(	
			select bond_id, from_date from  Coupons 
			union
			select bond_id, date_add(coupon_date,interval 1 day) from  Coupons 
			union
			select security_id, from_date from Security_CB_Rate
			union 
			select security_id, date_add(to_date,interval 1 day) from Security_CB_Rate	
			union
			select bond_id, from_date from Amortization
			union
			select bond_id, date_add(end_date,interval 1 day) from Amortization

		) t1
		left join Security_CB_Rate t2 on t1.bond_id = t2.security_id and t1.from_date between t2.from_date and t2.to_date
		left join Coupons t3 on t1.bond_id = t3.bond_id and t1.from_date between t3.from_date and t3.coupon_date
		left join Amortization t4 on t1.bond_id = t4.bond_id and t1.from_date between t4.from_date and t4.end_date		
-- 		--where t1.bond_id = 935
	) k1
	inner join Securities k2 on k1.bond_id = k2.id and k2.type='Облигации' 
) k1
where  exists(SELECT 1 FROM Bonds.Deals l1 where l1.security_id = k1.bond_id);
-- --and k1.from_date<='2099-01-01' and k1.coupon_rate is not null
