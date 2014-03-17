alter table SITE_EMAILS add CREATED_TS timestamp after CREATED_GMT;

alter table SITE_EMAILS add MODIFIED_TS timestamp after CREATED_TS;

update SITE_EMAILS set CREATED_TS = unix_timestamp(CREATED_GMT);

update SITE_EMAILS set MODIFIED_TS = unix_timestamp(CREATED_TS);

alter table SITE_EMAILS drop CREATED_GMT;

alter table SITE_EMAILS change MSGSUBJECT SUBJECT varchar(60) default '' not null;

alter table SITE_EMAILS change MSGFORMAT FORMAT enum('HTML','WIKI','TEXT','XML','HTML5','DONOTSEND');

delete from SITE_EMAILS where MSGTYPE='INCOMPLETE';

alter table SITE_EMAILS change MSGTYPE OBJECT enum('ORDER','ACCOUNT','PRODUCT','SUPPLY','TICKET','') ;

alter table SITE_EMAILS change MSGBODY BODY mediumtext default '' not null;

alter table SITE_EMAILS add METAJSON text default '' not null;

update SITE_EMAILS set METAJSON=concat("{\"email_from\":\"",MSGFROM,"\",\"email_bcc\":\"",MSGBCC,"\"}");

commit;
