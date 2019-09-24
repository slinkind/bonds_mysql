use Bonds
SET @isin = 'RU000A0ZZ0L6';
#declare @isin as varchar(12) = 'RU000A0JQS74'

#RU000A0JXRP9
#RU000A0ZYKG7

select 

	 k1.security_id,    
	 k1.name
	,k1.isin
	,k1.date
	,k1.days
	,k1.total_amount
	,k1.total_value	- k1.amortization_sum AS total_value
	,k1.deal_profit
	,k1.coupon_pay_sum
	,k1.amortization
	,k1.bond_return_sum
	,k1.total_nkd
	#,k1.Доходность по гашению	
	#,k1.Доходность% чистая
	,k1.`Доходность% грязная`
	#,k1.Доходность 
	,if(k1.days>0,365*100*((k1.`Доходность% грязная`/(k1.days))/(k2.value*if(k1.total_amount>0,k1.total_amount,1))),0) as `Доходность простая%`
   #,date_add(k1.date,INTERVAL if(k3.profit_per_day>0 and k1.deal_profit<0,convert(ceiling(abs(k1.deal_profit)/k3.profit_per_day),SIGNED),0) DAY) as `Дата_Окупаемости`
	,k3.profit_per_day

from
(
	 select 

	 k1.security_id    
	,k1.name
	,k1.isin
	,k1.date
	,sum(k1.days) over(partition by k1.isin order by k1.date) as days
	,sum(k1.total_amount) over(partition by k1.isin order by k1.date) as total_amount
	,abs(sum(k1.total_value) over(partition by k1.isin order by k1.date)) as total_value	
	,k1.deal_profit
	,k1.coupon_pay_sum
	,sum(k1.amortization_sum) over(partition by k1.isin order by k1.date) as amortization_sum
  ,k1.amortization_sum AS amortization
	,k1.bond_return_sum
	,k1.total_nkd
	,sum(k1.total_value) over(partition by k1.isin order by k1.date)+sum(k1.amortization_sum) over(partition by k1.isin order by k1.date)+k1.bond_return_sum as `Доходность по гашению`
	,sum(k1.coupon_pay_sum) over(partition by k1.isin order by k1.date)
	 +sum(k1.total_nkd) over(partition by k1.isin order by k1.date) 
	 +sum(k1.deal_profit) over(partition by k1.isin order by k1.date) as `Доходность% грязная`
	,sum(k1.coupon_pay_sum) over(partition by k1.isin order by k1.date)
	 +sum(k1.total_nkd) over(partition by k1.isin order by k1.date) as `Доходность% чистая`
	,sum(k1.total_value) over(partition by k1.isin order by k1.date)+sum(k1.amortization_sum) over(partition by k1.isin order by k1.date)+k1.bond_return_sum # Доходность
	+sum(k1.coupon_pay_sum) over(partition by k1.isin order by k1.date)+sum(k1.total_nkd) over(partition by k1.isin order by k1.date) #as Доходность% чистая
	as `Доходность`
	
	from

	(
		select
			 k1.security_id    
			,k1.name
			,k1.isin
			,k1.date		
			,ifnull(-datediff(lag(k1.date,1) over(partition by k1.isin order by k1.date),k1.date),0) as days
			,sum(k1.total_amount) as total_amount
			,sum(k1.total_value) as total_value		
			,sum(k1.deal_profit) as deal_profit
			,sum(k1.coupon_pay_sum) as coupon_pay_sum
			,sum(k1.amortization_sum) as amortization_sum
			,sum(k1.bond_return_sum) as bond_return_sum 
			,sum(k1.total_nkd) as total_nkd

		from
		(

			SELECT 

			t1.security_id    
			,t1.name
			,t1.isin
			,t1.day_total_amount as total_amount
			,t1.day_total_value as total_value	
			,t1.from_date as date
			,t1.buy_deal_profit+t1.sell_deal_profit as deal_profit		 
			,0 as coupon_pay
			,0 as amortization_pay
			,0 as bond_return
			,0 as coupon_pay_sum
			,0 as amortization_sum
			,0 as bond_return_sum
			,t1.buy_nkd_on_period+t1.sell_nkd_on_period as total_nkd

			FROM Bonds.total_pays t1

				union all

				/*Выплата купонов в ЦБ*/
				SELECT 
					 t1.security_id    
					,t1.name
					,t1.isin
					,0 as total_amount
					,0 as total_value		
					,t2.coupon_date as date
					,0 as deal_profit
					,1 as coupon_pay
					,0 as amortization_pay
					,0 as bond_return
					,t1.total_amount*(t1.value*(coupon_rate/(100*365))*(-datediff(last_coupon_date,date(coupon_date))+1))*((100-ifnull(amortization_percent,0))/100) as coupon_pay_sum
					,0 as amortization_sum
					,0 as bond_return_sum
					,0 as total_nkd
				FROM Bonds.port_on_day t1
				inner join Coupons t2 on t2.bond_id = t1.security_id and t2.coupon_date between t1.from_date and t1.to_date 
				where  t1.total_amount>0 #and @on_date <=t2.coupon_date and 
				#order by t2.coupon_date

				union all

				/*Выплата по амортизации*/
				select 
				 t2.security_id    
				,t2.name
				,t2.isin
				,0 as total_amount
				,0 as total_value		
				,t1.amortization_date
				,0 as deal_profit
				,0 as coupon_pay
				,1 as amortization_pay
				,0 as bond_return
				,0 as coupon_pay_sum
				,t2.total_amount*(percent/100)*t2.value as amortization_sum
				,0 as bond_return_sum
				,0 as total_nkd
	
				from 
				Amortization t1 
				inner join Bonds.port_on_day t2 on t1.bond_id = t2.security_id and t1.amortization_date between t2.from_date and t2.to_date 
				where t2.total_amount>0 #and @on_date <=t1.amortization_date 

				union all

				/*Гашение облигаций*/
				SELECT  

					t2.security_id    
					,t2.name
					,t2.isin
					,0 as total_amount
					,0 as total_value		
					,t1.end_date
					,0 as deal_profit
					,0 as coupon_pay
					,0 as amortization_pay
					,1 as bond_return
					,0 as coupon_pay_sum
					,0 as amortization_sum
					,t2.value*total_amount as bond_return_sum		
					,0 as total_nkd
			  FROM Bonds t1
			  inner join Bonds.port_on_day t2 on t1.security_id = t2.security_id and t1.end_date between t2.from_date and t2.to_date
			  where  t2.total_amount>0 #and @on_date <=t1.end_date 
			  and not exists (select 1 from Amortization l1 where l1.bond_id = t2.security_id)

		) k1
		where exists(select 1 from Bonds.Bonds l1 where k1.security_id = l1.security_id )
		and isin = @isin
		#and isin in ('RU000A0ZZ0L6')
		group by k1.security_id,k1.name,k1.isin,k1.date
		#order by k1.date, k1.isin
	) k1
) k1
inner join Securities k2 on k2.id = k1.security_id 
inner join Bonds.port_on_day k3 on k3.security_id = k1.security_id and k1.date between k3.from_date and k3.to_date
#where k1.date>=getdate()-1
#order by k1.security_id, k1.date
order by k1.date

#select * from ##111_xxx order by days
