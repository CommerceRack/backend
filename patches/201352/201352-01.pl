
alter table CAMPAIGNS 
	add STATUS enum('NEW','WAITING','SENDING','FINISHED') default 'NEW',
	add STARTTIME timestamp,
	add JOBID integer default 0 not null;




