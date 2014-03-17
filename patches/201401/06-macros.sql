create table BLAST_MACROS (
  MID integer default 0 not null,   
  PRT tinyint default 0 not null,
  MACROID varchar(15) default '' not null,
  TITLE varchar(50) default '' not null,
  BODY text default '' not null,  
  CREATED_TS datetime default now(),
  LUSER varchar(10) default '' not null,
  unique MACCHEESE (MID,PRT,MACROID)
  ) Engine=MyISAM;


commit;

