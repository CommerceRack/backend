delete from ZUSER_LOGIN where LUSER='admin';

insert into ZUSER_LOGIN (USERNAME,MID,LUSER,PASSWORD) select USERNAME,MID,'admin',PASSWORD from ZUSERS;

alter table ZUSER_LOGIN rename LUSERS;

alter table LUSERS drop FLAG_SETUP, drop FLAG_PRODUCTS, drop FLAG_ORDERS, drop FLAG_MANAGE, drop FLAG_ZOM, drop FLAG_ZWM, drop FLAG_CRM;

alter table LUSERS add PASSHASH varchar(64) default '' not null;

alter table LUSERS add PASSSALT varchar(16) default '' not null;

update LUSERS set PASSSALT=rand()*1000*UID;

update LUSERS set PASSHASH=sha1(concat(PASSWORD,PASSSALT));

update LUSERS set ROLES='BOSS;SUPER;' where ROLES='';

update LUSERS set IS_ADMIN='Y' where LUSER='ADMIN';

commit;
