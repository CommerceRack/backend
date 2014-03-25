alter table CUSTOMERS drop PASSWORD_ENCODE, add PASSHASH varchar(30) default '' not null after PASSWORD, add PASSSALT varchar(10) default '' not null after PASSHASH;

update CUSTOMERS set PASSSALT=rand()*CID;

update CUSTOMERS set PASSHASH=to_base64(unhex(sha1(concat(PASSWORD,PASSSALT))));

commit;
