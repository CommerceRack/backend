delete from PATCH_HISTORY where PATCH_ID like '%patchhistory%';

alter table PATCH_HISTORY change PATCH_ID PATCH_ID varchar(64) default '' not null;

commit;
