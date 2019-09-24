USE bonds;

INSERT INTO quotes(security_id, quote_date, price) 
SELECT * from
  (SELECT 
     t2.id AS security_id
    ,STR_TO_DATE(t1.`���� ����.����.`,'%d.%m.%Y %k:%i:%S') AS quote_date 
    ,t1.`���� ����.` AS price
    #,t1.ISIN
    #,t1.`��� ������`
    #,t1.`���� ������`
    #,t1.`��. ���. ����`
     
  FROM bonds._temp_load t1
  INNER JOIN bonds.securities t2 ON t1.`��� ������`=t2.code 
  WHERE #t1.`��� ������` = 'YNDX' AND 
    `��� �����-��` in ('���������','������ ������') and `�����` 
     not in ('�������������� �����'
   ,'����: ���-���� (���������)'
   ,'�� ��: ���: ��������� ��������� ����������'
   ,'���� ��: ���: ����� �� (���������)'
   ,'�������� ����'
   ,'����: ���-����'
   ,'����: ��������'
  ) and t1.`isin` is not NULL AND t1.`���� ����.����.` IS NOT NULL) k1
ON DUPLICATE KEY UPDATE
  price = k1.price;
