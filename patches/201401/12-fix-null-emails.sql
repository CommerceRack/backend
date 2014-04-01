update SITE_EMAILS set FORMAT='HTML' where ISNULL(FORMAT)>0;

commit;

