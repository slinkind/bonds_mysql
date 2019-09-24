/*�������� ����������*/
USE bonds;
DROP TABLE IF EXISTS securities_load;

CREATE TEMPORARY TABLE securities_load AS (

    SELECT 
    	  `������` as `name`
    	 ,`������` as `full_name`
    	,1 as `market_status`
    	,1 as `port_status`
    	,`isin`
    	,ifnull(`������`,`����.������`) as `currency`
    	,ifnull(replace(`�������`,',','.'),0) as `value`
    	,if(ifnull(`����. ������`,0)>0,365/`����. ������`,null) as  `coupon_count`
    	,'2000-01-01'as `start_date`
    	,ifnull(`���������`,'2099-01-01') as `end_date`
    	,`��� �����-��` as `type`
    	,`���` as `lot`
    	,`��� ������` as `code` 
    	,`����. ������` as `coupon_days`
    	FROM bonds._temp_load
    			 where #isin in ('RU000A0JUHY8') and 
    				   `��� �����-��` in ('���������','������ ������') and `�����` 
    				   not in ('�������������� �����'
    				 ,'����: ���-���� (���������)'
    				 ,'�� ��: ���: ��������� ��������� ����������'
    				 ,'���� ��: ���: ����� �� (���������)'
    				 ,'�������� ����'
    				 ,'����: ���-����'
    				 ,'����: ��������'
    				) and `isin` is not NULL
  );

insert into securities_load(name, full_name, market_status, port_status, code, isin, value, currency, type, start_date)
  VALUES 
    ('SUR','SUR',1,1,'SUR','SUR',1,'SUR','�������� ��������','2000-01-01')
	 ,('USD','USD',1,1,'USD','USD',1,'USD','�������� ��������','2000-01-01')
	 ,('EUR','EUR',1,1,'EUR','EUR',1,'EUR','�������� ��������','2000-01-01');

INSERT INTO securities(name, full_name, market_status, port_status, code, isin, value, currency, type, start_date)
SELECT name, full_name, market_status, port_status, code, isin, value, currency, type, start_date FROM securities_load AS t1
ON DUPLICATE KEY UPDATE
  name=t1.name
	,full_name=t1.full_name
	,market_status=t1.market_status
	,port_status=t1.port_status
	,value=t1.value
	,start_date=t1.start_date	
	,currency=t1.currency
	,type=t1.type
	,isin = t1.isin;

/*��������� ������ � ������� ���������*/
INSERT INTO bonds (security_id, coupon_count, end_date, coupon_days)
  SELECT * FROM
  (select 
  	 t2.id
  	,round(t1.coupon_count) as coupon_count
  	,STR_TO_DATE(t1.end_date,'%d.%m.%Y %k:%i:%S') as end_date
  	,t1.coupon_days
  	from securities_load t1
  	inner join Securities t2 on t2.code = t1.code
  	where t1.type = '���������') AS k1
  ON DUPLICATE KEY UPDATE 
   coupon_count = k1.coupon_count
	,end_date = k1.end_date
	,coupon_days = k1.coupon_days;

 /*��������� ������ � ������� �����*/
INSERT INTO Shares(security_id, lot)
  SELECT * FROM
	(select 
	 t2.id
	,t1.lot
  from securities_load t1
	inner join Securities t2 on t2.code = t1.code
	where t1.type = '������ ������') k1
ON DUPLICATE KEY UPDATE
  lot = k1.lot;