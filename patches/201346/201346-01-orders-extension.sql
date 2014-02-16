alter table ORDERS change ORDERID ORDERID varchar(30) default '' not null;
alter table INVENTORY_DETAIL change OUR_ORDERID OUR_ORDERID varchar(30) default '' not null;
alter table AMAZON_ORDERS change OUR_ORDERID OUR_ORDERID varchar(30) default '' not null;
alter table AMAZON_ORDER_EVENTS change ORDERID ORDERID varchar(30) default '' not null;
alter table AMZPAY_ORDER_LOOKUP change ORDERID ORDERID varchar(30) default '' not null;
alter table CUSTOMER_PO_TRANSACTIONS CUSTOMER_PO_TRANSACTIONS change ORDERID ORDERID varchar(30) default '' nt null;
alter table CUSTOMER_RETURNED_ITEM CUSTOMER_PO_TRANSACTIONS change ORDERID ORDERID varchar(30) default '' nt null;
alter table EBAY_ORDERS change OUR_ORDERID OUR_ORDERID varchar(30) default '' not null;
alter table EXTERNAL_ITEMS change ZOOVY_ORDERID ZOOVY_ORDERID varchar(30) default '' not null;
alter table GIFTCARDS change LAST_ORDER LAST_ORDER varchar(30) default '' not null;
alter table ORDER_EVENTS change ORDERID ORDERID varchar(30) default '' not null;
alter table ORDER_PAYMENT_ADJUSTMENTS change ORDERID ORDERID varchar(30) default '' not null;
alter table ORDER_SHIP_NOTIFICATIONS change ORDERID ORDERID varchar(30) default '' not null;
alter table SYNDICATION_ORDERS change ZOOVY_ORDERID ZOOVY_ORDERID varchar(30) default '' not null;
alter table UPIC change ORDERID ORDERID varchar(30) default '' not null;
alter table USER_EVENTS_TRACKING change OID OID varchar(30) default '' not null;
alter table VENDOR_ORDERITEMS change OUR_ORDERID OUR_ORDERID varchar(30) default '' not null;
alter table VENDOR_ORDERS change OUR_ORDERID OUR_ORDERID varchar(30) default '' not null;

