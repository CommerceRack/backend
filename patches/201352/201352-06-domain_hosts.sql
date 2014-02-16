
alter table DOMAIN_HOSTS change HOSTTYPE HOSTTYPE varchar(20) default '' not null;

update DOMAIN_HOSTS set HOSTTYPE='VSTORE' where HOSTTYPE='';

update DOMAIN_HOSTS set HOSTTYPE='VSTORE-APP' where HOSTTYPE='SITE';

update DOMAIN_HOSTS set HOSTTYPE='VSTORE-APP' where HOSTTYPE='SITEPTR';

update DOMAIN_HOSTS set HOSTTYPE='APPTIMIZER' where HOSTTYPE='APP';

alter table DOMAIN_HOSTS change HOSTTYPE HOSTTYPE enum ('APPTIMIZER','VSTORE','VSTORE-APP','REDIR','CUSTOM','') default '' not null;

commit;
