USE bonds;
DROP TABLE IF EXISTS coupons_load;
DROP TABLE IF EXISTS amortization_load;


/*Ставка по купонам*/
CREATE TEMPORARY TABLE coupons_load
  SELECT 
   ISIN,	
  `Дата` as coupon_date,		
  `Ставка купона,  % годовых` as rate
  FROM bonds._temp_coupons;



INSERT INTO Coupons(bond_id, from_date, coupon_date, rate)
SELECT bond_id, from_date, coupon_date, rate from
(
  select  
	t2.id as bond_id,    	
	ifnull(date_add(lag(t1.coupon_date,1) over (partition by t2.id, t1.ISIN order by t1.coupon_date),INTERVAL 1 DAY),date_add(t1.coupon_date,INTERVAL -t3.coupon_days+1 DAY)) as from_date,	
	t1.coupon_date,		
	ifnull(t1.rate,0) as rate,
   date_add(lag(t1.coupon_date,1) over (partition by t2.id, t1.ISIN order by t1.coupon_date),INTERVAL 1 DAY) as _temp_from_date
	from coupons_load t1
	inner join Securities t2 on t1.isin = t2.isin
  inner join Bonds t3 on t3.security_id = t2.id) k1
ON DUPLICATE KEY UPDATE
  bond_id = k1.bond_id,
  coupon_date = k1.coupon_date,
  from_date = k1.from_date,
  rate = k1.rate;


  /*Амортизация*/
CREATE TEMPORARY TABLE amortization_load
  SELECT 
  `ISIN`,		
  STR_TO_DATE(`Дата`,'%d.%m.%Y %k:%i:%S') as amortization_date	,
  min(convert(`Выплата (% от номинала)`,decimal(5,2))) as percent
  FROM bonds._temp_amortization
  where `Выплата (% от номинала)`!=100
  group by ISIN, STR_TO_DATE(`Дата`,'%d.%m.%Y %k:%i:%S');


INSERT INTO amortization(bond_id,amortization_date ,from_date,end_date ,percent ,total_percent)
SELECT * FROM 
 (select 
	t2.id as bond_id,
	#t1.ISIN,
	t1.amortization_date,	
	date_add(t1.amortization_date,INTERVAL 1 DAY) as from_date,
	ifnull(date_add(lead(t1.amortization_date) over(partition by t2.id  order by t2.id, t1.amortization_date),INTERVAL 0 DAY),'2099-01-01') as end_date,
  t1.percent,
	sum(t1.percent) over(partition by t2.id  order by t2.id, t1.amortization_date) as total_percent
	from amortization_load t1
	inner join Securities t2 on t1.isin = t2.isin) k1
ON DUPLICATE KEY UPDATE
   bond_id = k1.bond_id,
   amortization_date = k1.amortization_date,
   from_date = k1.from_date,
   end_date = k1.end_date,
   total_percent = k1.total_percent
