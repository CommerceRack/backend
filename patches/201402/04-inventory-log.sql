
drop table INVENTORY_LOG;

CREATE TABLE `INVENTORY_LOG` (
  `ID` bigint unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(11) NOT NULL DEFAULT '0',
  `PID` varchar(20) NOT NULL DEFAULT '',
  `SKU` varchar(35) NOT NULL DEFAULT '',
  `CMD` varchar(10) default '' not null,
  `QTY` varchar(10) default 0 not null,
  `UUID` varchar(20) default '' not null,
  `LUSER` varchar(20) NOT NULL DEFAULT '',
  `TS`	datetime default 0 not null,
  `PARAMS` text default '' not null, PRIMARY KEY (`ID`), KEY `PID` (`MID`,`PID`,`TS`)
  ) ENGINE=MyISAM AUTO_INCREMENT=0 DEFAULT CHARSET=latin1;

commit;
