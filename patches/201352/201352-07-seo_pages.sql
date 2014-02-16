create table SEO_PAGES (
	ID integer unsigned auto_increment,
	MID integer unsigned,
	CREATED_TS timestamp default 0 not null,
	GUID varchar(36) default '' not null,
	DOMAIN varchar(65) default '' not null,
	ESCAPED_FRAGMENT varchar(128),
	SITEMAP_SCORE tinyint unsigned default 100 not null,
	BODY mediumtext,
	primary key(ID),
	unique(MID,DOMAIN,GUID,ESCAPED_FRAGMENT)
) engine=MyISAM;

commit;
