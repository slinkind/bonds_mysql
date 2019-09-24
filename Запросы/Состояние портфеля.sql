use Bonds;
SET @on_date = '2019-09-16';

select 
  
 k1.name
,k1.isin
,sum(k1.total_amount) as total_amount
,sum(k1.total_value)+sum(k1.amortization_sum) as total_value
,if(sum(k1.total_amount)=0,sum(k1.amortization_sum)+sum(k1.nkd)+sum(k1.total_value)+sum(k1.nkd_buy)+sum(k1.nkd_sell)+sum(k1.coupon_pay)+sum(k1.bons_return_sum)+sum(k1.broker_comission)+sum(k1.stock_comission),
  SUM(k1.price)+sum(k1.amortization_sum)+sum(k1.nkd)+sum(k1.total_value)+sum(k1.nkd_buy)+sum(k1.nkd_sell)+sum(k1.coupon_pay)+sum(k1.bons_return_sum)+sum(k1.broker_comission)+sum(k1.stock_comission)) as profit 
,SUM(k1.price) AS current_price
,SUM(k1.price)+sum(k1.nkd) AS `current_price+nkd`
,sum(k1.nkd_buy) as nkd_buy 
,sum(k1.nkd_sell) as nkd_sell
,sum(k1.nkd) as nkd
,sum(k1.coupon_pay) as coupon_pay
,sum(k1.clean_coupon_pay) as clean_coupon_pay
,sum(k1.amortization_sum) as amortization_sum
,sum(k1.bons_return_sum) as bons_return_sum
,sum(k1.broker_comission) as broker_comission
,sum(k1.stock_comission) as stock_comission   

from

(
	/*Покупка и продажа ЦБ*/
	SELECT 
	 t1.security_id    
	,t1.name
	,t1.isin
	,t1.total_amount
	,t1.total_value
	,0 as nkd_buy  
	,0 as nkd_sell
	,0 as nkd
	,0 as coupon_pay
	,0 as clean_coupon_pay
	,0 as amortization_sum
	,0 as bons_return_sum
	,-t1.broker_comission as broker_comission
	,-t1.stock_comission as stock_comission 
  ,0 as price
	FROM Bonds.port_on_day t1
	where @on_date between t1.from_date and t1.to_date
  AND t1.isin!='SUR'

	union all

	/*НКД на дату покупки-продажи ЦБ*/
	select 
		 k1.security_id
		,k1.name
		,k1.isin 
		,0 as total_amount
		,0 as total_value
		,sum(k1.nkd_buy) as nkd_buy 
		,sum(k1.nkd_sell)	as nkd_sell
		,0 as nkd
		,0 as coupon_pay
		,0 as clean_coupon_pay
		,0 as amortization_sum
		,0 as bons_return_sum
		,0 as broker_comission
		,0 as stock_comission
    ,0 as price
	from
	(
		select 
			 t2.security_id    
			,t2.name
			,t2.isin
			,if(operation_type ='Buy',-t1.amount*(t2.value*(coupon_rate/(100*365))*(-datediff(last_coupon_date,date(deal_datetime))+1))*((100-ifnull(amortization_percent,0))/100),0) as nkd_buy 
			,if(operation_type ='Sell',t1.amount*(t2.value*(coupon_rate/(100*365))*(-datediff(last_coupon_date,date(deal_datetime))+1))*((100-ifnull(amortization_percent,0))/100),0) as nkd_sell	
		from Deals t1 
		inner join port_on_day t2 on t2.security_id = t1.security_id and deal_datetime between from_date and to_date
		where date(deal_datetime)<=@on_date
	) k1
	group by k1.security_id,k1.name, k1.isin

	union all
	/*Выплата купонов в ЦБ*/
	SELECT 
		 t1.security_id    
		,t1.name
		,t1.isin
		,0 as total_amount
		,0 as total_value
		,0 as nkd_buy 
		,0 as nkd_sell
		,0 as nkd
		#,t1.total_amount*(t1.value*(coupon_rate/(100*365))*(-datediff(last_coupon_date,date(coupon_date))+1))*((100-ifnull(amortization_percent,0))/100) as coupon_pay
		,t1.total_amount*t11.coupon_pay as coupon_pay
		,t1.total_amount*t11.clean_coupon_pay as clean_coupon_pay #купон с учетом налога
		,0 as amortization_sum
		,0 as bons_return_sum
		,0 as broker_comission
		,0 as stock_comission
    ,0 as price
	FROM Bonds.port_on_day t1
	inner join Coupons t2 on t2.bond_id = t1.security_id and t2.coupon_date between t1.from_date and t1.to_date 
	inner join coupon_pay t11 on t11.bond_id = t1.security_id and t2.coupon_date between t11.from_date and t11.to_date 
	where @on_date >=t2.coupon_date

	union all

	/*Выплата по амортизации*/
	select 
	 t2.security_id    
	,t2.name
	,t2.isin
	,0 as total_amount
	,0 as total_value
	,0 as nkd_buy 
	,0 as nkd_sell
	,0 as nkd
	,0 as coupon_pay
	,0 as clean_coupon_pay
	,(percent/100)*t2.value*t2.total_amount as amortization_sum
	,0 as bons_return_sum
	,0 as broker_comission
	,0 as stock_comission
  ,0 as price
	from 
	Amortization t1 
	inner join Bonds.port_on_day t2 on t1.bond_id = t2.security_id and t1.amortization_date between t2.from_date and t2.to_date 
	where @on_date >=t1.amortization_date

	union all

	/*Гашение облигаций*/
	SELECT  
		t2.security_id    
		,t2.name
		,t2.isin
		,0 as total_amount
		,0 as total_value
		,0 as nkd_buy 
		,0 as nkd_sell
		,0 as nkd
		,0 as coupon_pay
		,0 as clean_coupon_pay
		,0 as amortization_sum
		,t2.value*total_amount as bons_return_sum
		,0 as broker_comission
		,0 as stock_comission
    ,0 as price
  FROM Bonds t1
  inner join Bonds.port_on_day t2 on t1.security_id = t2.security_id and t1.end_date between t2.from_date and t2.to_date
  where @on_date >=t1.end_date

     /*НКД на текущую дату*/
 union all

 select 
	k1.security_id
	,k1.name
	,k1.isin 
	,0 as total_amount
	,0 as total_value
	,0 as nkd_buy  
	,0 as nkd_sell
	,sum(k1.nkd) as nkd 
	,0 as coupon_pay
	,0 as clean_coupon_pay
	,0 as amortization_sum
	,0 as bons_return_sum
	,0 as broker_comission
	,0 as stock_comission
  ,0 as price
	from
	(
    select 
			 t2.security_id    
			,t2.name
			,t2.isin			
			,t2.total_amount*(t2.value*(coupon_rate/(100*365))*(-datediff(last_coupon_date,date(@on_date))+1))*((100-ifnull(amortization_percent,0))/100) as nkd	
		from port_on_day t2 
		where @on_date between t2.from_date and t2.to_date

	) k1
	group by k1.security_id,k1.name, k1.isin

  UNION ALL

  /*Текущая стоимость цунных бумаг*/
  SELECT 
  t1.security_id    
  ,t2.name
  ,t2.isin
  ,0 AS total_amount
  ,0 AS total_value
  ,0 as nkd_buy  
  ,0 as nkd_sell
  ,0 as nkd
  ,0 as coupon_pay
  ,0 as clean_coupon_pay
  ,0 as amortization_sum
  ,0 as bons_return_sum
  ,0 as broker_comission
  ,0 as stock_comission 
  ,case 
  	when t3.type = 'Облигации' then (1-ifnull(t4.total_percent,0)/100)*t2.value*(t1.price/100)*t2.total_amount*t2.lot
		when t3.type = 'Ценные бумаги' then t1.price*t2.total_amount*t2.lot
		when t3.type = 'Денежные средства' then t1.price*t2.total_amount*t2.lot
	else null end  AS price

  FROM bonds.quotes t1
  INNER JOIN Bonds.port_on_day t2 ON t1.security_id = t2.security_id
  INNER JOIN Bonds.securities t3 ON t2.security_id = t3.id
  left join Amortization t4 on t4.bond_id = t1.security_id and @on_date between t4.from_date and t4.end_date
  WHERE quote_date = (SELECT MAX(quote_date) FROM quotes t1 WHERE t1.quote_date<=@on_date)
  AND @on_date between t2.from_date and t2.to_date
  and t2.isin!='SUR'

	union all
 #####################-
	/*Движение средств в денежных средствах*/
 	/*Покупка и продажа ЦБ*/
	SELECT 
	 t1.security_id    
	,'SUR' as name
	,'SUR' as isin
	,t1.total_amount
	,t1.total_value
	,0 as nkd_buy  
	,0 as nkd_sell
	,0 as nkd
	,0 as coupon_pay
	,0 as clean_coupon_pay
	,0 as amortization_sum
	,0 as bons_return_sum
	,-t1.broker_comission as broker_comission
	,-t1.stock_comission as stock_comission 
  ,0 as price
	FROM Bonds.port_on_day t1
	where @on_date between t1.from_date and t1.to_date
	and isin!='SUR'

	union all

	/*НКД на дату покупки-продажи ЦБ*/
	select 
		 k1.security_id
		 ,'SUR' as name
	     ,'SUR' as isin
		,0 as total_amount
		,0 as total_value
		,sum(k1.nkd_buy) as nkd_buy 
		,sum(k1.nkd_sell)	as nkd_sell
		,0 as nkd
		,0 as coupon_pay
		,0 as clean_coupon_pay
		,0 as amortization_sum
		,0 as bons_return_sum
		,0 as broker_comission
		,0 as stock_comission
    ,0 as price
	from
	(
		select 
			 t2.security_id    
			,t2.name
			,t2.isin
			,if(operation_type ='Buy',-t1.amount*(t2.value*(coupon_rate/(100*365))*(-datediff(last_coupon_date,date(deal_datetime))+1))*((100-ifnull(amortization_percent,0))/100),0) as nkd_buy 
			,if(operation_type ='Sell',t1.amount*(t2.value*(coupon_rate/(100*365))*(-datediff(last_coupon_date,date(deal_datetime))+1))*((100-ifnull(amortization_percent,0))/100),0) as nkd_sell	
		from Deals t1 
		inner join port_on_day t2 on t2.security_id = t1.security_id and deal_datetime between from_date and to_date
		where date(deal_datetime)<=@on_date
	) k1
	group by k1.security_id,k1.name, k1.isin

	union all
	/*Выплата купонов в ЦБ*/
	SELECT 
		 t1.security_id    
    ,'SUR' as name
    ,'SUR' as isin
		,0 as total_amount
		,0 as total_value
		,0 as nkd_buy 
		,0 as nkd_sell
		,0 as nkd
		#,t1.total_amount*(t1.value*(coupon_rate/(100*365))*(-datediff(last_coupon_date,date(coupon_date))+1))*((100-ifnull(amortization_percent,0))/100) as coupon_pay
		,t1.total_amount*t11.coupon_pay as coupon_pay
		,t1.total_amount*t11.clean_coupon_pay as clean_coupon_pay #купон с учетом налога
		,0 as amortization_sum
		,0 as bons_return_sum
		,0 as broker_comission
		,0 as stock_comission
    ,0 as price
	FROM Bonds.port_on_day t1
	inner join Coupons t2 on t2.bond_id = t1.security_id and t2.coupon_date between t1.from_date and t1.to_date 
	inner join coupon_pay t11 on t11.bond_id = t1.security_id and t2.coupon_date between t11.from_date and t11.to_date 
	where @on_date >=t2.coupon_date

	union all

	/*Выплата по амортизации*/
	select 
	 t2.security_id    
	 ,'SUR' as name
	 ,'SUR' as isin
	,0 as total_amount
	,0 as total_value
	,0 as nkd_buy 
	,0 as nkd_sell
	,0 as nkd
	,0 as coupon_pay
	,0 as clean_coupon_pay
	,(percent/100)*t2.value*t2.total_amount as amortization_sum
	,0 as bons_return_sum
	,0 as broker_comission
	,0 as stock_comission
  ,0 as price
	from 
	Amortization t1 
	inner join Bonds.port_on_day t2 on t1.bond_id = t2.security_id and t1.amortization_date between t2.from_date and t2.to_date 
	where @on_date >=t1.amortization_date

	union all

	/*Гашение облигаций*/
	SELECT  
		t2.security_id    
		 ,'SUR' as name
		 ,'SUR' as isin
		,0 as total_amount
		,0 as total_value
		,0 as nkd_buy 
		,0 as nkd_sell
		,0 as nkd
		,0 as coupon_pay
		,0 as clean_coupon_pay
		,0 as amortization_sum
		,t2.value*total_amount as bons_return_sum
		,0 as broker_comission
		,0 as stock_comission
    ,0 as price
  FROM Bonds t1
  inner join Bonds.port_on_day t2 on t1.security_id = t2.security_id and t1.end_date between t2.from_date and t2.to_date
  where @on_date >=t1.end_date
 
  UNION ALL

  /*Текущая стоимость цунных бумаг*/
  SELECT 
  t1.security_id    
  ,'SUR' as name
  ,'SUR' as isin
  ,0 AS total_amount
  ,0 AS total_value
  ,0 as nkd_buy  
  ,0 as nkd_sell
  ,0 as nkd
  ,0 as coupon_pay
  ,0 as clean_coupon_pay
  ,0 as amortization_sum
  ,0 as bons_return_sum
  ,0 as broker_comission
  ,0 as stock_comission 
  ,case 
  	when t3.type = 'Облигации' then (1-ifnull(t4.total_percent,0)/100)*t2.value*(t1.price/100)*t2.total_amount*t2.lot
		when t3.type = 'Ценные бумаги' then t1.price*t2.total_amount*t2.lot
		when t3.type = 'Денежные средства' then t1.price*t2.total_amount*t2.lot
	else null end  AS price

  FROM bonds.quotes t1
  INNER JOIN Bonds.port_on_day t2 ON t1.security_id = t2.security_id
  INNER JOIN Bonds.securities t3 ON t2.security_id = t3.id
  left join Amortization t4 on t4.bond_id = t1.security_id and @on_date between t4.from_date and t4.end_date
  WHERE quote_date = (SELECT MAX(quote_date) FROM quotes t1 WHERE t1.quote_date<=@on_date)
  AND @on_date between t2.from_date and t2.to_date
  and t2.isin!='SUR'

   /*НКД на текущую дату*/
 union all

 select 
	k1.security_id
	,'SUR' as name
  ,'SUR' as isin 
	,0 as total_amount
	,0 as total_value
	,0 as nkd_buy  
	,0 as nkd_sell
	,sum(k1.nkd) as nkd 
	,0 as coupon_pay
	,0 as clean_coupon_pay
	,0 as amortization_sum
	,0 as bons_return_sum
	,0 as broker_comission
	,0 as stock_comission
  ,0 as price
	from
	(
    select 
			 t2.security_id    
			,t2.name
			,t2.isin			
			,t2.total_amount*(t2.value*(coupon_rate/(100*365))*(-datediff(last_coupon_date,date(@on_date))+1))*((100-ifnull(amortization_percent,0))/100) as nkd	
		from port_on_day t2 
		where @on_date between t2.from_date and t2.to_date

	) k1
	group by k1.security_id,k1.name, k1.isin
 
 #####################

) k1
group by  k1.name, k1.isin;

