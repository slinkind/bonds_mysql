/*создание БД*/
DROP DATABASE IF EXISTS bonds;

CREATE DATABASE bonds
CHARACTER SET utf8mb4
COLLATE utf8mb4_general_ci;

USE bonds;

DROP TABLE IF EXISTS Securities;
DROP TABLE IF EXISTS Market_Status; #статус бумаги на рынке
DROP TABLE IF EXISTS Port_Status; #статус бумаги в портфеле
DROP TABLE IF EXISTS Shares; #таблица акций
DROP TABLE IF EXISTS Bonds; #таблица облигаций
DROP TABLE IF EXISTS Securities; #таблица ценных бумаг
DROP TABLE IF EXISTS Coupons; #таблица купонов
DROP TABLE IF EXISTS Amortization; #таблица амортизации
DROP TABLE IF EXISTS Deals; #таблица сделок
DROP TABLE IF EXISTS CB_Rate; #таблица ставок ЦБ
DROP TABLE IF EXISTS Quotes; #таблица котировок

#таблица статуса ценных бумаг на рынке
create table Market_Status(
	id int not null AUTO_INCREMENT,
	status varchar(20) not null UNIQUE,
  PRIMARY KEY (id)
);

#таблица статуса ценных бумаг в портфеле
create table Port_Status(
	id int not null AUTO_INCREMENT,
	status varchar(20) not null UNIQUE,
  PRIMARY KEY (id)
);

#таблица ценных бумаг
/*таблица ценных бумаг*/
CREATE TABLE Securities (
	`id` int NOT NULL AUTO_INCREMENT,
	`name` varchar(50) NOT NULL,
	`full_name` varchar(500) NOT NULL,
	`market_status` int NOT NULL,
	`port_status` int NOT NULL,
	`code` varchar(12) NOT NULL UNIQUE,
	`isin` varchar(12) NOT NULL UNIQUE,
	`value` numeric(30, 6) NOT NULL,
	`currency` varchar(3) NOT NULL,
	`type` varchar(20) NOT NULL,
	`start_date` date NOT NULL,
   PRIMARY KEY (id)
);

#таблица акций
create table Shares(
  id int not null AUTO_INCREMENT, 
	security_id int not NULL UNIQUE,
	lot int not NULL, #число лотов 
	PRIMARY KEY (id) 
);


#Таблица бондов 
create table Bonds(
	id int not null AUTO_INCREMENT, 
	security_id int not NULL UNIQUE,	
	coupon_count int ,	
	end_date date not null, #дата окончания обращения
	coupon_days int not NULL, #длительность купона
  PRIMARY KEY (id)
);

#Купоны Облигации
create table Coupons(
 id int not null AUTO_INCREMENT, 
 bond_id int not null,
 from_date date not null,
 coupon_date date not null,
 rate numeric(5,2) not NULL,
 PRIMARY KEY (id),
 CONSTRAINT UNIQUE(bond_id,coupon_date)
);

#Купоны Облигации
create table Amortization(
 id int not null AUTO_INCREMENT, 
 bond_id int not null,
 amortization_date date not null,
 from_date date not null,
 end_date date not null,
 percent numeric(5,2) not null,
 total_percent numeric(5,2) not NULL,
 PRIMARY KEY (id),
 CONSTRAINT UNIQUE(bond_id,amortization_date)
);


#Таблица позиций
create table Deals(
 id int not null AUTO_INCREMENT, 
 deal_id numeric(10) not NULL UNIQUE, 
 security_id int not null,	 
 deal_datetime datetime not null, 
 operation_type varchar(4) not null,
 amount int,
 price numeric(30,6),
 value numeric(30,6),
 nkd numeric(30,6),
 broker_comission numeric(30,6),
 stock_comission numeric(30,6),
 execute_date date not null,
 test bit null,
 PRIMARY KEY (id)
);

#Таблица ставок ЦБ
create table CB_Rate(
 id int not null AUTO_INCREMENT, 
 from_date date not null,
 to_date date not null,
 rate numeric(5,2) not NULL,
 PRIMARY KEY (id)
);

#таблица котировок
CREATE TABLE Quotes(
   id int NOT NULL AUTO_INCREMENT
  ,security_id int not NULL
  ,quote_date date NOT NULL
  ,price numeric(30,6)
  ,PRIMARY KEY(id)
  ,CONSTRAINT UNIQUE(security_id, quote_date)  
  )




