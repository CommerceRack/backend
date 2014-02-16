create table WHOLESALE_SCHEDULES (
	ID integer unsigned auto_increment,
	MID integer unsigned default 0 not null,
   CODE varchar(3) default '' not null,
	CREATED_TS timestamp,
   JSON mediumtext default '' not null,
   primary key(ID),
	unique(MID,CODE)
	) engine=MyISAM;

commit;
