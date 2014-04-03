
alter table LUSERS add PASSPIN varchar(10) default '' not null;

update LUSERS set PASSPIN=PASSWORD;

commit;

