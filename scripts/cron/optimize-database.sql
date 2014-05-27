
delete from CUSTOMER_SECURE where EXPIRES<now();

delete from AMAZON_DOCUMENT_CONTENTS where CREATED_TS<date_sub(now(),interval 60 day);
alter table AMAZON_DOCUMENT_CONTENTS Engine=InnoDB Row_Format=Compressed;


delete from SYNDICATION_QUEUED_EVENTS where PROCESSED_GMT>0 and PROCESSED_GMT<unix_timestamp(date_sub(now(),interval 90 day));
optimize table SYNDICATION_QUEUED_EVENTS;

delete from BATCH_JOBS where END_TS < date_sub(now(),interval 30 day) and END_TS>0;

delete from AMAZON_DOCUMENT_CONTENTS where CREATED_TS>0 and CREATED_TS<date_sub(now(),interval 6 month);
optimize table INVENTORY_DETAIL;
optimize table PRODUCTS;

#delete from INVENTORY_OTHER where EXPIRES_GMT>0 and EXPIRES_GMT<unix_timestamp(date_sub(now(),interval 15 day));

delete from INVENTORY_LOG where FINALIZED_GMT<unix_timestamp(date_sub(now(),interval 1 year)) ;
optimize table INVENTORY_LOG;

delete from LISTING_EVENTS where PROCESSED_GMT<unix_timestamp(date_sub(now(),interval 60 day)) and PROCESSED_GMT>0;

#delete from USER_EVENTS where PROCESSED_GMT>1000 and PROCESSED_GMT<unix_timestamp(date_sub(now(),interval 15 day));
#optimize table USER_EVENTS;

#delete from AMAZON_LOG where CREATED_GMT<unix_timestamp(date_sub(now(),interval 60 day));
#delete from BUYSAFE_LOG where CREATED_GMT<unix_timestamp(date_sub(now(),interval 60 day));

delete from TODO where EXPIRES_GMT>0 and EXPIRES_GMT<unix_timestamp(now());
delete from TODO where COMPLETED_GMT>0 and COMPLETED_GMT<unix_timestamp(now());
delete from TODO where CREATED_GMT<unix_timestamp(date_sub(now(),interval 1 year));
optimize table TODO;

delete from EBAY_LISTINGS where IS_ENDED>0 and ENDS_GMT<unix_timestamp(date_sub(now(),interval 30 day)) and ENDS_GMT>0;

delete from SYNDICATION where IS_ACTIVE=0 and LASTSAVE_GMT<unix_timestamp(date_sub(now(),interval 30 day)) and LASTRUN_GMT<unix_timestamp(date_sub(now(),interval 30 day));

delete from GOOGLE_NOTIFICATIONS where PROCESSED_GMT>0 and PROCESSED_GMT<unix_timestamp(date_sub(now(),interval 90 day));

delete LOW_PRIORITY from USER_EVENTS_FUTURE where PROCESSED_GMT>0 and PROCESSED_GMT<unix_timestamp(date_sub(now(),interval 30 day));
delete LOW_PRIORITY from USER_EVENTS_FUTURE where CREATED_GMT<unix_timestamp(date_sub(now(),interval 1 year)); 

delete LOW_PRIORITY from SYNDICATION_PID_ERRORS where ARCHIVE_GMT>0 and ARCHIVE_GMT<unix_timestamp(date_sub(now(),interval 30 day));
delete LOW_PRIORITY from SYNDICATION_PID_ERRORS where CREATED_GMT<unix_timestamp(date_sub(now(),interval 1 year));

delete from STAT_LISTINGS where UPDATED_GMT<unix_timestamp(now())-(86400*60);
optimize table STAT_LISTINGS;

/* epoch 315561600: On this day in history international Decade of Water & Sanitation begins */ 
/* so we will celebrate this by cleaning up records where SYNCED_GMT is set to non-zero but they haven't been synced */
update ORDERS set SYNCED_GMT=315561600 where SYNCED_GMT=0 and MODIFIED_GMT<unix_timestamp(date_sub(now(),interval 30 day));

delete from SYNDICATION_SUMMARY where CREATED<date_sub(now(),interval 1 year);
optimize table SYNDICATION_SUMMARY;

delete from SYNDICATION_QUEUED_EVENTS where PROCESSED_GMT>0 and PROCESSED_GMT<unix_timestamp(date_sub(now(),interval 90 day));
optimize table SYNDICATION_QUEUED_EVENTS;

/* update nagios_status with a variable to let us know the last time this script ran */
replace into nagios_status (ID,NEXTRUN_TS,LASTRUN_TS) values 
	('optimized',date_add(now(),interval 18 day),now());


