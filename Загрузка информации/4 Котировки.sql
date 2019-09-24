USE bonds;

INSERT INTO quotes(security_id, quote_date, price) 
SELECT * from
  (SELECT 
     t2.id AS security_id
    ,STR_TO_DATE(t1.`Дата посл.торг.`,'%d.%m.%Y %k:%i:%S') AS quote_date 
    ,t1.`Цена закр.` AS price
    #,t1.ISIN
    #,t1.`Код бумаги`
    #,t1.`Дата торгов`
    #,t1.`Ср. взв. цена`
     
  FROM bonds._temp_load t1
  INNER JOIN bonds.securities t2 ON t1.`Код бумаги`=t2.code 
  WHERE #t1.`Код бумаги` = 'YNDX' AND 
    `Тип инстр-та` in ('Облигации','Ценные бумаги') and `Класс` 
     not in ('Информационный класс'
   ,'РЕПО: ОТС-РЕПО (Облигации)'
   ,'МБ ФР: РПС: Облигации Первичное размещение'
   ,'ММВБ ФБ: РПС: Выкуп ЦБ (облигации)'
   ,'Неполные лоты'
   ,'РЕПО: ОТС-РЕПО'
   ,'РЕПО: СпецРЕПО'
  ) and t1.`isin` is not NULL AND t1.`Дата посл.торг.` IS NOT NULL) k1
ON DUPLICATE KEY UPDATE
  price = k1.price;
