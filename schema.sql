-- MySQL dump 10.13  Distrib 5.6.20, for Linux (x86_64)
--
-- Host: localhost    Database: CAMPUSCOLORS
-- ------------------------------------------------------
-- Server version	5.6.20

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `AMAZON_DOCS`
--

DROP TABLE IF EXISTS `AMAZON_DOCS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `AMAZON_DOCS` (
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `PRT` smallint(5) unsigned NOT NULL DEFAULT '0',
  `DOCTYPE` varchar(40) NOT NULL DEFAULT '',
  `DOCID` bigint(20) unsigned NOT NULL DEFAULT '0',
  `DOCBODY` mediumtext NOT NULL,
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `RETRIEVED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `RESPONSE_DOCID` bigint(20) unsigned NOT NULL DEFAULT '0',
  `RESPONSE_BODY` mediumtext,
  `RESENT_DOCID` bigint(20) unsigned DEFAULT NULL,
  `ATTEMPTS` tinyint(4) NOT NULL DEFAULT '0',
  UNIQUE KEY `DOCID` (`DOCID`),
  KEY `MID` (`MID`,`RETRIEVED_GMT`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `AMAZON_DOCUMENT_CONTENTS`
--

DROP TABLE IF EXISTS `AMAZON_DOCUMENT_CONTENTS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `AMAZON_DOCUMENT_CONTENTS` (
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `DOCID` bigint(20) NOT NULL DEFAULT '0',
  `MSGID` int(11) NOT NULL DEFAULT '0',
  `FEED` enum('init','products','prices','images','inventory','relations','shipping','deleted') DEFAULT NULL,
  `SKU` varchar(35) NOT NULL DEFAULT '',
  `CREATED_TS` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `DEBUG` tinytext,
  `ACK_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  UNIQUE KEY `MID` (`MID`,`DOCID`,`MSGID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 ROW_FORMAT=COMPRESSED;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `AMAZON_ORDERS`
--

DROP TABLE IF EXISTS `AMAZON_ORDERS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `AMAZON_ORDERS` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `MID` int(11) NOT NULL DEFAULT '0',
  `PRT` smallint(5) unsigned NOT NULL DEFAULT '0',
  `DOCID` bigint(20) DEFAULT NULL,
  `AMAZON_ORDERID` varchar(20) NOT NULL DEFAULT '',
  `OUR_ORDERID` varchar(30) NOT NULL DEFAULT '',
  `CREATED_GMT` int(11) NOT NULL DEFAULT '0',
  `ACK_GMT` int(11) NOT NULL DEFAULT '0',
  `TRACK_GMT` int(11) DEFAULT '0',
  `HAS_TRACKING` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `ORDER_TOTAL` decimal(10,2) DEFAULT NULL,
  `DIRTY` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `POSTED_GMT` int(11) NOT NULL DEFAULT '0',
  `SHIPPING_METHOD` enum('Standard','Expedited','Scheduled','NextDay','SecondDay','Unknown') DEFAULT 'Unknown',
  `NEWORDER_ACK_PROCESSED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `NEWORDER_ACK_DOCID` bigint(20) unsigned NOT NULL DEFAULT '0',
  `FULFILLMENT_ACK_REQUESTED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `FULFILLMENT_ACK_PROCESSED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `FULFILLMENT_ACK_DOCID` bigint(20) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `AMZ_ORDERID` (`AMAZON_ORDERID`),
  KEY `MID_PRT_DOCID` (`MID`,`PRT`,`DOCID`),
  KEY `NEWORDER_ACK_PROCESSED_GMT` (`NEWORDER_ACK_PROCESSED_GMT`),
  KEY `FULFILLMENT_ACK_PROCESSED_GMT` (`FULFILLMENT_ACK_PROCESSED_GMT`,`FULFILLMENT_ACK_REQUESTED_GMT`),
  KEY `MID` (`MID`,`PRT`,`OUR_ORDERID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `AMAZON_ORDER_EVENTS`
--

DROP TABLE IF EXISTS `AMAZON_ORDER_EVENTS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `AMAZON_ORDER_EVENTS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `CREATED` datetime DEFAULT NULL,
  `TYPE` enum('ORDER-ACK','FULFILL-ACK','') NOT NULL DEFAULT '',
  `ORDERID` varchar(30) NOT NULL DEFAULT '',
  `DATA` tinytext,
  `LOCK_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `PROCESSED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `PROCESSED_DOCID` int(10) unsigned NOT NULL DEFAULT '0',
  `ATTEMPTS` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  KEY `LOCK_GMT` (`LOCK_GMT`),
  KEY `PROCESSED_GMT` (`PROCESSED_GMT`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `AMAZON_OVERRIDES`
--

DROP TABLE IF EXISTS `AMAZON_OVERRIDES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `AMAZON_OVERRIDES` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `PRT` smallint(5) unsigned NOT NULL DEFAULT '0',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `UPDATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `PID` varchar(50) NOT NULL DEFAULT '',
  `SERVICE_LEVEL` enum('Standard','Expedited','Second','Schedule','NextDay','SecondDay','') NOT NULL DEFAULT '',
  `LOCALE` enum('ContinentalUS','AlaskaAndHawaii','USProtectorates','InternationalCanada','InternationalEurope','InternationalAsia','InternationalOther') DEFAULT NULL,
  `DONOTSHIP` smallint(1) unsigned NOT NULL DEFAULT '0',
  `TYPE` enum('Additive','Exclusive') DEFAULT NULL,
  `SHIP_AMOUNT` decimal(10,2) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`PRT`,`PID`,`LOCALE`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `AMAZON_REPORTS`
--

DROP TABLE IF EXISTS `AMAZON_REPORTS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `AMAZON_REPORTS` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `MID` int(11) NOT NULL DEFAULT '0',
  `PRT` smallint(5) unsigned NOT NULL DEFAULT '0',
  `TYPE` varchar(50) NOT NULL DEFAULT 'Settlement',
  `DOCID` bigint(20) DEFAULT NULL,
  `REPORTID` int(11) DEFAULT NULL,
  `START_DATE` int(11) NOT NULL DEFAULT '0',
  `END_DATE` int(11) NOT NULL DEFAULT '0',
  `CREATED_GMT` int(11) NOT NULL DEFAULT '0',
  `ACK_GMT` int(11) NOT NULL DEFAULT '0',
  `ROWS` int(11) DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `DOCID` (`MID`,`DOCID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `AMAZON_THESAURUS`
--

DROP TABLE IF EXISTS `AMAZON_THESAURUS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `AMAZON_THESAURUS` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `GUID` varchar(36) NOT NULL DEFAULT '',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(11) NOT NULL DEFAULT '0',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `NAME` varchar(20) NOT NULL DEFAULT '',
  `ITEMTYPE` varchar(100) DEFAULT NULL,
  `USEDFOR` varchar(255) NOT NULL DEFAULT '',
  `SUBJECTCONTENT` varchar(255) NOT NULL DEFAULT '',
  `OTHERITEM` varchar(255) NOT NULL DEFAULT '',
  `TARGETAUDIENCE` varchar(255) NOT NULL DEFAULT '',
  `ADDITIONALATTRIBS` varchar(255) NOT NULL DEFAULT '',
  `SEARCH_TERMS_1` varchar(100) DEFAULT NULL,
  `SEARCH_TERMS_2` varchar(100) DEFAULT NULL,
  `SEARCH_TERMS_3` varchar(100) DEFAULT NULL,
  `SEARCH_TERMS_4` varchar(100) DEFAULT NULL,
  `SEARCH_TERMS_5` varchar(100) DEFAULT NULL,
  `ISGIFTWRAPAVAILABLE` int(11) NOT NULL DEFAULT '0',
  `ISGIFTMESSAGEAVAILABLE` int(11) NOT NULL DEFAULT '0',
  `SEARCH_TERMS` varchar(250) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`NAME`),
  UNIQUE KEY `MIDGUID` (`MID`,`GUID`),
  UNIQUE KEY `MIDNAME` (`MID`,`NAME`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `AMZPAY_ORDER_LOOKUP`
--

DROP TABLE IF EXISTS `AMZPAY_ORDER_LOOKUP`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `AMZPAY_ORDER_LOOKUP` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(11) NOT NULL DEFAULT '0',
  `PRT` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `CREATED` datetime DEFAULT NULL,
  `CARTID` varchar(30) NOT NULL DEFAULT '',
  `ORDERID` varchar(30) NOT NULL DEFAULT '',
  `AMZ_PAYID` varchar(24) NOT NULL DEFAULT '',
  `AMZ_REQID` varchar(60) NOT NULL DEFAULT '',
  `CART` mediumtext NOT NULL,
  `PROCESSED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`CARTID`),
  UNIQUE KEY `MID_2` (`MID`,`AMZ_PAYID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `AMZREPRICE_PROFILES`
--

DROP TABLE IF EXISTS `AMZREPRICE_PROFILES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `AMZREPRICE_PROFILES` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `CODE` varchar(8) NOT NULL DEFAULT '',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `MODIFIED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `DATA` mediumtext NOT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`CODE`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `BATCH_JOBS`
--

DROP TABLE IF EXISTS `BATCH_JOBS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `BATCH_JOBS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `LUSERNAME` varchar(10) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `PRT` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `GUID` varchar(36) NOT NULL DEFAULT '',
  `JOB_TYPE` varchar(3) NOT NULL DEFAULT '',
  `VERSION` decimal(6,0) NOT NULL DEFAULT '0',
  `BATCH_EXEC` varchar(45) NOT NULL DEFAULT '',
  `PARAMETERS_UUID` varchar(36) NOT NULL DEFAULT '',
  `BATCH_VARS` mediumtext NOT NULL,
  `CREATED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `QUEUED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `START_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `ESTDONE_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `END_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `ARCHIVED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `ABORTED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `TITLE` varchar(65) NOT NULL DEFAULT '',
  `STATUS` enum('NEW','HOLD','QUEUED','RUNNING','ABORTING','END','END-ABORT','END-SUCCESS','END-WARNINGS','END-ERRORS','END-CRASHED') DEFAULT NULL,
  `STATUS_MSG` varchar(100) NOT NULL DEFAULT '',
  `RECORDS_DONE` int(10) unsigned NOT NULL DEFAULT '0',
  `RECORDS_TOTAL` int(10) unsigned NOT NULL DEFAULT '0',
  `RECORDS_WARN` int(10) unsigned NOT NULL DEFAULT '0',
  `RECORDS_ERROR` int(10) unsigned NOT NULL DEFAULT '0',
  `HAS_SLOG` tinyint(4) NOT NULL DEFAULT '0',
  `OUTPUT_FILE` varchar(50) NOT NULL DEFAULT '',
  `IS_RUNNING` int(10) unsigned NOT NULL DEFAULT '0',
  `IS_CRASHED` int(10) unsigned NOT NULL DEFAULT '0',
  `IS_ABORTABLE` int(10) unsigned NOT NULL DEFAULT '0',
  `JOB_COST_CYCLES` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `UN_UG` (`USERNAME`,`GUID`),
  KEY `IN_MBF` (`MID`,`BATCH_EXEC`,`END_TS`),
  KEY `IN_CS` (`CREATED_TS`,`STATUS`)
) ENGINE=MyISAM AUTO_INCREMENT=1746 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `BATCH_PARAMETERS`
--

DROP TABLE IF EXISTS `BATCH_PARAMETERS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `BATCH_PARAMETERS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `UUID` varchar(36) NOT NULL DEFAULT '',
  `MID` int(11) NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `LUSER` varchar(10) NOT NULL DEFAULT '',
  `TITLE` varchar(80) DEFAULT NULL,
  `CREATED_TS` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `CREATED_BY` varchar(10) NOT NULL DEFAULT '',
  `LASTRUN_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `LASTJOB_ID` int(10) unsigned NOT NULL DEFAULT '0',
  `BATCH_EXEC` varchar(45) NOT NULL DEFAULT '',
  `APIVERSION` int(10) unsigned NOT NULL DEFAULT '0',
  `YAML` text NOT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `IN_MIDUUID` (`MID`,`UUID`),
  KEY `IN_MIDLUSER` (`MID`,`LUSER`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `BLAST_MACROS`
--

DROP TABLE IF EXISTS `BLAST_MACROS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `BLAST_MACROS` (
  `MID` int(11) NOT NULL DEFAULT '0',
  `PRT` tinyint(4) NOT NULL DEFAULT '0',
  `MACROID` varchar(15) NOT NULL DEFAULT '',
  `TITLE` varchar(50) NOT NULL DEFAULT '',
  `BODY` text NOT NULL,
  `CREATED_TS` datetime DEFAULT CURRENT_TIMESTAMP,
  `LUSER` varchar(10) NOT NULL DEFAULT '',
  UNIQUE KEY `MACCHEESE` (`MID`,`PRT`,`MACROID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `BUYCOM_DBMAPS`
--

DROP TABLE IF EXISTS `BUYCOM_DBMAPS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `BUYCOM_DBMAPS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `MAPID` varchar(10) NOT NULL DEFAULT '',
  `STOREID` int(11) NOT NULL DEFAULT '0',
  `CATID` varchar(6) NOT NULL DEFAULT '',
  `MAPTXT` text NOT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`MAPID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `BUYCOM_FILES_PROCESSED`
--

DROP TABLE IF EXISTS `BUYCOM_FILES_PROCESSED`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `BUYCOM_FILES_PROCESSED` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `FILENAME` varchar(50) NOT NULL DEFAULT '',
  `CREATED` datetime DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`FILENAME`),
  KEY `CREATED` (`CREATED`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `CAMPAIGNS`
--

DROP TABLE IF EXISTS `CAMPAIGNS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CAMPAIGNS` (
  `CAMPAIGNID` varchar(20) NOT NULL DEFAULT '',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `SUBJECT` varchar(70) NOT NULL DEFAULT '',
  `PRT` tinyint(4) NOT NULL DEFAULT '0',
  `CREATED_TS` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `TEMPLATE_ORIGIN` varchar(36) NOT NULL DEFAULT '',
  `RECIPIENTS` text,
  `SEND_EMAIL` tinyint(4) NOT NULL DEFAULT '0',
  `SEND_APPLEIOS` tinyint(4) NOT NULL DEFAULT '0',
  `SEND_ANDROID` tinyint(4) NOT NULL DEFAULT '0',
  `SEND_FACEBOOK` tinyint(4) NOT NULL DEFAULT '0',
  `SEND_TWITTER` tinyint(4) NOT NULL DEFAULT '0',
  `SEND_SMS` tinyint(4) NOT NULL DEFAULT '0',
  `QUEUE_MODE` enum('FRONT','BACK','SINGLE') DEFAULT 'FRONT',
  `EXPIRES` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `COUPON` varchar(10) NOT NULL DEFAULT '',
  `RSS_DATA` tinytext NOT NULL,
  `STATUS` enum('NEW','WAITING','SENDING','FINISHED') DEFAULT 'NEW',
  `STARTTIME` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `JOBID` int(11) NOT NULL DEFAULT '0',
  UNIQUE KEY `MID` (`MID`,`CAMPAIGNID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `CAMPAIGN_RECIPIENTS`
--

DROP TABLE IF EXISTS `CAMPAIGN_RECIPIENTS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CAMPAIGN_RECIPIENTS` (
  `ID` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `CID` bigint(20) unsigned NOT NULL DEFAULT '0',
  `CPG` int(11) NOT NULL DEFAULT '0',
  `CREATED_GMT` int(11) NOT NULL DEFAULT '0',
  `SENT_GMT` int(11) NOT NULL DEFAULT '0',
  `OPENED` tinyint(4) NOT NULL DEFAULT '0',
  `CLICKED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `OPENED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `UNSUBSCRIBED` tinyint(4) NOT NULL DEFAULT '0',
  `BOUNCED` tinyint(4) NOT NULL DEFAULT '0',
  `LOCKED_GMT` int(11) NOT NULL DEFAULT '0',
  `LOCKED_PID` int(11) NOT NULL DEFAULT '0',
  `CLICKED` int(11) NOT NULL DEFAULT '0',
  `PURCHASED` int(11) NOT NULL DEFAULT '0',
  `TOTAL_SALES` int(11) NOT NULL DEFAULT '0',
  `PURCHASED_GMT` int(10) unsigned DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `CPG` (`CPG`,`CID`,`MID`),
  KEY `CREATED_GMT` (`CREATED_GMT`,`SENT_GMT`),
  KEY `LOCKED_PID` (`LOCKED_PID`,`LOCKED_GMT`),
  KEY `LOCKED_GMT` (`LOCKED_GMT`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `CHECKOUTS`
--

DROP TABLE IF EXISTS `CHECKOUTS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CHECKOUTS` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `SDOMAIN` varchar(50) NOT NULL DEFAULT '',
  `ASSIST` enum('NONE','CALL','CHAT','') NOT NULL DEFAULT '',
  `CARTID` varchar(36) NOT NULL DEFAULT '',
  `CID` int(10) unsigned NOT NULL DEFAULT '0',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `HANDLED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `CLOSED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `ASSISTID` varchar(5) NOT NULL DEFAULT '',
  `CHECKOUT_STAGE` varchar(8) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  KEY `MID` (`MID`,`SDOMAIN`,`HANDLED_GMT`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `CHECKUP`
--

DROP TABLE IF EXISTS `CHECKUP`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CHECKUP` (
  `ID` int(11) NOT NULL DEFAULT '0',
  `TIMESTAMP` int(11) NOT NULL DEFAULT '0'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `CIENGINE_AGENTS`
--

DROP TABLE IF EXISTS `CIENGINE_AGENTS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CIENGINE_AGENTS` (
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `GUID` varchar(36) NOT NULL DEFAULT '',
  `CREATED_TS` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UPDATED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `AGENTID` varchar(20) NOT NULL DEFAULT '',
  `SCRIPT` text NOT NULL,
  `REVISION` int(10) unsigned NOT NULL DEFAULT '0',
  `INTERFACE` decimal(6,0) NOT NULL DEFAULT '0',
  `LINE_COUNT` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`MID`,`AGENTID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `CRM_SETUP`
--

DROP TABLE IF EXISTS `CRM_SETUP`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CRM_SETUP` (
  `MID` int(11) NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `PRT` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `EMAIL_ADDRESS` varchar(65) NOT NULL DEFAULT '',
  `EMAIL_PASS` varchar(15) NOT NULL DEFAULT '',
  `EMAIL_LASTPOLL_GMT` int(11) NOT NULL DEFAULT '0',
  `TICKET_COUNT` int(11) NOT NULL DEFAULT '0',
  `TICKET_SEQ` enum('ALPHA','SEQ5','DATEYYMM4') NOT NULL DEFAULT 'ALPHA',
  `TICKET_LAST_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `TICKET_LOCK_PID` varchar(10) NOT NULL DEFAULT '',
  `EMAIL_CLEANUP` tinyint(4) NOT NULL DEFAULT '0',
  UNIQUE KEY `MID` (`MID`,`PRT`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `CURRENCIES`
--

DROP TABLE IF EXISTS `CURRENCIES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CURRENCIES` (
  `CURRENCY` varchar(3) NOT NULL DEFAULT '',
  `RATE` decimal(10,5) NOT NULL DEFAULT '0.00000',
  `UPDATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  UNIQUE KEY `CURRENCY` (`CURRENCY`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `CUSTOMER`
--

DROP TABLE IF EXISTS `CUSTOMER`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CUSTOMER` (
  `CID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `ORGID` int(10) unsigned NOT NULL DEFAULT '0',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `PRT` smallint(4) unsigned NOT NULL DEFAULT '0',
  `EMAIL` varchar(65) NOT NULL DEFAULT '',
  `PASSWORD_ENCODE` varchar(20) DEFAULT '',
  `PASSWORD` varchar(36) NOT NULL DEFAULT '',
  `FIRSTNAME` varchar(50) CHARACTER SET utf8 NOT NULL DEFAULT '',
  `LASTNAME` varchar(50) CHARACTER SET utf8 NOT NULL DEFAULT '',
  `PHONE` varchar(10) CHARACTER SET ascii NOT NULL DEFAULT '',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `MODIFIED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `LASTLOGIN_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `LASTORDER_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `ORDER_COUNT` smallint(5) unsigned NOT NULL DEFAULT '0',
  `NEWSLETTER` int(11) unsigned DEFAULT '1',
  `OPTIN_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `HINT_NUM` tinyint(4) NOT NULL DEFAULT '0',
  `HINT_ANSWER` varchar(10) CHARACTER SET utf8 NOT NULL DEFAULT '',
  `HINT_ATTEMPTS` tinyint(4) NOT NULL DEFAULT '0',
  `IP` int(10) unsigned NOT NULL DEFAULT '0',
  `ORIGIN` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `SCHEDULE` varchar(4) CHARACTER SET utf8 NOT NULL DEFAULT '',
  `HAS_NOTES` tinyint(4) NOT NULL DEFAULT '0',
  `REWARD_BALANCE` int(10) unsigned DEFAULT NULL,
  `IS_AFFILIATE` smallint(6) NOT NULL DEFAULT '0',
  `IS_LOCKED` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`CID`),
  UNIQUE KEY `CID` (`MID`,`CID`),
  UNIQUE KEY `MID` (`MID`,`PRT`,`EMAIL`),
  KEY `MID_2` (`MID`,`MODIFIED_GMT`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `CUSTOMERS`
--

DROP TABLE IF EXISTS `CUSTOMERS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CUSTOMERS` (
  `CID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `ORGID` int(10) unsigned NOT NULL DEFAULT '0',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `PRT` smallint(4) unsigned NOT NULL DEFAULT '0',
  `EMAIL` varchar(65) NOT NULL DEFAULT '',
  `PASSWORD` varchar(36) NOT NULL DEFAULT '',
  `PASSHASH` varchar(30) NOT NULL DEFAULT '',
  `PASSSALT` varchar(10) NOT NULL DEFAULT '',
  `FIRSTNAME` varchar(50) CHARACTER SET utf8 NOT NULL DEFAULT '',
  `LASTNAME` varchar(50) CHARACTER SET utf8 NOT NULL DEFAULT '',
  `PHONE` varchar(10) CHARACTER SET ascii NOT NULL DEFAULT '',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `MODIFIED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `LASTLOGIN_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `LASTORDER_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `ORDER_COUNT` smallint(5) unsigned NOT NULL DEFAULT '0',
  `NEWSLETTER` int(11) unsigned DEFAULT '1',
  `OPTIN_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `HINT_NUM` tinyint(4) NOT NULL DEFAULT '0',
  `HINT_ANSWER` varchar(10) CHARACTER SET utf8 NOT NULL DEFAULT '',
  `HINT_ATTEMPTS` tinyint(4) NOT NULL DEFAULT '0',
  `IP` int(10) unsigned NOT NULL DEFAULT '0',
  `ORIGIN` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `SCHEDULE` varchar(4) CHARACTER SET utf8 NOT NULL DEFAULT '',
  `HAS_NOTES` tinyint(4) NOT NULL DEFAULT '0',
  `REWARD_BALANCE` int(10) unsigned DEFAULT NULL,
  `IS_AFFILIATE` smallint(6) NOT NULL DEFAULT '0',
  `IS_LOCKED` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`CID`),
  UNIQUE KEY `CID` (`MID`,`CID`),
  UNIQUE KEY `MID` (`MID`,`PRT`,`EMAIL`),
  KEY `MID_2` (`MID`,`MODIFIED_GMT`)
) ENGINE=MyISAM AUTO_INCREMENT=198 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `CUSTOMERS_AUTHENTICATOR`
--

DROP TABLE IF EXISTS `CUSTOMERS_AUTHENTICATOR`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CUSTOMERS_AUTHENTICATOR` (
  `ID` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(11) NOT NULL DEFAULT '0',
  `PRT` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `SRC` enum('PHONE','FACEBOOK','ORDER') DEFAULT NULL,
  `CID` bigint(20) NOT NULL DEFAULT '0',
  `AUTHKEY` varchar(20) NOT NULL DEFAULT '',
  `EXPIRES` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `UN1` (`MID`,`PRT`,`CID`,`SRC`),
  UNIQUE KEY `UN2` (`MID`,`PRT`,`SRC`,`AUTHKEY`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `CUSTOMER_ADDR`
--

DROP TABLE IF EXISTS `CUSTOMER_ADDR`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CUSTOMER_ADDR` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(11) NOT NULL DEFAULT '0',
  `TYPE` enum('SHIP','BILL','META','WS','NOTE','') NOT NULL DEFAULT '',
  `PARENT` int(11) NOT NULL DEFAULT '0',
  `CODE` varchar(10) NOT NULL DEFAULT '',
  `INFO` mediumtext,
  `IS_DEFAULT` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `PARENT` (`PARENT`,`MID`,`TYPE`,`CODE`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `CUSTOMER_ADDRS`
--

DROP TABLE IF EXISTS `CUSTOMER_ADDRS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CUSTOMER_ADDRS` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(11) NOT NULL DEFAULT '0',
  `TYPE` enum('SHIP','BILL','META','WS','NOTE','') NOT NULL DEFAULT '',
  `PARENT` int(11) NOT NULL DEFAULT '0',
  `CODE` varchar(10) NOT NULL DEFAULT '',
  `INFO` mediumtext,
  `IS_DEFAULT` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `PARENT` (`PARENT`,`MID`,`TYPE`,`CODE`)
) ENGINE=MyISAM AUTO_INCREMENT=173 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `CUSTOMER_COUNTER`
--

DROP TABLE IF EXISTS `CUSTOMER_COUNTER`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CUSTOMER_COUNTER` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `MERCHANT` varchar(20) DEFAULT '',
  PRIMARY KEY (`ID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `CUSTOMER_LISTS`
--

DROP TABLE IF EXISTS `CUSTOMER_LISTS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CUSTOMER_LISTS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `CID` int(10) unsigned NOT NULL DEFAULT '0',
  `LISTID` varchar(15) NOT NULL DEFAULT '',
  `SKU` varchar(35) NOT NULL DEFAULT '',
  `QTY` int(10) unsigned NOT NULL DEFAULT '0',
  `MODIFIED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `NOTE` tinytext,
  `PRIORITY` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`CID`,`LISTID`,`SKU`)
) ENGINE=MyISAM AUTO_INCREMENT=16 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `CUSTOMER_NOTES`
--

DROP TABLE IF EXISTS `CUSTOMER_NOTES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CUSTOMER_NOTES` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `CID` int(10) unsigned NOT NULL DEFAULT '0',
  `MERCHANT` varchar(20) NOT NULL DEFAULT '',
  `LUSER` varchar(20) NOT NULL DEFAULT '',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `NOTE` varchar(80) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  KEY `MID` (`MID`,`CID`),
  KEY `CREATED_GMT` (`CREATED_GMT`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `CUSTOMER_PO_TRANSACTIONS`
--

DROP TABLE IF EXISTS `CUSTOMER_PO_TRANSACTIONS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CUSTOMER_PO_TRANSACTIONS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `CID` int(10) unsigned NOT NULL DEFAULT '0',
  `CREATED_GMT` int(11) NOT NULL DEFAULT '0',
  `CREATED_BY` varchar(10) NOT NULL DEFAULT '',
  `ENTRY_TYPE` enum('SUMMARY','DEBIT','ADJUST','PAYMENT') DEFAULT NULL,
  `ENTRY_NOTE` varchar(80) NOT NULL DEFAULT '',
  `ORDERID` varchar(30) NOT NULL DEFAULT '',
  `PAYMENT_UUID` varchar(24) NOT NULL DEFAULT '',
  `PO_NUMBER` varchar(20) NOT NULL DEFAULT '',
  `AMOUNT` decimal(10,2) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`CID`,`CREATED_GMT`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `CUSTOMER_RETURNED_ITEM`
--

DROP TABLE IF EXISTS `CUSTOMER_RETURNED_ITEM`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CUSTOMER_RETURNED_ITEM` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `PRT` tinyint(4) NOT NULL DEFAULT '0',
  `CID` int(10) unsigned NOT NULL DEFAULT '0',
  `TKTCODE` varchar(12) NOT NULL DEFAULT '',
  `ORDERID` varchar(30) NOT NULL DEFAULT '',
  `STID` varchar(65) NOT NULL DEFAULT '',
  `STID_SERIAL` varchar(20) NOT NULL DEFAULT '',
  `STAGE` varchar(3) NOT NULL DEFAULT '',
  `CREATED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `CREATED_BY` varchar(10) NOT NULL DEFAULT '',
  `APPROVED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `APPROVED_BY` varchar(10) NOT NULL DEFAULT '',
  `APPROVED_NOTES` tinytext NOT NULL,
  `APPROVED_RESTOCK_FEE` decimal(10,2) NOT NULL DEFAULT '0.00',
  `EXPECTED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `EXPECTED_CONDITION` varchar(4) NOT NULL DEFAULT '',
  `XSHIP_APPROVED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `XSHIP_APPROVED_BY` varchar(10) NOT NULL DEFAULT '',
  `XSHIP_ORDERID` varchar(10) NOT NULL DEFAULT '',
  `XSHIP_PAID` enum('NO','AUTHONLY','CUSTOMER','VENDOR') DEFAULT NULL,
  `XSHIP_TENDER` varchar(10) NOT NULL DEFAULT '',
  `XSHIP_TXNID` varchar(25) NOT NULL DEFAULT '0',
  `XSHIP_NOTES` tinytext NOT NULL,
  `RECEIVED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `RECEIVED_BY` varchar(10) NOT NULL DEFAULT '',
  `RECEIVED_CONDITION` varchar(4) NOT NULL DEFAULT '',
  `RECEIVED_NOTES` tinytext NOT NULL,
  `INSPECTION_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `INSPECTION_BY` varchar(10) NOT NULL DEFAULT '',
  `INSPECTION_NOTES` tinytext NOT NULL,
  `INSPECTION_CONDITION` varchar(4) NOT NULL DEFAULT '',
  `INSPECTION_DAMAGED` tinyint(3) unsigned NOT NULL,
  `RETURNED_INV_REC` int(10) unsigned NOT NULL DEFAULT '0',
  `RETURNED_BY` varchar(10) NOT NULL DEFAULT '',
  `REFUND_BY` varchar(10) NOT NULL DEFAULT '',
  `REFUND_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `REFUND_AMOUNT` decimal(10,2) NOT NULL DEFAULT '0.00',
  `REFUND_TAXES` decimal(5,2) NOT NULL DEFAULT '0.00',
  `REFUND_SHIPPING` decimal(5,2) NOT NULL DEFAULT '0.00',
  `REFUND_TOTAL` decimal(10,2) NOT NULL DEFAULT '0.00',
  `REFUND_TENDER` varchar(10) NOT NULL DEFAULT '',
  `REFUND_TXNID` varchar(25) NOT NULL DEFAULT '',
  `REFUND_NOTES` tinytext NOT NULL,
  `CLOSED_TS` int(10) unsigned NOT NULL DEFAULT '0',
  `NOTES` tinytext NOT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`ORDERID`,`STID`,`STID_SERIAL`),
  KEY `MID_2` (`MID`,`TKTCODE`),
  KEY `MID_3` (`MID`,`CLOSED_TS`,`STAGE`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `CUSTOMER_REVIEWS`
--

DROP TABLE IF EXISTS `CUSTOMER_REVIEWS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CUSTOMER_REVIEWS` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `CUSTOMER` varchar(65) NOT NULL DEFAULT '',
  `CID` int(11) NOT NULL DEFAULT '0',
  `CUSTOMER_NAME` varchar(30) NOT NULL DEFAULT '',
  `LOCATION` varchar(30) NOT NULL DEFAULT '',
  `PID` varchar(20) NOT NULL DEFAULT '',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `SUBJECT` varchar(60) NOT NULL DEFAULT '',
  `MESSAGE` text NOT NULL,
  `USEFUL_YES` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `USEFUL_NO` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `RATING` tinyint(4) NOT NULL DEFAULT '0',
  `BLOG_URL` varchar(128) NOT NULL DEFAULT '',
  `IPADDRESS` bigint(20) NOT NULL DEFAULT '0',
  `APPROVED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  KEY `MID` (`MID`,`PID`,`APPROVED_GMT`)
) ENGINE=MyISAM AUTO_INCREMENT=6 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `CUSTOMER_SECURE`
--

DROP TABLE IF EXISTS `CUSTOMER_SECURE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CUSTOMER_SECURE` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `CID` int(10) unsigned NOT NULL DEFAULT '0',
  `CREATED` datetime DEFAULT NULL,
  `EXPIRES` datetime DEFAULT NULL,
  `IS_DEFAULT` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `DESCRIPTION` varchar(20) NOT NULL DEFAULT '',
  `SECURE` tinytext NOT NULL,
  `ATTEMPTS` int(11) NOT NULL DEFAULT '0',
  `FAILURES` int(11) NOT NULL DEFAULT '0',
  `SYNCED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `IS_DELETED` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `KEYREF` varchar(3) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `UNI_MIDCIDID` (`MID`,`CID`,`ID`),
  KEY `IN_EXPIRES` (`EXPIRES`)
) ENGINE=MyISAM AUTO_INCREMENT=148 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `CUSTOMER_WHOLESALE`
--

DROP TABLE IF EXISTS `CUSTOMER_WHOLESALE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CUSTOMER_WHOLESALE` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `PRT` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `CID` int(10) unsigned NOT NULL DEFAULT '0',
  `EMAIL` varchar(65) NOT NULL DEFAULT '',
  `DOMAIN` varchar(65) DEFAULT NULL,
  `firstname` varchar(25) NOT NULL DEFAULT '',
  `lastname` varchar(25) NOT NULL DEFAULT '',
  `company` varchar(100) NOT NULL DEFAULT '',
  `address1` varchar(60) NOT NULL DEFAULT '',
  `address2` varchar(60) NOT NULL DEFAULT '',
  `city` varchar(30) NOT NULL DEFAULT '',
  `region` varchar(10) NOT NULL DEFAULT '',
  `postal` varchar(9) NOT NULL DEFAULT '',
  `countrycode` varchar(9) NOT NULL DEFAULT '',
  `phone` varchar(12) NOT NULL DEFAULT '',
  `LOGO` varchar(60) NOT NULL DEFAULT '',
  `BILLING_CONTACT` varchar(60) NOT NULL DEFAULT '',
  `BILLING_PHONE` varchar(60) NOT NULL DEFAULT '',
  `ALLOW_PO` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `RESALE` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `RESALE_PERMIT` varchar(20) NOT NULL DEFAULT '',
  `CREDIT_LIMIT` decimal(10,2) NOT NULL,
  `CREDIT_BALANCE` decimal(10,2) NOT NULL,
  `CREDIT_TERMS` varchar(25) NOT NULL DEFAULT '',
  `ACCOUNT_MANAGER` varchar(10) NOT NULL DEFAULT '',
  `ACCOUNT_TYPE` varchar(20) NOT NULL DEFAULT '',
  `ACCOUNT_REFID` varchar(36) NOT NULL DEFAULT '',
  `JEDI_MID` int(11) NOT NULL DEFAULT '0',
  `BUYER_PASSWORD` varchar(10) NOT NULL DEFAULT '',
  `IS_LOCKED` tinyint(4) NOT NULL DEFAULT '0',
  `SCHEDULE` varchar(10) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  KEY `IN_DOMAIN` (`MID`,`PRT`,`DOMAIN`),
  KEY `IN_EMAIL` (`MID`,`PRT`,`EMAIL`),
  KEY `IN_CONTACT` (`MID`,`PRT`,`BILLING_CONTACT`),
  KEY `IN_PHONE` (`MID`,`PRT`,`phone`),
  KEY `MIDCID` (`MID`,`CID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `DEVICES`
--

DROP TABLE IF EXISTS `DEVICES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `DEVICES` (
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `CREATED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `LASTUSED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `LASTIP` varchar(32) NOT NULL DEFAULT '',
  `DEVICE_NOTE` varchar(32) NOT NULL DEFAULT '',
  `DEVICEID` varchar(32) NOT NULL DEFAULT '',
  `HISTORY` text NOT NULL,
  UNIQUE KEY `MID` (`MID`,`DEVICEID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `DOMAINS`
--

DROP TABLE IF EXISTS `DOMAINS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `DOMAINS` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `MID` int(11) NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `PRT` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `IS_PRT_PRIMARY` tinyint(4) NOT NULL DEFAULT '0',
  `IS_FAVORITE` tinyint(4) DEFAULT NULL,
  `PROFILE` varchar(10) NOT NULL DEFAULT '',
  `DOMAIN` varchar(50) NOT NULL DEFAULT '',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `VERIFIED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `MODIFIED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `REG_TYPE` enum('OTHER','ZOOVY','VSTORE','SUBDOMAIN','NEW','TRANSFER','WAIT','ERROR','') NOT NULL DEFAULT '',
  `REG_STATE` enum('','NEW','TRANSFER','NEW-WAIT','TRANSFER-WAIT','VERIFY','ACTIVE') NOT NULL DEFAULT '',
  `REG_ORDERID` int(10) unsigned NOT NULL DEFAULT '0',
  `REG_RENEWAL_GMT` int(11) NOT NULL DEFAULT '0',
  `REG_STATUS` varchar(60) NOT NULL DEFAULT '',
  `EMAIL_TYPE` enum('MX','GOOGLE','FUSEMAIL','NONE','') DEFAULT NULL,
  `EMAIL_CONFIG` text,
  `GOOGLE_SITEMAP` varchar(100) NOT NULL DEFAULT '',
  `DKIM_PRIVKEY` text NOT NULL,
  `DKIM_PUBKEY` tinytext NOT NULL,
  `BING_SITEMAP` varchar(100) NOT NULL DEFAULT '',
  `YAHOO_SITEMAP` varchar(100) NOT NULL DEFAULT '',
  `IS_DELETED_GMT` int(11) NOT NULL DEFAULT '0',
  `NEWSLETTER_ENABLE` tinyint(4) NOT NULL DEFAULT '1',
  `SYNDICATION_ENABLE` tinyint(4) NOT NULL DEFAULT '0',
  `YAML` mediumtext NOT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `DOMAIN` (`DOMAIN`),
  UNIQUE KEY `ID` (`ID`),
  KEY `MID` (`MID`),
  KEY `USERNAME` (`USERNAME`)
) ENGINE=MyISAM AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `DOMAINS_EMAIL_ALIAS`
--

DROP TABLE IF EXISTS `DOMAINS_EMAIL_ALIAS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `DOMAINS_EMAIL_ALIAS` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `DOMAIN` varchar(64) NOT NULL DEFAULT '',
  `ALIAS` varchar(50) NOT NULL DEFAULT '',
  `TARGET_EMAIL` varchar(129) NOT NULL DEFAULT '',
  `AUTORESPONDER` tinyint(4) NOT NULL DEFAULT '0',
  `AUTORESPONDER_MSG` mediumtext NOT NULL,
  `IS_NEWSLETTER` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`DOMAIN`,`ALIAS`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `DOMAINS_LOG`
--

DROP TABLE IF EXISTS `DOMAINS_LOG`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `DOMAINS_LOG` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `MID` int(11) NOT NULL DEFAULT '0',
  `DOMAIN` varchar(50) NOT NULL DEFAULT '',
  `CREATED_GMT` int(11) NOT NULL DEFAULT '0',
  `CLASS` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `TXT` varchar(100) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  KEY `MID` (`MID`,`DOMAIN`,`CREATED_GMT`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `DOMAINS_PARKED`
--

DROP TABLE IF EXISTS `DOMAINS_PARKED`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `DOMAINS_PARKED` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `DOMAIN` varchar(65) NOT NULL DEFAULT '',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `HITS` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `DOMAIN` (`DOMAIN`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `DOMAINS_POOL`
--

DROP TABLE IF EXISTS `DOMAINS_POOL`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `DOMAINS_POOL` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `DOMAIN` varchar(65) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `DOMAIN` (`DOMAIN`),
  KEY `MID` (`MID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `DOMAINS_URL_MAP`
--

DROP TABLE IF EXISTS `DOMAINS_URL_MAP`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `DOMAINS_URL_MAP` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(11) NOT NULL DEFAULT '0',
  `DOMAIN` varchar(50) NOT NULL DEFAULT '',
  `PATH` varchar(100) NOT NULL DEFAULT '',
  `TARGETURL` varchar(200) NOT NULL DEFAULT '',
  `CREATED` datetime DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `PATH` (`MID`,`DOMAIN`,`PATH`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `DOMAIN_HOSTS`
--

DROP TABLE IF EXISTS `DOMAIN_HOSTS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `DOMAIN_HOSTS` (
  `CREATED_TS` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `DOMAINNAME` varchar(50) NOT NULL DEFAULT '',
  `HOSTNAME` varchar(10) NOT NULL DEFAULT '',
  `HOSTTYPE` enum('APPTIMIZER','VSTORE','VSTORE-APP','REDIR','CUSTOM','') NOT NULL DEFAULT '',
  `CONFIG` tinytext,
  `CHKOUT` varchar(65) NOT NULL DEFAULT '',
  UNIQUE KEY `MID` (`MID`,`DOMAINNAME`,`HOSTNAME`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `DOMAIN_LOGS`
--

DROP TABLE IF EXISTS `DOMAIN_LOGS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `DOMAIN_LOGS` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `MID` int(11) NOT NULL DEFAULT '0',
  `DOMAIN` varchar(50) NOT NULL DEFAULT '',
  `CREATED_TS` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `LUSER` varchar(10) NOT NULL DEFAULT '',
  `HOST` varchar(10) NOT NULL DEFAULT '',
  `MSGTYPE` varchar(10) NOT NULL DEFAULT '',
  `MSG` tinytext NOT NULL,
  PRIMARY KEY (`ID`),
  KEY `MID` (`MID`,`DOMAIN`,`CREATED_TS`)
) ENGINE=MyISAM AUTO_INCREMENT=28 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `DSS_COMPETITORS`
--

DROP TABLE IF EXISTS `DSS_COMPETITORS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `DSS_COMPETITORS` (
  `ID` int(10) unsigned NOT NULL DEFAULT '0',
  `CREATED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `MKT` enum('AMZ','EBAY','BUY','WEB') DEFAULT NULL,
  `MKTID` varchar(30) NOT NULL DEFAULT '',
  `MKTNAME` varchar(50) NOT NULL DEFAULT '',
  `LOGO_HEIGHT` smallint(6) DEFAULT NULL,
  `LOGO_WIDTH` smallint(6) DEFAULT NULL,
  `LOGOFORMAT` enum('','png','jpg','gif') DEFAULT NULL,
  `LOGOBLOB` blob,
  UNIQUE KEY `MID` (`MID`,`MKT`,`MKTID`),
  KEY `MID_2` (`MID`,`MKT`,`MKTNAME`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `EBAYSTORE_CATEGORIES`
--

DROP TABLE IF EXISTS `EBAYSTORE_CATEGORIES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `EBAYSTORE_CATEGORIES` (
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(11) NOT NULL DEFAULT '0',
  `EIAS` varchar(64) NOT NULL DEFAULT '',
  `EBAYUSER` varchar(25) NOT NULL DEFAULT '',
  `CatNum` bigint(20) unsigned NOT NULL DEFAULT '0',
  `Category` varchar(128) NOT NULL DEFAULT '',
  UNIQUE KEY `MID` (`MID`,`EIAS`,`CatNum`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `EBAY_JOBS`
--

DROP TABLE IF EXISTS `EBAY_JOBS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `EBAY_JOBS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `PRT` tinyint(4) NOT NULL DEFAULT '0',
  `CREATED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `JOB_ID` varchar(32) NOT NULL DEFAULT '',
  `JOB_TYPE` varchar(25) NOT NULL DEFAULT '',
  `JOB_FILEID` bigint(20) NOT NULL DEFAULT '0',
  `DOWNLOADED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `FILENAME` varchar(64) NOT NULL DEFAULT '',
  `ERRORS` int(10) unsigned NOT NULL DEFAULT '0',
  `WARNINGS` int(10) unsigned NOT NULL DEFAULT '0',
  `DOWNLOADED_APP` varchar(6) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `UNI_MIDPRTJOBID` (`MID`,`PRT`,`JOB_ID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `EBAY_LISTINGS`
--

DROP TABLE IF EXISTS `EBAY_LISTINGS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `EBAY_LISTINGS` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `MERCHANT` varchar(20) NOT NULL DEFAULT '',
  `MID` int(11) NOT NULL DEFAULT '0',
  `PRT` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `PROFILE` varchar(10) NOT NULL DEFAULT '',
  `PROFILE_VERSION` tinyint(4) NOT NULL DEFAULT '0',
  `PRODUCT` varchar(45) NOT NULL DEFAULT '',
  `CHANNEL` bigint(20) NOT NULL DEFAULT '0',
  `EBAY_ID` bigint(20) DEFAULT NULL,
  `CREATED_GMT` int(11) NOT NULL DEFAULT '0',
  `LASTSAVE_GMT` int(11) NOT NULL DEFAULT '0',
  `LAUNCHED_GMT` int(11) NOT NULL DEFAULT '0',
  `LAST_PROCESSED_GMT` int(11) NOT NULL DEFAULT '0',
  `LAST_TRANSACTIONS_GMT` int(11) NOT NULL DEFAULT '0',
  `ENDS_GMT` int(11) NOT NULL DEFAULT '0',
  `EXPIRES_GMT` int(11) NOT NULL DEFAULT '0',
  `QUANTITY` int(11) NOT NULL DEFAULT '0',
  `ITEMS_SOLD` int(11) NOT NULL DEFAULT '0',
  `ITEMS_REMAIN` int(11) NOT NULL DEFAULT '0',
  `ORIG_EBAYID` bigint(20) NOT NULL DEFAULT '0',
  `DEST_USER` varchar(60) NOT NULL DEFAULT '',
  `TRIGGER_PRICE` decimal(10,2) NOT NULL DEFAULT '0.00',
  `RECYCLED_ID` bigint(20) NOT NULL DEFAULT '0',
  `BIDPRICE` decimal(10,2) NOT NULL DEFAULT '0.00',
  `BIDCOUNT` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `BUYITNOW` decimal(10,2) NOT NULL DEFAULT '0.00',
  `TITLE` varchar(55) NOT NULL DEFAULT '',
  `CATEGORY` int(11) NOT NULL DEFAULT '0',
  `STORECAT` int(10) unsigned NOT NULL DEFAULT '0',
  `CLASS` enum('AUCTION','DUTCH','FIXED','MOTOR','STORE','PERSONAL','OTHER') DEFAULT 'OTHER',
  `VISITORS` int(11) NOT NULL DEFAULT '0',
  `IS_GTC` tinyint(4) NOT NULL DEFAULT '0',
  `IS_POWERLISTER` int(10) unsigned NOT NULL DEFAULT '0',
  `IS_RELIST` tinyint(4) NOT NULL DEFAULT '0',
  `IS_RECYCLABLE` tinyint(4) NOT NULL DEFAULT '0',
  `IS_SYNDICATED` tinyint(4) NOT NULL DEFAULT '0',
  `HAS_OPTIONS` tinyint(4) NOT NULL DEFAULT '0',
  `IS_MOTORS` tinyint(4) NOT NULL DEFAULT '0',
  `IS_RESERVE` decimal(10,2) NOT NULL DEFAULT '0.00',
  `IS_SCOK` decimal(8,2) NOT NULL DEFAULT '0.00',
  `RESULT` varchar(60) NOT NULL DEFAULT '',
  `RELISTS` tinyint(4) NOT NULL DEFAULT '0',
  `THUMB` varchar(60) NOT NULL DEFAULT '',
  `LOCK_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `LOCK_PID` int(10) unsigned NOT NULL DEFAULT '0',
  `GALLERY_UPDATES` int(11) NOT NULL DEFAULT '0',
  `DISPATCHID` int(11) DEFAULT NULL,
  `PRODTS` int(11) NOT NULL DEFAULT '0',
  `IS_SANDBOX` tinyint(4) NOT NULL DEFAULT '0',
  `IS_ENDED` int(10) unsigned NOT NULL DEFAULT '0',
  `INV_RESERVATION_ID` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `EBAY_ID` (`EBAY_ID`),
  UNIQUE KEY `DISPATCHID` (`DISPATCHID`),
  KEY `MID` (`MID`,`CHANNEL`),
  KEY `LAUNCHED_GMT` (`LAUNCHED_GMT`),
  KEY `LOCK_PID` (`LOCK_PID`),
  KEY `CHANNEL` (`CHANNEL`),
  KEY `MID_2` (`MID`,`ENDS_GMT`,`PRODUCT`),
  KEY `MID_3` (`MID`,`PRODUCT`,`ENDS_GMT`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `EBAY_ORDERS`
--

DROP TABLE IF EXISTS `EBAY_ORDERS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `EBAY_ORDERS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `CREATED` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `EBAY_EIAS` varchar(64) NOT NULL DEFAULT '',
  `EBAY_JOBID` bigint(20) NOT NULL DEFAULT '0',
  `EBAY_ORDERID` varchar(50) NOT NULL DEFAULT '',
  `EBAY_STATUS` enum('Active','Completed','Shipped','') NOT NULL DEFAULT '',
  `OUR_ORDERID` varchar(30) NOT NULL DEFAULT '',
  `PAY_METHOD` varchar(10) NOT NULL DEFAULT '',
  `PAY_REFID` varchar(20) NOT NULL DEFAULT '',
  `APPVER` varchar(4) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`EBAY_ORDERID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `EBAY_POWER_QUEUE`
--

DROP TABLE IF EXISTS `EBAY_POWER_QUEUE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `EBAY_POWER_QUEUE` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `PRT` tinyint(4) NOT NULL DEFAULT '0',
  `PRODUCT` varchar(45) NOT NULL DEFAULT '',
  `CLASS` enum('AUCTION','FIXED','') NOT NULL DEFAULT '',
  `STATUS` enum('NEW','ACTIVE','PAUSED','ERROR','DONE') DEFAULT 'NEW',
  `STATUS_REASON` tinytext NOT NULL,
  `CREATED_TS` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `EXPIRES_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `QUANTITY_RESERVED` int(11) NOT NULL DEFAULT '0',
  `QUANTITY_SOLD` int(11) NOT NULL DEFAULT '0',
  `LISTINGS_ALLOWED` int(11) NOT NULL DEFAULT '0',
  `LISTINGS_LAUNCHED` int(11) NOT NULL DEFAULT '0',
  `CONCURRENT_LISTINGS` int(11) NOT NULL DEFAULT '0',
  `LAST_POLL_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `NEXT_POLL_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `START_HOUR` int(11) DEFAULT NULL,
  `END_HOUR` int(11) DEFAULT NULL,
  `LAUNCH_DOW` int(11) NOT NULL DEFAULT '0',
  `LAUNCH_DELAY` int(11) NOT NULL DEFAULT '0',
  `FILL_BIN_ASAP` enum('Y','N') NOT NULL DEFAULT 'N',
  `LAST_LAUNCH_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `LAST_SALE_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `BIN_EVENTS` int(11) DEFAULT NULL,
  `DIRTY` int(11) DEFAULT NULL,
  `TRIGGER_PRICE` decimal(10,2) NOT NULL DEFAULT '0.00',
  `CONCURRENT_LISTING_MAX` int(11) NOT NULL DEFAULT '0',
  `TITLE` varchar(80) NOT NULL DEFAULT '',
  `ERRORS` int(11) NOT NULL DEFAULT '0',
  `LOCKED` int(11) NOT NULL DEFAULT '0',
  `LOCK_PID` int(11) NOT NULL DEFAULT '0',
  `DATA` mediumtext NOT NULL,
  `TXLOG` text NOT NULL,
  PRIMARY KEY (`ID`),
  KEY `DIRTY` (`DIRTY`),
  KEY `EXPIRES` (`EXPIRES_TS`),
  KEY `LOCKED` (`LOCKED`),
  KEY `MID` (`MID`,`PRODUCT`),
  KEY `IN_STATUS` (`STATUS`,`MID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `EBAY_PROFILES`
--

DROP TABLE IF EXISTS `EBAY_PROFILES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `EBAY_PROFILES` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `PRT` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `CODE` varchar(8) NOT NULL DEFAULT '',
  `V` decimal(6,0) NOT NULL DEFAULT '0',
  `DATA` mediumtext NOT NULL,
  `CREATED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `MODIFIED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `LASTUSED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `HAS_ERRORS` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`PRT`,`CODE`),
  UNIQUE KEY `MID_2` (`MID`,`CODE`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `EBAY_TOKENS`
--

DROP TABLE IF EXISTS `EBAY_TOKENS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `EBAY_TOKENS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `PRT` int(10) unsigned NOT NULL DEFAULT '0',
  `EBAY_USERNAME` varchar(40) NOT NULL DEFAULT '',
  `EBAY_TOKEN` mediumtext,
  `EBAY_TOKEN_EXP` datetime DEFAULT NULL,
  `VERIFIED` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `IS_SANDBOX` tinyint(4) NOT NULL DEFAULT '0',
  `IS_EPU` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `LAST_POLL_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `NEXT_POLL_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `ERRORS` int(10) unsigned NOT NULL DEFAULT '0',
  `LAST_TRANSACTIONS_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `LAST_ACCOUNT_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `NEXT_ACCOUNT_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `CACHED_FLAGS` varchar(45) NOT NULL DEFAULT '',
  `GALLERY_LAST_POLL_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `GALLERY_NEXT_POLL_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `GALLERY_POLL_INTERVAL` int(10) unsigned NOT NULL DEFAULT '0',
  `UPI_OLDEST_OPEN_DISPUTE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `UPI_NEXTPOLL_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `UPI_AUTODISPUTE` int(10) unsigned NOT NULL DEFAULT '0',
  `HAS_STORE` tinyint(4) NOT NULL DEFAULT '0',
  `EBAY_EIAS` varchar(64) DEFAULT NULL,
  `EBAY_SUBSCRIPTION` varchar(20) NOT NULL DEFAULT '',
  `EBAY_FEEDBACKSCORE` int(11) NOT NULL DEFAULT '0',
  `CHKOUT_PROFILE` varchar(10) NOT NULL DEFAULT 'DEFAULT',
  `GALLERY_VARS` tinytext NOT NULL,
  `GALLERY_STYLE` tinyint(4) NOT NULL DEFAULT '0',
  `MONITOR_LOCK_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `MONITOR_LOCK_ID` int(10) unsigned NOT NULL DEFAULT '0',
  `MONITOR_LOCK_ATTEMPTS` int(10) unsigned NOT NULL DEFAULT '0',
  `FB_MODE` tinyint(3) unsigned NOT NULL DEFAULT '1',
  `FB_POLLED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `FB_MESSAGE` varchar(55) NOT NULL DEFAULT '',
  `ORDERS_POLLED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `CHKOUT_STYLE` enum('COR','EBAY') DEFAULT 'COR',
  `DO_IMPORT_LISTINGS` tinyint(4) NOT NULL DEFAULT '0',
  `DO_CREATE_ORDERS` tinyint(3) unsigned NOT NULL DEFAULT '1',
  `IGNORE_ORDERS_BEFORE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `LMS_SOLD_DOCID` bigint(20) NOT NULL DEFAULT '0',
  `LMS_SOLD_UUID` varchar(32) NOT NULL DEFAULT '',
  `LMS_SOLD_REQGMT` int(10) unsigned NOT NULL DEFAULT '0',
  `LMS_SOLD_PENDING` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `LMS_PROCESSED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `LMS_LOCK_ID` int(10) unsigned NOT NULL DEFAULT '0',
  `LMS_LOCK_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `LMS_ACTIVE_DOCID` bigint(20) unsigned NOT NULL DEFAULT '0',
  `LMS_ACTIVE_UUID` varchar(20) NOT NULL DEFAULT '',
  `LMS_ACTIVE_REQGMT` int(10) unsigned NOT NULL DEFAULT '0',
  `LMS_INVENTORY_DOCID` bigint(20) NOT NULL DEFAULT '0',
  `LMS_INVENTORY_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`EBAY_USERNAME`),
  UNIQUE KEY `MERCHANT` (`USERNAME`,`PRT`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `EBAY_USER_CATEGORIES`
--

DROP TABLE IF EXISTS `EBAY_USER_CATEGORIES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `EBAY_USER_CATEGORIES` (
  `MERCHANT` varchar(20) NOT NULL DEFAULT '',
  `CREATED_GMT` int(11) NOT NULL DEFAULT '0',
  `CATEGORY` decimal(10,0) DEFAULT NULL,
  `SITE` tinyint(4) NOT NULL DEFAULT '0',
  UNIQUE KEY `MERCHANT_2` (`MERCHANT`,`CATEGORY`),
  KEY `MERCHANT` (`MERCHANT`,`CREATED_GMT`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `EBAY_WINNERS`
--

DROP TABLE IF EXISTS `EBAY_WINNERS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `EBAY_WINNERS` (
  `CLAIM` int(11) NOT NULL DEFAULT '0',
  `MERCHANT` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `PROFILE` varchar(10) NOT NULL DEFAULT '',
  `CHANNEL` int(11) NOT NULL DEFAULT '0',
  `PRODUCT` varchar(30) NOT NULL DEFAULT '',
  `EBAY_ID` bigint(20) NOT NULL DEFAULT '0',
  `EBAY_USER` varchar(40) NOT NULL DEFAULT '',
  `EBAY_USER_EIAS` varchar(64) NOT NULL DEFAULT '',
  `EMAIL` varchar(65) NOT NULL DEFAULT '0',
  `CREATED` datetime DEFAULT '0000-00-00 00:00:00',
  `AMOUNT` decimal(10,2) NOT NULL DEFAULT '0.00',
  `QTY` int(11) NOT NULL DEFAULT '0',
  `TRANSACTION` bigint(20) unsigned NOT NULL DEFAULT '0',
  `APP` varchar(10) NOT NULL DEFAULT '',
  `FEEDBACK_RECEIVED` int(11) NOT NULL DEFAULT '0',
  `PAID` int(11) NOT NULL DEFAULT '0',
  `FEEDBACK_LEFT` int(11) NOT NULL DEFAULT '0',
  `FEEDBACK_DIRTY` tinyint(4) NOT NULL DEFAULT '0',
  `DISPUTE_STATUS` enum('NONE','OPEN','WAIT','CLOSE') NOT NULL DEFAULT 'NONE',
  `DISPUTE_ID` int(10) unsigned NOT NULL DEFAULT '0',
  `SITE_ID` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `EIAS` varchar(64) NOT NULL DEFAULT '',
  `EBAY_ORDERID` varchar(64) NOT NULL DEFAULT '',
  UNIQUE KEY `EBAY_ID` (`EBAY_ID`,`EMAIL`,`TRANSACTION`),
  UNIQUE KEY `EBAY_ID2` (`EBAY_ID`,`EBAY_USER`,`TRANSACTION`),
  UNIQUE KEY `CLAIM` (`CLAIM`,`MID`),
  KEY `CHANNEL` (`CHANNEL`),
  KEY `FEEDBACK_DIRTY` (`FEEDBACK_DIRTY`),
  KEY `MID` (`MID`,`PROFILE`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `EMAIL_ABUSERS`
--

DROP TABLE IF EXISTS `EMAIL_ABUSERS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `EMAIL_ABUSERS` (
  `ID` int(11) NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `IPADDRESS` varchar(20) NOT NULL DEFAULT '',
  `COUNT` int(10) unsigned NOT NULL DEFAULT '0',
  `LASTATTEMPT_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  UNIQUE KEY `MID` (`MID`,`IPADDRESS`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `EMAIL_LOG`
--

DROP TABLE IF EXISTS `EMAIL_LOG`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `EMAIL_LOG` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `EMAIL` varchar(65) NOT NULL DEFAULT '',
  `CREATED` datetime DEFAULT NULL,
  `STATE` enum('SENT','OPTOUT','') NOT NULL DEFAULT '',
  `URIDATA` tinytext,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`EMAIL`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `EVENT_RECOVERY_TXNS`
--

DROP TABLE IF EXISTS `EVENT_RECOVERY_TXNS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `EVENT_RECOVERY_TXNS` (
  `MID` int(10) unsigned DEFAULT NULL,
  `CREATED_GMT` int(10) unsigned DEFAULT NULL,
  `CLASS` varchar(20) NOT NULL DEFAULT '',
  `ACTION` varchar(20) NOT NULL DEFAULT '',
  `GUID` varchar(36) NOT NULL DEFAULT '',
  KEY `MID` (`MID`,`CLASS`,`ACTION`,`GUID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `EXTERNAL_ITEMS`
--

DROP TABLE IF EXISTS `EXTERNAL_ITEMS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `EXTERNAL_ITEMS` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `PRT` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `CHANNEL` int(11) NOT NULL DEFAULT '0',
  `BUYER_EMAIL` varchar(65) NOT NULL DEFAULT '',
  `BUYER_USERID` varchar(30) NOT NULL DEFAULT '',
  `BUYER_EIAS` varchar(64) NOT NULL DEFAULT '',
  `SELLER_EIAS` varchar(64) NOT NULL DEFAULT '',
  `SKU` varchar(35) NOT NULL DEFAULT '',
  `PROD_NAME` varchar(200) NOT NULL DEFAULT '',
  `PRICE` decimal(10,2) NOT NULL DEFAULT '0.00',
  `QTY` smallint(5) unsigned NOT NULL DEFAULT '0',
  `MKT` enum('ebay','overstock','') NOT NULL DEFAULT '',
  `MKT_SITE` varchar(3) NOT NULL DEFAULT '',
  `MKT_LISTINGID` bigint(20) unsigned NOT NULL DEFAULT '0',
  `MKT_TRANSACTIONID` bigint(20) unsigned NOT NULL DEFAULT '0',
  `MKT_ORDERID` bigint(20) NOT NULL DEFAULT '0',
  `ZOOVY_ORDERID` varchar(30) NOT NULL DEFAULT '',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `MUSTPURCHASEBY_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `MODIFIED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `EMAILSENT_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `PAID_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `SHIPPED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `FEEDBACK_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `STAGE` enum('A','I','V','T','E','H','P','C','','G','W','N','X') DEFAULT NULL,
  `DATA` mediumtext,
  `REF` bigint(20) unsigned NOT NULL DEFAULT '0',
  `SYNCED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `REFX` (`MID`,`BUYER_EMAIL`,`MKT_LISTINGID`,`SKU`,`REF`),
  KEY `P` (`MKT`,`STAGE`),
  KEY `MID_3` (`MID`,`CHANNEL`),
  KEY `MID_4` (`MID`,`BUYER_EMAIL`),
  KEY `MID_5` (`MID`,`STAGE`),
  KEY `MID_6` (`MID`,`SKU`),
  KEY `MID_7` (`MID`,`BUYER_USERID`),
  KEY `MIDMKTID` (`MID`,`MKT_LISTINGID`),
  KEY `IN_SYNCED` (`MID`,`SYNCED_GMT`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `FAQ_ANSWERS`
--

DROP TABLE IF EXISTS `FAQ_ANSWERS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `FAQ_ANSWERS` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `MID` int(11) NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `PRT` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `TOPIC_ID` int(11) NOT NULL DEFAULT '0',
  `KEYWORDS` varchar(128) NOT NULL DEFAULT '',
  `QUESTION` varchar(80) NOT NULL DEFAULT '',
  `ANSWER` text NOT NULL,
  `LIMIT_PROFILE` varchar(8) NOT NULL DEFAULT '',
  `PRIORITY` tinyint(3) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  KEY `MID` (`MID`)
) ENGINE=MyISAM AUTO_INCREMENT=8 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `FAQ_TOPICS`
--

DROP TABLE IF EXISTS `FAQ_TOPICS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `FAQ_TOPICS` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `MID` int(11) NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `PRT` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `TITLE` varchar(30) NOT NULL DEFAULT '',
  `PRIORITY` tinyint(3) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  KEY `MID` (`MID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `GIFTCARDS`
--

DROP TABLE IF EXISTS `GIFTCARDS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `GIFTCARDS` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) CHARACTER SET latin1 NOT NULL DEFAULT '',
  `PRT` tinyint(4) NOT NULL DEFAULT '0',
  `CODE` varchar(16) CHARACTER SET latin1 NOT NULL DEFAULT '',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `CREATED_BY` varchar(15) CHARACTER SET latin1 NOT NULL DEFAULT '',
  `EXPIRES_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `LAST_ORDER` varchar(30) NOT NULL DEFAULT '',
  `CID` int(11) NOT NULL DEFAULT '0',
  `NOTE` varchar(128) CHARACTER SET latin1 NOT NULL DEFAULT '',
  `BALANCE` decimal(10,2) NOT NULL DEFAULT '0.00',
  `TXNCNT` smallint(5) unsigned DEFAULT '0',
  `COMBINABLE` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `MODIFIED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `CASHEQUIV` tinyint(4) NOT NULL DEFAULT '0',
  `SYNCED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `IS_DELETED` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `SRC_GUID` varchar(70) DEFAULT NULL,
  `SRC_SERIES` varchar(16) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`CODE`),
  UNIQUE KEY `GUID` (`MID`,`SRC_GUID`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `GIFTCARDS_LOG`
--

DROP TABLE IF EXISTS `GIFTCARDS_LOG`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `GIFTCARDS_LOG` (
  `MID` int(11) NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) CHARACTER SET latin1 NOT NULL DEFAULT '',
  `LUSER` varchar(10) CHARACTER SET latin1 NOT NULL DEFAULT '',
  `GCID` int(10) unsigned NOT NULL DEFAULT '0',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `NOTE` varchar(40) NOT NULL DEFAULT '',
  `TXNCNT` smallint(5) unsigned DEFAULT '0',
  `BALANCE` decimal(10,2) DEFAULT NULL,
  UNIQUE KEY `MID` (`MID`,`GCID`,`TXNCNT`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `GOOGLE_NOTIFICATIONS`
--

DROP TABLE IF EXISTS `GOOGLE_NOTIFICATIONS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `GOOGLE_NOTIFICATIONS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `CREATED` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `PRT` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `DATA` mediumtext,
  `REQUEST_URI` varchar(255) NOT NULL DEFAULT '',
  `PROCESSED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `LOCK_PID` int(10) unsigned NOT NULL DEFAULT '0',
  `LOCK_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `CALL_TYPE` varchar(15) NOT NULL DEFAULT 'UNKNOWN',
  `GOOGLE_SERIAL` varchar(32) DEFAULT NULL,
  `GOOGLE_INVNUM` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `GOOGLE_SERIAL` (`GOOGLE_SERIAL`),
  KEY `PROCESSED_GMT` (`PROCESSED_GMT`),
  KEY `PROCESSED_GMT_2` (`PROCESSED_GMT`,`LOCK_GMT`,`LOCK_PID`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `GOOGLE_ORDERS`
--

DROP TABLE IF EXISTS `GOOGLE_ORDERS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `GOOGLE_ORDERS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `CREATED` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `GOOGLE_ORDERID` varchar(20) NOT NULL DEFAULT '',
  `OUR_ORDERID` varchar(20) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `GOOGLE_ORDERID` (`GOOGLE_ORDERID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `GUID_REGISTRY`
--

DROP TABLE IF EXISTS `GUID_REGISTRY`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `GUID_REGISTRY` (
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `CREATED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `GUIDTYPE` varchar(6) NOT NULL DEFAULT '',
  `GUID` varchar(45) NOT NULL DEFAULT '',
  `DATA` varchar(32) NOT NULL DEFAULT '',
  UNIQUE KEY `MID` (`MID`,`GUIDTYPE`,`GUID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `IFOLDERS`
--

DROP TABLE IF EXISTS `IFOLDERS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `IFOLDERS` (
  `FID` int(11) NOT NULL AUTO_INCREMENT,
  `FName` varchar(100) NOT NULL DEFAULT '',
  `ImageCount` int(11) NOT NULL DEFAULT '0',
  `MERCHANT` varchar(20) NOT NULL DEFAULT '',
  `MID` int(11) NOT NULL DEFAULT '0',
  `ParentFID` int(10) unsigned NOT NULL DEFAULT '0',
  `ParentName` varchar(175) NOT NULL DEFAULT '',
  `TS` int(10) unsigned NOT NULL DEFAULT '0',
  `ItExists` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`FID`),
  UNIQUE KEY `MID_2` (`MID`,`ParentFID`,`FName`),
  KEY `MID` (`MID`,`FName`)
) ENGINE=MyISAM AUTO_INCREMENT=22 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `IMAGES`
--

DROP TABLE IF EXISTS `IMAGES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `IMAGES` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `ImgName` varchar(80) NOT NULL DEFAULT '',
  `Format` enum('gif','jpg','png','swf','pdf','mpg','mov','mp3','zip','') NOT NULL DEFAULT '',
  `TS` int(10) unsigned NOT NULL DEFAULT '0',
  `MERCHANT` varchar(20) NOT NULL DEFAULT '',
  `MID` int(11) NOT NULL DEFAULT '0',
  `FID` int(11) NOT NULL DEFAULT '0',
  `ItExists` tinyint(4) NOT NULL DEFAULT '0',
  `ThumbSize` int(10) unsigned NOT NULL DEFAULT '0',
  `MasterSize` int(10) unsigned NOT NULL DEFAULT '0',
  `H` smallint(6) NOT NULL DEFAULT '-1',
  `W` smallint(6) NOT NULL DEFAULT '-1',
  PRIMARY KEY (`Id`),
  UNIQUE KEY `MID_3` (`MID`,`FID`,`ImgName`),
  KEY `MID` (`MID`,`TS`)
) ENGINE=MyISAM AUTO_INCREMENT=318064 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `IMAGE_CACHE`
--

DROP TABLE IF EXISTS `IMAGE_CACHE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `IMAGE_CACHE` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `FILENAME` varchar(128) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `INVENTORY_DETAIL`
--

DROP TABLE IF EXISTS `INVENTORY_DETAIL`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `INVENTORY_DETAIL` (
  `ID` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `UUID` varchar(36) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `PID` varchar(20) NOT NULL DEFAULT '',
  `SKU` varchar(35) NOT NULL DEFAULT '',
  `WMS_GEO` varchar(3) DEFAULT NULL,
  `WMS_ZONE` varchar(3) DEFAULT NULL,
  `WMS_POS` varchar(12) DEFAULT NULL,
  `QTY` int(11) NOT NULL DEFAULT '0',
  `COST_I` int(10) unsigned NOT NULL DEFAULT '0',
  `NOTE` varchar(25) NOT NULL DEFAULT '',
  `CONTAINER` varchar(8) NOT NULL DEFAULT '',
  `ORIGIN` varchar(16) NOT NULL DEFAULT '',
  `BASETYPE` enum('SIMPLE','RETURN','WMS','SUPPLIER','ITEM','UNPAID','PURCHASE','HOLD','PICK','PICKED','DONE','SHIPPED','CANCEL','OVERSOLD','BACKORDER','ERROR','PREORDER','ONORDER','MARKET','CLAIM','CONSTANT','_ASM_') DEFAULT 'ERROR',
  `SUPPLIER_ID` varchar(10) DEFAULT NULL,
  `SUPPLIER_SKU` varchar(25) NOT NULL DEFAULT '',
  `MARKET_DST` varchar(4) DEFAULT NULL,
  `MARKET_REFID` varchar(16) NOT NULL DEFAULT '',
  `MARKET_ENDS_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `MARKET_SOLD_QTY` int(11) NOT NULL DEFAULT '0',
  `MARKET_SALE_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `PREFERENCE` smallint(6) NOT NULL DEFAULT '0',
  `CREATED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `MODIFIED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `MODIFIED_BY` varchar(10) NOT NULL DEFAULT '',
  `MODIFIED_INC` bigint(20) NOT NULL DEFAULT '0',
  `MODIFIED_QTY_WAS` int(11) NOT NULL DEFAULT '0',
  `VERIFY_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `VERIFY_INC` int(10) unsigned NOT NULL DEFAULT '0',
  `OUR_ORDERID` varchar(30) NOT NULL DEFAULT '',
  `PICK_BATCHID` varchar(8) NOT NULL DEFAULT '',
  `PICK_ROUTE` enum('','NEW','TBD','SIMPLE','WMS','SUPPLIER','PARTNER') DEFAULT NULL,
  `PICK_DONE_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `GRPASM_REF` varchar(35) DEFAULT NULL,
  `DESCRIPTION` tinytext NOT NULL,
  `VENDOR_STATUS` enum('NEW','MANUAL_DISPATCH','ADDED','ONORDER','CONFIRMED','RECEIVED','RETURNED','FINISHED','CANCELLED','CORRUPT') DEFAULT NULL,
  `VENDOR` varchar(6) NOT NULL DEFAULT '',
  `VENDOR_ORDER_DBID` int(10) unsigned NOT NULL DEFAULT '0',
  `VENDOR_SKU` varchar(25) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `IN_UUID` (`MID`,`SKU`,`UUID`),
  UNIQUE KEY `IN_MKT` (`MID`,`MARKET_DST`,`MARKET_REFID`),
  KEY `MID_2` (`MID`,`CONTAINER`),
  KEY `IN_MIDPID` (`MID`,`PID`),
  KEY `IN_MIDMOD` (`MID`,`MODIFIED_TS`),
  KEY `IN_MIDSUP` (`MID`,`SUPPLIER_ID`,`SKU`),
  KEY `IN_MIDWMS` (`MID`,`WMS_ZONE`),
  KEY `MID_VENDOR_ORDERID` (`MID`,`VENDOR`,`VENDOR_ORDER_DBID`),
  KEY `MID` (`MID`,`VENDOR_STATUS`),
  KEY `MID_3` (`MID`,`OUR_ORDERID`)
) ENGINE=MyISAM AUTO_INCREMENT=147131 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `INVENTORY_LOCKS`
--

DROP TABLE IF EXISTS `INVENTORY_LOCKS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `INVENTORY_LOCKS` (
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `CREATED` datetime DEFAULT NULL,
  `LOCK_PID` int(10) unsigned NOT NULL DEFAULT '0',
  UNIQUE KEY `UER` (`USERNAME`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `INVENTORY_LOG`
--

DROP TABLE IF EXISTS `INVENTORY_LOG`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `INVENTORY_LOG` (
  `ID` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(11) NOT NULL DEFAULT '0',
  `PID` varchar(20) NOT NULL DEFAULT '',
  `SKU` varchar(35) NOT NULL DEFAULT '',
  `CMD` varchar(10) NOT NULL DEFAULT '',
  `QTY` varchar(10) NOT NULL DEFAULT '0',
  `UUID` varchar(20) NOT NULL DEFAULT '',
  `LUSER` varchar(20) NOT NULL DEFAULT '',
  `TS` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `PARAMS` text NOT NULL,
  PRIMARY KEY (`ID`),
  KEY `PID` (`MID`,`PID`,`TS`)
) ENGINE=MyISAM AUTO_INCREMENT=3375742 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `INVENTORY_NOTIFICATIONS`
--

DROP TABLE IF EXISTS `INVENTORY_NOTIFICATIONS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `INVENTORY_NOTIFICATIONS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `PROFILE` varchar(10) NOT NULL DEFAULT '',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `SENT_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `PRODUCT` varchar(20) NOT NULL DEFAULT '',
  `SKU` varchar(45) NOT NULL DEFAULT '',
  `MSGID` varchar(12) NOT NULL DEFAULT '',
  `CID` int(11) DEFAULT '0',
  `EMAIL` varchar(65) NOT NULL DEFAULT '',
  `VARS` tinytext NOT NULL,
  PRIMARY KEY (`ID`),
  KEY `MID` (`MID`,`PRODUCT`),
  KEY `MID_2` (`MID`,`CID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `INVENTORY_UPDATES`
--

DROP TABLE IF EXISTS `INVENTORY_UPDATES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `INVENTORY_UPDATES` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) DEFAULT NULL,
  `LUSER` varchar(20) NOT NULL DEFAULT '',
  `TIMESTAMP` datetime DEFAULT NULL,
  `TYPE` enum('U','I','R','J','') DEFAULT NULL,
  `PRODUCT` varchar(20) NOT NULL DEFAULT '',
  `SKU` varchar(35) NOT NULL DEFAULT '',
  `QUANTITY` int(11) DEFAULT NULL,
  `APPID` varchar(10) NOT NULL DEFAULT '',
  `ORDERID` varchar(16) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  KEY `USERNAME` (`USERNAME`,`SKU`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `KPI_GRP_COUNTER`
--

DROP TABLE IF EXISTS `KPI_GRP_COUNTER`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `KPI_GRP_COUNTER` (
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `GRPTYPE` varchar(1) NOT NULL,
  `I` int(10) unsigned NOT NULL DEFAULT '0',
  UNIQUE KEY `MID` (`MID`,`GRPTYPE`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `KPI_GRP_LOOKUP`
--

DROP TABLE IF EXISTS `KPI_GRP_LOOKUP`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `KPI_GRP_LOOKUP` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `GRP` varchar(5) NOT NULL DEFAULT '',
  `SOUNDEX` varchar(6) NOT NULL DEFAULT '',
  `PRETTY` varchar(30) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`GRP`)
) ENGINE=MyISAM AUTO_INCREMENT=78 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `KPI_STATS`
--

DROP TABLE IF EXISTS `KPI_STATS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `KPI_STATS` (
  `ID` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `DT` int(10) unsigned NOT NULL DEFAULT '0',
  `GRP` varchar(5) NOT NULL DEFAULT '',
  `STAT_GMS` int(10) unsigned NOT NULL DEFAULT '0',
  `STAT_INC` int(10) unsigned NOT NULL DEFAULT '0',
  `STAT_UNITS` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`DT`,`GRP`)
) ENGINE=MyISAM AUTO_INCREMENT=904 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `KPI_USER_COLLECTIONS`
--

DROP TABLE IF EXISTS `KPI_USER_COLLECTIONS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `KPI_USER_COLLECTIONS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `PRT` tinyint(4) NOT NULL DEFAULT '0',
  `TITLE` varchar(60) NOT NULL DEFAULT '',
  `CREATED` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `IS_HIDDEN` tinyint(4) DEFAULT NULL,
  `IS_SYSTEM` int(10) unsigned NOT NULL DEFAULT '0',
  `UUID` varchar(36) NOT NULL,
  `VERSION` smallint(6) NOT NULL DEFAULT '0',
  `PRIORITY` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `YAML` mediumtext NOT NULL,
  `CREATED_TS` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `MODIFIED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `IN_MIDUUID` (`MID`,`UUID`),
  KEY `MID` (`MID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `KPI_USER_GRAPHS`
--

DROP TABLE IF EXISTS `KPI_USER_GRAPHS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `KPI_USER_GRAPHS` (
  `UUID` varchar(40) NOT NULL,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `CREATED` datetime DEFAULT NULL,
  `GRAPH` varchar(20) NOT NULL DEFAULT '',
  `TITLE` varchar(60) NOT NULL DEFAULT '',
  `CONFIG` text NOT NULL,
  `COLLECTION` int(10) unsigned NOT NULL DEFAULT '0',
  `SIZE` varchar(6) NOT NULL DEFAULT '',
  `PERIOD` varchar(20) NOT NULL DEFAULT '',
  `GRPBY` varchar(10) NOT NULL DEFAULT '',
  `COLUMNS` int(10) unsigned NOT NULL DEFAULT '0',
  `IS_SYSTEM` int(10) unsigned NOT NULL DEFAULT '0',
  `SORT_ORDER` smallint(5) unsigned NOT NULL DEFAULT '0',
  `JSON` text,
  UNIQUE KEY `MIDUUID` (`MID`,`UUID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `LISTING_EVENTS`
--

DROP TABLE IF EXISTS `LISTING_EVENTS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `LISTING_EVENTS` (
  `ID` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `PRT` tinyint(4) NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `LUSER` varchar(10) NOT NULL DEFAULT '',
  `PRODUCT` varchar(20) NOT NULL DEFAULT '',
  `SKU` varchar(35) NOT NULL DEFAULT '',
  `QTY` varchar(10) NOT NULL DEFAULT '',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `LAUNCH_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `PROCESSED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `TARGET` varchar(12) NOT NULL DEFAULT '',
  `TARGET_LISTINGID` bigint(20) unsigned DEFAULT NULL,
  `TARGET_UUID` bigint(20) NOT NULL DEFAULT '0',
  `LOCK_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `LOCK_ID` int(10) unsigned NOT NULL DEFAULT '0',
  `VERB` enum('INSERT','REMOVE-LISTING','REMOVE-SKU','UPDATE-INVENTORY','UPDATE-LISTING','END','CLEANUP','PAUSE','RESUME','DB-SYNC','') NOT NULL DEFAULT '',
  `REQUEST_BATCHID` varchar(8) NOT NULL DEFAULT '',
  `REQUEST_APP` varchar(4) NOT NULL DEFAULT '',
  `REQUEST_APP_UUID` bigint(20) DEFAULT NULL,
  `REQUEST_DATA` mediumtext,
  `RESULT` enum('PENDING','RUNNING','FAIL-SOFT','FAIL-FATAL','SUCCESS','SUCCESS-WARNING','') NOT NULL DEFAULT '',
  `RESULT_ERR_SRC` enum('','PREFLIGHT','LAUNCH','TRANSPORT','MKT','MKT-LISTING','MKT-ACCOUNT') NOT NULL DEFAULT '',
  `RESULT_ERR_CODE` int(11) NOT NULL DEFAULT '0',
  `RESULT_ERR_MSG` tinytext,
  `ATTEMPTS` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID_2` (`MID`,`REQUEST_BATCHID`,`REQUEST_APP`,`REQUEST_APP_UUID`),
  KEY `MID` (`MID`,`PRODUCT`),
  KEY `IN_NOT_PROCESSED_GMT` (`PROCESSED_GMT`,`LAUNCH_GMT`),
  KEY `IN_POWERLISTER` (`REQUEST_BATCHID`,`REQUEST_APP`,`PROCESSED_GMT`),
  KEY `IN_POWERLISTER2` (`REQUEST_BATCHID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `LUSERS`
--

DROP TABLE IF EXISTS `LUSERS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `LUSERS` (
  `UID` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(11) NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `LUSER` varchar(20) NOT NULL DEFAULT '',
  `PRT` int(11) NOT NULL DEFAULT '0',
  `FULLNAME` varchar(50) NOT NULL DEFAULT '',
  `JOBTITLE` varchar(50) NOT NULL DEFAULT '',
  `EMAIL` varchar(60) NOT NULL DEFAULT '',
  `PHONE` varchar(20) NOT NULL DEFAULT '',
  `CREATED_GMT` int(11) NOT NULL DEFAULT '0',
  `LASTLOGIN_GMT` int(11) NOT NULL DEFAULT '0',
  `LOGINS` int(10) unsigned NOT NULL DEFAULT '0',
  `IS_BILLING` enum('Y','N') NOT NULL DEFAULT 'N',
  `IS_CUSTOMERSERVICE` enum('Y','N') DEFAULT NULL,
  `IS_ADMIN` enum('Y','N') DEFAULT NULL,
  `ROLES` tinytext NOT NULL,
  `EXPIRES_GMT` int(11) NOT NULL DEFAULT '0',
  `PASSWORD` varchar(50) NOT NULL DEFAULT '',
  `PASSWORD_CHANGED` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `DT_CUID` varchar(128) NOT NULL DEFAULT '',
  `DT_REGISTER_GMT` int(11) NOT NULL DEFAULT '0',
  `DT_LASTPOLL_GMT` int(11) NOT NULL DEFAULT '0',
  `DATA` mediumtext NOT NULL,
  `ALLOW_FORUMS` enum('Y','N') NOT NULL DEFAULT 'N',
  `HAS_EMAIL` enum('Y','N','WAIT','ERR') NOT NULL DEFAULT 'N',
  `WMS_DEVICE_PIN` varchar(10) DEFAULT NULL,
  `PASSHASH` varchar(64) NOT NULL DEFAULT '',
  `PASSSALT` varchar(16) NOT NULL DEFAULT '',
  `PASSPIN` varchar(10) NOT NULL DEFAULT '',
  PRIMARY KEY (`UID`),
  UNIQUE KEY `MID` (`MID`,`LUSER`),
  UNIQUE KEY `MERCHANT_2` (`USERNAME`,`LUSER`),
  KEY `MERCHANT` (`USERNAME`,`LUSER`),
  KEY `MID_2` (`MID`,`DT_CUID`)
) ENGINE=MyISAM AUTO_INCREMENT=14 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `NAVCAT_BLOBS`
--

DROP TABLE IF EXISTS `NAVCAT_BLOBS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `NAVCAT_BLOBS` (
  `MID` int(11) NOT NULL DEFAULT '0',
  `ID` varchar(25) NOT NULL DEFAULT '',
  `UPDATED` int(10) unsigned NOT NULL DEFAULT '0',
  `DATA` mediumblob,
  UNIQUE KEY `MID` (`MID`,`ID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `NAVCAT_MEMORY`
--

DROP TABLE IF EXISTS `NAVCAT_MEMORY`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `NAVCAT_MEMORY` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) DEFAULT '',
  `MID` int(10) unsigned DEFAULT '0',
  `PRT` tinyint(4) NOT NULL DEFAULT '0',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `PID` varchar(20) NOT NULL DEFAULT '',
  `SAFENAME` varchar(128) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  KEY `PID` (`PID`,`CREATED_GMT`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `NAVCAT_UPDATES`
--

DROP TABLE IF EXISTS `NAVCAT_UPDATES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `NAVCAT_UPDATES` (
  `ID` bigint(20) NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `VERB` enum('SET','NUKE','SORT','') NOT NULL DEFAULT '',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `path` varchar(128) NOT NULL DEFAULT '',
  `pretty` varchar(128) NOT NULL DEFAULT '',
  `products` mediumtext NOT NULL,
  `sort` varchar(10) NOT NULL DEFAULT '',
  `meta` mediumtext NOT NULL,
  PRIMARY KEY (`ID`),
  KEY `MID` (`MID`,`path`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `NEWSLETTERS`
--

DROP TABLE IF EXISTS `NEWSLETTERS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `NEWSLETTERS` (
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `PRT` smallint(6) NOT NULL DEFAULT '0',
  `ID` int(11) NOT NULL DEFAULT '0',
  `NAME` varchar(30) NOT NULL DEFAULT '',
  `EXEC_SUMMARY` varchar(255) NOT NULL DEFAULT '',
  `MODE` int(11) NOT NULL DEFAULT '0',
  `LASTCAMPAIGN_GMT` int(11) NOT NULL DEFAULT '0',
  `RECENTSUBSCRIBER_GMT` int(11) NOT NULL DEFAULT '0',
  `TOTAL_SUBSCRIBERS` int(11) NOT NULL DEFAULT '0',
  `CREATED_GMT` int(11) NOT NULL DEFAULT '0',
  UNIQUE KEY `MID_2` (`MID`,`PRT`,`ID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `OAUTH_SESSIONS`
--

DROP TABLE IF EXISTS `OAUTH_SESSIONS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `OAUTH_SESSIONS` (
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `LUSERNAME` varchar(20) NOT NULL DEFAULT '',
  `CLIENTID` varchar(10) NOT NULL DEFAULT '',
  `DEVICEID` varchar(32) NOT NULL DEFAULT '',
  `AUTHTOKEN` varchar(128) NOT NULL DEFAULT '',
  `CREATED_TS` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `EXPIRES_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `IP_ADDRESS` varchar(32) NOT NULL DEFAULT '',
  `CACHED_FLAGS` varchar(255) NOT NULL DEFAULT '',
  `ACL` varchar(8192) DEFAULT NULL,
  UNIQUE KEY `MID` (`MID`,`AUTHTOKEN`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `OLD_SUPPLIER_ORDERS`
--

DROP TABLE IF EXISTS `OLD_SUPPLIER_ORDERS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `OLD_SUPPLIER_ORDERS` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(11) NOT NULL DEFAULT '0',
  `ORDERID` varchar(20) NOT NULL DEFAULT '',
  `REFID` varchar(15) NOT NULL DEFAULT '',
  `SUPPLIERCODE` varchar(6) DEFAULT NULL,
  `SUPPLIEROID` varchar(20) NOT NULL DEFAULT '',
  `FORMAT` enum('DROPSHIP','FULFILL','STOCK','') NOT NULL DEFAULT '',
  `CREATED_GMT` int(11) NOT NULL DEFAULT '0',
  `DISPATCHED_GMT` int(11) NOT NULL DEFAULT '0',
  `ARCHIVED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `RECEIVED_GMT` int(11) DEFAULT '0',
  `DISPATCHED_COUNT` int(11) DEFAULT '0',
  `STATUS` enum('OPEN','HOLD','CLOSED','PLACED','CONFIRMED','RECEIVED','ERROR','CANCELLED','CORRUPT','') DEFAULT NULL,
  `CONF_PERSON` varchar(30) NOT NULL DEFAULT '',
  `CONF_EMAIL` varchar(50) NOT NULL DEFAULT '',
  `CONF_ORDERTOTAL` decimal(10,2) DEFAULT NULL,
  `CONF_GMT` int(11) NOT NULL DEFAULT '0',
  `LOCK_GMT` int(11) NOT NULL DEFAULT '0',
  `LOCK_PID` int(11) NOT NULL DEFAULT '0',
  `WAIT_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `TOTAL_COST` decimal(10,2) DEFAULT '0.00',
  `ATTEMPTS` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `UNQ_ORDER` (`MID`,`ORDERID`,`SUPPLIERCODE`),
  KEY `MID_2` (`MID`,`ORDERID`),
  KEY `SRCMID` (`MID`,`SUPPLIERCODE`,`SUPPLIEROID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ORDERS`
--

DROP TABLE IF EXISTS `ORDERS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ORDERS` (
  `ID` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `MERCHANT` varchar(20) NOT NULL DEFAULT '',
  `MID` int(11) unsigned NOT NULL DEFAULT '0',
  `PRT` smallint(5) unsigned NOT NULL DEFAULT '0',
  `ORDERID` varchar(30) NOT NULL DEFAULT '',
  `BS_SETTLEMENT` int(10) unsigned NOT NULL DEFAULT '0',
  `V` tinyint(3) unsigned DEFAULT '0',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `MODIFIED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `PAID_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `PAID_TXN` varchar(20) NOT NULL DEFAULT '',
  `INV_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `SHIPPED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `SYNCED_GMT` int(11) NOT NULL DEFAULT '0',
  `CUSTOMER` int(11) unsigned NOT NULL DEFAULT '0',
  `POOL` enum('RECENT','REVIEW','HOLD','PENDING','APPROVED','PROCESS','COMPLETED','DELETED','QUOTE','BACKORDER','PREORDER','ARCHIVE','') NOT NULL DEFAULT '',
  `ORDER_BILL_NAME` varchar(30) NOT NULL DEFAULT '',
  `ORDER_BILL_EMAIL` varchar(30) NOT NULL DEFAULT '',
  `ORDER_BILL_ZONE` varchar(12) CHARACTER SET ascii NOT NULL DEFAULT '',
  `ORDER_BILL_PHONE` varchar(12) CHARACTER SET ascii NOT NULL DEFAULT '',
  `ORDER_SHIP_NAME` varchar(30) NOT NULL DEFAULT '',
  `ORDER_SHIP_ZONE` varchar(12) CHARACTER SET ascii NOT NULL DEFAULT '',
  `REVIEW_STATUS` varchar(3) CHARACTER SET ascii NOT NULL DEFAULT '',
  `ORDER_PAYMENT_STATUS` char(3) CHARACTER SET ascii NOT NULL DEFAULT '',
  `ORDER_PAYMENT_METHOD` varchar(4) CHARACTER SET ascii NOT NULL DEFAULT '',
  `ORDER_PAYMENT_LOOKUP` varchar(4) CHARACTER SET ascii NOT NULL DEFAULT '',
  `ORDER_EREFID` varchar(30) DEFAULT '',
  `ORDER_TOTAL` decimal(10,2) NOT NULL DEFAULT '0.00',
  `ORDER_SPECIAL` varchar(40) CHARACTER SET ascii NOT NULL DEFAULT '',
  `SHIP_METHOD` varchar(10) NOT NULL DEFAULT '',
  `MKT` int(10) unsigned DEFAULT '0',
  `MKT_BITSTR` varchar(24) CHARACTER SET ascii NOT NULL DEFAULT '',
  `FLAGS` int(10) unsigned NOT NULL DEFAULT '0',
  `ITEMS` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `YAML` mediumtext NOT NULL,
  `CARTID` varchar(30) CHARACTER SET ascii DEFAULT NULL,
  `SDOMAIN` tinytext CHARACTER SET ascii,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `IN_ORDERID` (`MID`,`ORDERID`),
  UNIQUE KEY `UNI_MIDCARTID` (`MID`,`CARTID`),
  KEY `IN_EREFID` (`MID`,`ORDER_EREFID`),
  KEY `IN_POOL` (`MID`,`POOL`),
  KEY `IN_CUSTOMER` (`MID`,`CUSTOMER`),
  KEY `IN_PAIDSHIP` (`MID`,`PAID_GMT`,`SHIPPED_GMT`),
  KEY `IN_SYNCED` (`MID`,`SYNCED_GMT`),
  KEY `MID` (`MID`,`CREATED_GMT`),
  KEY `IN_CREATED` (`MID`,`CREATED_GMT`),
  KEY `IN_BILL_EMAIL` (`MID`,`ORDER_BILL_EMAIL`)
) ENGINE=MyISAM AUTO_INCREMENT=1943 DEFAULT CHARSET=utf8 ROW_FORMAT=COMPRESSED;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ORDER_COUNTERS`
--

DROP TABLE IF EXISTS `ORDER_COUNTERS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ORDER_COUNTERS` (
  `MID` int(11) DEFAULT '0',
  `MERCHANT` varchar(20) NOT NULL DEFAULT '',
  `COUNTER` int(11) DEFAULT '0',
  `LAST_PID` int(11) DEFAULT '0',
  `LAST_SERVER` varchar(25) NOT NULL DEFAULT '',
  UNIQUE KEY `MERCHANT` (`MERCHANT`),
  UNIQUE KEY `MID` (`MID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ORDER_EVENTS`
--

DROP TABLE IF EXISTS `ORDER_EVENTS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ORDER_EVENTS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `PRT` tinyint(4) NOT NULL DEFAULT '0',
  `ORDERID` varchar(30) NOT NULL DEFAULT '',
  `EVENT` varchar(10) NOT NULL DEFAULT '',
  `LOCK_ID` smallint(5) unsigned NOT NULL DEFAULT '0',
  `LOCK_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `ATTEMPTS` tinyint(3) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  KEY `LOCK_GMT` (`LOCK_GMT`,`LOCK_ID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ORDER_PAYMENT_ADJUSTMENTS`
--

DROP TABLE IF EXISTS `ORDER_PAYMENT_ADJUSTMENTS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ORDER_PAYMENT_ADJUSTMENTS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `PRT` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `ORDERID` varchar(30) NOT NULL DEFAULT '',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `UUID` varchar(32) NOT NULL DEFAULT '',
  `AMOUNT` decimal(10,2) NOT NULL DEFAULT '0.00',
  `NOTE` tinytext NOT NULL,
  `LUSER` varchar(10) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`ORDERID`,`UUID`),
  KEY `MID_2` (`MID`,`PRT`,`CREATED_GMT`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ORDER_SHIP_NOTIFICATIONS`
--

DROP TABLE IF EXISTS `ORDER_SHIP_NOTIFICATIONS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ORDER_SHIP_NOTIFICATIONS` (
  `MID` int(11) NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `PRT` tinyint(4) NOT NULL DEFAULT '0',
  `OID` varchar(30) NOT NULL DEFAULT '',
  `CREATED_TS` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `MKT` varchar(3) NOT NULL DEFAULT '',
  `TRANSMIT_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `TRANSMIT_DOCID` bigint(20) NOT NULL DEFAULT '0',
  KEY `MID` (`MID`,`PRT`,`OID`),
  KEY `MID_2` (`MID`,`MKT`,`TRANSMIT_TS`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `PATCH_HISTORY`
--

DROP TABLE IF EXISTS `PATCH_HISTORY`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `PATCH_HISTORY` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `PATCH_ID` varchar(64) NOT NULL DEFAULT '',
  `PATCH_MD5` varchar(32) NOT NULL DEFAULT '',
  `APPLIED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `RESULT` varchar(10) NOT NULL DEFAULT '',
  `IS_CRASHED` tinyint(4) NOT NULL DEFAULT '0',
  `LOG` mediumtext NOT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `PATCH_ID` (`PATCH_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `PRIVATE_FILES`
--

DROP TABLE IF EXISTS `PRIVATE_FILES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `PRIVATE_FILES` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `GUID` varchar(36) NOT NULL DEFAULT '',
  `CREATEDBY` varchar(10) NOT NULL DEFAULT '',
  `CREATED` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `EXPIRES` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `TITLE` varchar(50) NOT NULL DEFAULT '',
  `FILENAME` varchar(100) NOT NULL DEFAULT '',
  `FILETYPE` varchar(12) DEFAULT NULL,
  `META` text NOT NULL,
  `REFERENCE` bigint(20) NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`FILENAME`),
  UNIQUE KEY `MID_2` (`MID`,`GUID`,`FILETYPE`(1)),
  KEY `MID_3` (`MID`,`FILETYPE`(1)),
  KEY `MID_4` (`MID`,`EXPIRES`)
) ENGINE=MyISAM AUTO_INCREMENT=9628 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `PROCESSING`
--

DROP TABLE IF EXISTS `PROCESSING`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `PROCESSING` (
  `EBAY_ID` bigint(20) NOT NULL DEFAULT '0',
  `PID` int(11) NOT NULL DEFAULT '0',
  `TS` int(11) NOT NULL DEFAULT '0',
  `APP` varchar(10) NOT NULL DEFAULT '',
  UNIQUE KEY `EBAY_ID` (`EBAY_ID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `PRODUCTS`
--

DROP TABLE IF EXISTS `PRODUCTS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `PRODUCTS` (
  `ID` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `MID` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `MERCHANT` varchar(20) NOT NULL DEFAULT '',
  `PRODUCT` varchar(20) NOT NULL DEFAULT '',
  `TS` int(11) unsigned NOT NULL DEFAULT '0',
  `PRODUCT_NAME` varchar(80) NOT NULL DEFAULT '',
  `CATEGORY` varchar(60) NOT NULL DEFAULT '',
  `DATA` mediumtext NOT NULL,
  `SALESRANK` int(10) unsigned NOT NULL DEFAULT '0',
  `CREATED_GMT` int(11) NOT NULL DEFAULT '0',
  `LASTSOLD_GMT` int(11) NOT NULL DEFAULT '0',
  `BASE_PRICE` decimal(10,2) DEFAULT NULL,
  `BASE_COST` decimal(10,2) DEFAULT NULL,
  `SUPPLIER` varchar(6) DEFAULT NULL,
  `SUPPLIER_ID` varchar(20) DEFAULT NULL,
  `MFG` varchar(20) DEFAULT NULL,
  `MFG_ID` varchar(20) DEFAULT NULL,
  `UPC` varchar(15) NOT NULL DEFAULT '',
  `OPTIONS` int(10) unsigned NOT NULL DEFAULT '0',
  `PROFILE` varchar(10) NOT NULL DEFAULT '',
  `MKT` bigint(20) NOT NULL DEFAULT '0',
  `PROD_IS` int(10) unsigned NOT NULL DEFAULT '0',
  `MKT_BITSTR` varchar(24) NOT NULL DEFAULT '',
  `MKTERR_BITSTR` varchar(16) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MIDPROD` (`MID`,`PRODUCT`),
  KEY `MIDTS` (`MID`,`TS`),
  KEY `MID_SUPPLIERID` (`MID`,`SUPPLIER_ID`)
) ENGINE=MyISAM AUTO_INCREMENT=30992 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `PRODUCT_RELATIONS`
--

DROP TABLE IF EXISTS `PRODUCT_RELATIONS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `PRODUCT_RELATIONS` (
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `PID` varchar(20) NOT NULL DEFAULT '',
  `CHILD_PID` varchar(20) NOT NULL DEFAULT '',
  `RELATION` varchar(16) NOT NULL DEFAULT '',
  `QTY` smallint(5) unsigned NOT NULL DEFAULT '0',
  `IS_ACTIVE` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `LIST_POS` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  UNIQUE KEY `MID` (`MID`,`PID`,`RELATION`,`CHILD_PID`),
  KEY `MID_2` (`MID`,`CHILD_PID`,`RELATION`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `PROJECTS`
--

DROP TABLE IF EXISTS `PROJECTS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `PROJECTS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `CREATED_TS` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UPDATED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `TITLE` varchar(45) NOT NULL DEFAULT '',
  `UUID` varchar(32) NOT NULL DEFAULT '',
  `SECRET` varchar(32) NOT NULL DEFAULT '',
  `TYPE` enum('APP','VSTORE','ADMIN','CHECKOUT','DSS','TEMPLATE','') NOT NULL DEFAULT '',
  `GITHUB_REPO` varchar(255) NOT NULL DEFAULT '',
  `GITHUB_BRANCH` varchar(20) NOT NULL DEFAULT '',
  `GITHUB_TXLOG` tinytext NOT NULL,
  `APP_RELEASE` varchar(6) NOT NULL DEFAULT '0',
  `APP_VERSION` varchar(16) NOT NULL DEFAULT '',
  `APP_SEO` varchar(6) NOT NULL DEFAULT '',
  `APP_EXPIRE` varchar(10) NOT NULL DEFAULT '',
  `APP_FORCE_SECURE` tinyint(4) NOT NULL DEFAULT '0',
  `APP_ROOT` varchar(50) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`)
) ENGINE=MyISAM AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `REPRICE_STRATEGIES`
--

DROP TABLE IF EXISTS `REPRICE_STRATEGIES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `REPRICE_STRATEGIES` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `DST` varchar(3) NOT NULL DEFAULT '',
  `IS_ACTIVE` tinyint(4) NOT NULL DEFAULT '0',
  `IS_SUSPENDED` tinyint(4) NOT NULL DEFAULT '0',
  `STRATEGY_ID` varchar(10) NOT NULL DEFAULT '',
  `CREATED_TS` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `MODIFIED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `LASTPOLL_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `YAML` text NOT NULL,
  `GUID` varchar(32) NOT NULL DEFAULT '',
  `COUNT_TOTAL` int(10) unsigned NOT NULL DEFAULT '0',
  `COUNT_SUCCESS` int(10) unsigned NOT NULL DEFAULT '0',
  `COUNT_FAILED` int(10) unsigned NOT NULL DEFAULT '0',
  `TXLOG` text NOT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`STRATEGY_ID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `RSS_FEEDS`
--

DROP TABLE IF EXISTS `RSS_FEEDS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `RSS_FEEDS` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `CPG_CODE` varchar(6) NOT NULL DEFAULT '',
  `CPG_TYPE` enum('NEWSLETTER','FOLLOWUP','RSS','PRINT','SMS','') NOT NULL DEFAULT '',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `CREATED_GMT` int(11) NOT NULL DEFAULT '0',
  `NAME` varchar(30) NOT NULL DEFAULT '',
  `SUBJECT` varchar(100) NOT NULL DEFAULT '',
  `SENDER` varchar(65) NOT NULL DEFAULT '',
  `DATA` mediumtext NOT NULL,
  `STATUS` enum('PENDING','APPROVED','QUEUED','FINISHED','ERROR') DEFAULT 'PENDING',
  `TESTED` int(11) DEFAULT NULL,
  `STARTS_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `QUEUED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `FINISHED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `STAT_QUEUED` int(10) unsigned NOT NULL DEFAULT '0',
  `STAT_SENT` int(10) unsigned NOT NULL DEFAULT '0',
  `STAT_OPENED` int(10) unsigned NOT NULL DEFAULT '0',
  `STAT_VIEWED` int(10) unsigned NOT NULL DEFAULT '0',
  `STAT_BOUNCED` int(10) unsigned NOT NULL DEFAULT '0',
  `STAT_CLICKED` int(10) unsigned NOT NULL DEFAULT '0',
  `STAT_CLICKEDINC` int(10) unsigned NOT NULL DEFAULT '0',
  `STAT_PURCHASED` int(10) unsigned NOT NULL DEFAULT '0',
  `STAT_TOTAL_SALES` int(10) unsigned NOT NULL DEFAULT '0',
  `STAT_UNSUBSCRIBED` int(10) unsigned NOT NULL DEFAULT '0',
  `RECIPIENT` varchar(20) DEFAULT NULL,
  `COUPON` varchar(8) NOT NULL DEFAULT '',
  `PROFILE` varchar(10) NOT NULL DEFAULT '',
  `PRT` smallint(5) unsigned NOT NULL DEFAULT '0',
  `LAYOUT` varchar(64) NOT NULL DEFAULT '',
  `SCHEDULE` varchar(10) NOT NULL DEFAULT '',
  `OUTPUT_HTML` text,
  `OUTPUT_TXT` text,
  `PREVIEW_GUID` varchar(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  KEY `MID` (`MID`),
  KEY `STATUS` (`STATUS`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SEARCH_CATALOGS`
--

DROP TABLE IF EXISTS `SEARCH_CATALOGS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SEARCH_CATALOGS` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `MERCHANT` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `CATALOG` varchar(20) NOT NULL DEFAULT '',
  `ATTRIBS` tinytext NOT NULL,
  `DIRTY` int(11) DEFAULT NULL,
  `CREATED` datetime DEFAULT NULL,
  `LASTINDEX` datetime DEFAULT NULL,
  `FORMAT` enum('ELASTIC','FULLTEXT','NUMERIC','EBAY','FINDER','') NOT NULL DEFAULT '',
  `ISOLATION_LEVEL` tinyint(3) unsigned NOT NULL DEFAULT '5',
  `DICTIONARY_DAYS` mediumint(9) NOT NULL DEFAULT '-1',
  `REPLACEMENTS` text NOT NULL,
  `KILLWORDS` text NOT NULL,
  `REWRITES` text NOT NULL,
  `USE_SOUNDEX` tinyint(4) NOT NULL DEFAULT '1',
  `USE_EXACT` tinyint(4) NOT NULL DEFAULT '1',
  `USE_WORDSTEMS` tinyint(4) NOT NULL DEFAULT '1',
  `USE_INFLECTIONS` tinyint(4) NOT NULL DEFAULT '1',
  `USE_ALLWORDS` tinyint(4) NOT NULL DEFAULT '0',
  `ES_DEFAULT_OPERATOR` enum('AND','OR') DEFAULT 'AND',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MERCHANT` (`MERCHANT`,`CATALOG`),
  KEY `DIRTY` (`DIRTY`),
  KEY `MERCHANT_2` (`MERCHANT`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SEARS_DOCS`
--

DROP TABLE IF EXISTS `SEARS_DOCS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SEARS_DOCS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `PRT` tinyint(4) NOT NULL DEFAULT '0',
  `DOCID` bigint(20) unsigned NOT NULL DEFAULT '0',
  `DOCTYPE` varchar(10) NOT NULL DEFAULT '',
  `CREATED_TS` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `PROCESSED_TS` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `YAML` text,
  `RESULT` tinytext NOT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`DOCID`),
  KEY `MID_2` (`MID`,`CREATED_TS`,`PROCESSED_TS`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SEO_PAGES`
--

DROP TABLE IF EXISTS `SEO_PAGES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SEO_PAGES` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned DEFAULT NULL,
  `CREATED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `GUID` varchar(36) NOT NULL DEFAULT '',
  `DOMAIN` varchar(65) NOT NULL DEFAULT '',
  `ESCAPED_FRAGMENT` varchar(128) DEFAULT NULL,
  `SITEMAP_SCORE` tinyint(3) unsigned NOT NULL DEFAULT '100',
  `BODY` mediumtext,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`DOMAIN`,`GUID`,`ESCAPED_FRAGMENT`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SEQUENCES`
--

DROP TABLE IF EXISTS `SEQUENCES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SEQUENCES` (
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `SEQUENCE_ID` varchar(10) NOT NULL DEFAULT '',
  `COUNTER` int(10) unsigned NOT NULL DEFAULT '0',
  `LAST_UPDATE` int(10) unsigned NOT NULL DEFAULT '0',
  `LAST_REQUEST` varchar(20) NOT NULL DEFAULT '',
  UNIQUE KEY `MIDS` (`MID`,`SEQUENCE_ID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SESSIONS`
--

DROP TABLE IF EXISTS `SESSIONS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SESSIONS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `TOKEN` varchar(32) NOT NULL DEFAULT '',
  `MID` int(11) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `LUSER` varchar(20) NOT NULL DEFAULT '',
  `RESELLER` varchar(10) NOT NULL DEFAULT '',
  `CLUSTER` varchar(10) NOT NULL DEFAULT '',
  `CREATED_TS` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `EXPIRES_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `IP_ADDRESS` varchar(20) NOT NULL DEFAULT '',
  `SESSIONID` varchar(26) NOT NULL DEFAULT '',
  `SECURITYID` varchar(26) NOT NULL DEFAULT '',
  `CACHED_FLAGS` varchar(255) NOT NULL DEFAULT '',
  `DOMAIN` varchar(65) NOT NULL DEFAULT '',
  `PRT` int(11) NOT NULL DEFAULT '0',
  `PROFILE` varchar(10) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `TOKEN` (`TOKEN`,`MID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SITE_EMAILS`
--

DROP TABLE IF EXISTS `SITE_EMAILS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SITE_EMAILS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) CHARACTER SET latin1 NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `PROFILE` varchar(10) CHARACTER SET latin1 NOT NULL DEFAULT '',
  `PRT` smallint(5) unsigned NOT NULL DEFAULT '0',
  `LANG` varchar(3) CHARACTER SET latin1 NOT NULL DEFAULT 'ENG',
  `MSGID` varchar(32) NOT NULL DEFAULT '',
  `FORMAT` enum('HTML','WIKI','TEXT','XML','HTML5','DONOTSEND') DEFAULT NULL,
  `OBJECT` enum('ORDER','ACCOUNT','PRODUCT','SUPPLY','TICKET','') DEFAULT NULL,
  `SUBJECT` varchar(60) NOT NULL DEFAULT '',
  `BODY` mediumtext NOT NULL,
  `MSGFROM` mediumtext,
  `MSGBCC` mediumtext,
  `CREATED_TS` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `MODIFIED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `LUSER` varchar(10) CHARACTER SET latin1 NOT NULL DEFAULT '',
  `METAJSON` text NOT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MIDXX` (`MID`,`PRT`,`MSGID`,`LANG`)
) ENGINE=MyISAM AUTO_INCREMENT=6 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SITE_MSGS`
--

DROP TABLE IF EXISTS `SITE_MSGS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SITE_MSGS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) CHARACTER SET latin1 NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `PRT` smallint(5) unsigned NOT NULL DEFAULT '0',
  `MSGID` varchar(48) CHARACTER SET latin1 NOT NULL DEFAULT '',
  `LANG` varchar(3) CHARACTER SET latin1 NOT NULL DEFAULT 'ENG',
  `MSGTXT` mediumtext CHARACTER SET latin1 NOT NULL,
  `CREATED_GMT` int(10) unsigned DEFAULT '0',
  `LUSER` varchar(10) CHARACTER SET latin1 NOT NULL DEFAULT '',
  `CUSTOM_CATEGORY` tinyint(4) NOT NULL DEFAULT '0',
  `CUSTOM_TITLE` tinytext NOT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID_2` (`MID`,`PRT`,`MSGID`,`LANG`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SITE_PAGES`
--

DROP TABLE IF EXISTS `SITE_PAGES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SITE_PAGES` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `PRT` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `PROFILE` varchar(10) NOT NULL DEFAULT '',
  `SAFEPATH` varchar(200) NOT NULL DEFAULT '',
  `DATA` mediumtext NOT NULL,
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `LASTMODIFIED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `DOMAIN` varchar(50) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  KEY `IN_DOMAIN` (`MID`,`SAFEPATH`,`DOMAIN`),
  KEY `IN_PRT` (`MID`,`PRT`,`SAFEPATH`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SKU_LOOKUP`
--

DROP TABLE IF EXISTS `SKU_LOOKUP`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SKU_LOOKUP` (
  `ID` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `PID` varchar(30) NOT NULL DEFAULT '',
  `INVOPTS` varchar(15) NOT NULL DEFAULT '',
  `GRP_PARENT` varchar(35) NOT NULL DEFAULT '',
  `SKU` varchar(45) NOT NULL,
  `TITLE` varchar(80) NOT NULL DEFAULT '0',
  `COST` decimal(10,2) NOT NULL DEFAULT '0.00',
  `PRICE` decimal(10,2) NOT NULL DEFAULT '0.00',
  `UPC` varchar(13) NOT NULL DEFAULT '',
  `MFGID` varchar(25) NOT NULL DEFAULT '',
  `SUPPLIERID` varchar(25) NOT NULL DEFAULT '',
  `PRODASM` tinytext,
  `ASSEMBLY` tinytext,
  `INV_AVAILABLE` int(11) NOT NULL DEFAULT '0',
  `QTY_ONSHELF` int(10) unsigned NOT NULL DEFAULT '0',
  `QTY_ONORDER` int(10) unsigned NOT NULL DEFAULT '0',
  `QTY_NEEDSHIP` int(10) unsigned NOT NULL DEFAULT '0',
  `QTY_MARKETS` int(10) unsigned NOT NULL DEFAULT '0',
  `QTY_LEGACY` int(11) NOT NULL DEFAULT '0',
  `QTY_RESERVED` int(10) unsigned NOT NULL DEFAULT '0',
  `AMZ_ASIN` varchar(15) NOT NULL DEFAULT '',
  `AMZ_FEEDS_DONE` smallint(5) unsigned NOT NULL DEFAULT '0',
  `AMZ_FEEDS_TODO` smallint(5) unsigned NOT NULL DEFAULT '0',
  `AMZ_FEEDS_SENT` tinyint(4) NOT NULL DEFAULT '0',
  `AMZ_FEEDS_WAIT` tinyint(4) NOT NULL DEFAULT '0',
  `AMZ_FEEDS_WARN` smallint(5) unsigned NOT NULL DEFAULT '0',
  `AMZ_FEEDS_ERROR` smallint(5) unsigned NOT NULL DEFAULT '0',
  `AMZ_PRODUCTDB_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `AMZ_ERROR` text NOT NULL,
  `INV_ON_SHELF` int(10) unsigned NOT NULL DEFAULT '0',
  `INV_ON_ORDER` int(10) unsigned NOT NULL DEFAULT '0',
  `INV_IS_BO` int(10) unsigned NOT NULL DEFAULT '0',
  `INV_REORDER` int(11) NOT NULL DEFAULT '0',
  `INV_IS_RSVP` int(10) unsigned NOT NULL DEFAULT '0',
  `DSS_AGENT` varchar(8) NOT NULL DEFAULT '',
  `DSS_RUN` set('ENABLED','UNLEASHED','PAUSED','HALTED') DEFAULT NULL,
  `DSS_MOOD` enum('WINNING','HAPPY','ZEN','MEDITATING','SLEEPY','GRUMPY','DEPRESSED','UNHAPPY','ANGRY','SUICIDAL') DEFAULT NULL,
  `DSS_CONFIG` text,
  `RP_IS` enum('ENABLED','UNLEASHED','PAUSED','UNHAPPY','ANGRY','WINNING','LOSING','DISABLED') NOT NULL DEFAULT 'DISABLED',
  `RP_STRATEGY` varchar(10) NOT NULL DEFAULT '',
  `RP_NEXTPOLL_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `RP_LASTPOLL_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `RP_CONFIG` tinytext NOT NULL,
  `RP_MINPRICE_I` int(10) unsigned NOT NULL DEFAULT '0',
  `RP_MINSHIP_I` int(10) unsigned NOT NULL DEFAULT '0',
  `RP_DATA` text NOT NULL,
  `IS_CONTAINER` tinyint(4) NOT NULL DEFAULT '0',
  `TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `DIRTY` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`PID`,`INVOPTS`),
  UNIQUE KEY `UNI_MIDSKU` (`MID`,`SKU`),
  KEY `MID_2` (`MID`,`UPC`),
  KEY `MID_3` (`MID`,`MFGID`),
  KEY `IN_AMZ_TODO` (`MID`,`AMZ_FEEDS_TODO`),
  KEY `MID_ASIN` (`MID`,`AMZ_ASIN`)
) ENGINE=MyISAM AUTO_INCREMENT=98376 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SNAPSHOT_SITES`
--

DROP TABLE IF EXISTS `SNAPSHOT_SITES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SNAPSHOT_SITES` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `PRT` int(10) unsigned NOT NULL DEFAULT '0',
  `SNAPSHOT_FILE` varchar(45) NOT NULL DEFAULT '',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`PRT`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SNAPSHOT_STATUS`
--

DROP TABLE IF EXISTS `SNAPSHOT_STATUS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SNAPSHOT_STATUS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `PRT` int(10) unsigned NOT NULL DEFAULT '0',
  `SERVER` varchar(20) NOT NULL DEFAULT '',
  `SNAPSHOT_FILE` varchar(45) NOT NULL DEFAULT '',
  `ACKED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`PRT`,`SERVER`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SSL_CERTIFICATES`
--

DROP TABLE IF EXISTS `SSL_CERTIFICATES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SSL_CERTIFICATES` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `CREATED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `CREATED_BY` varchar(10) NOT NULL DEFAULT '',
  `PROVISIONED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `ACTIVATED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `ACTIVATED_BY` varchar(10) NOT NULL DEFAULT '',
  `LIVE_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `USERNAME` varchar(20) DEFAULT NULL,
  `MID` int(10) unsigned DEFAULT NULL,
  `DOMAIN` varchar(65) DEFAULT NULL,
  `KEYTXT` mediumtext NOT NULL,
  `CSRTXT` mediumtext NOT NULL,
  `PEMTXT` mediumtext NOT NULL,
  `CERTTXT` mediumtext NOT NULL,
  `INC_INTERMEDIATE` enum('','GEO1') DEFAULT NULL,
  `RENEWING` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `STAT_LISTINGS`
--

DROP TABLE IF EXISTS `STAT_LISTINGS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `STAT_LISTINGS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `PID` varchar(20) NOT NULL DEFAULT '',
  `UUID` bigint(20) unsigned NOT NULL DEFAULT '0',
  `STYLE` enum('CHANNEL','LISTING','UUID') DEFAULT NULL,
  `CNT` int(10) unsigned NOT NULL DEFAULT '0',
  `LISTING_ID` bigint(20) unsigned NOT NULL DEFAULT '0',
  `UPDATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`PID`,`LISTING_ID`),
  KEY `UPDATED_GMT` (`UPDATED_GMT`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `STORE_OPTIONGROUPS`
--

DROP TABLE IF EXISTS `STORE_OPTIONGROUPS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `STORE_OPTIONGROUPS` (
  `SOGID` varchar(2) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `NAME` varchar(60) NOT NULL DEFAULT '',
  `MODIFIED_TS` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `CREATED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `YAML` mediumtext NOT NULL,
  `V` tinyint(4) NOT NULL DEFAULT '0',
  `INPUT_TYPE` varchar(15) NOT NULL DEFAULT '',
  `IS_INV` tinyint(4) NOT NULL DEFAULT '0',
  `IS_GLOBAL` tinyint(4) NOT NULL DEFAULT '0',
  UNIQUE KEY `MID` (`MID`,`SOGID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = latin1 */ ;
/*!50003 SET character_set_results = latin1 */ ;
/*!50003 SET collation_connection  = latin1_swedish_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER STORE_OPTIONGROUPS_CREATED_TS

BEFORE INSERT ON STORE_OPTIONGROUPS

FOR EACH ROW

SET NEW.CREATED_TS = CURRENT_TIMESTAMP */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `SUPPLIERS`
--

DROP TABLE IF EXISTS `SUPPLIERS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SUPPLIERS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(11) NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `CODE` varchar(10) NOT NULL DEFAULT '',
  `PROFILE` varchar(30) DEFAULT NULL,
  `FORMAT` enum('DROPSHIP','FULFILL','STOCK','NONE','RIVER','MARKET','FBA','') NOT NULL DEFAULT '',
  `PREFERENCE` smallint(5) unsigned NOT NULL DEFAULT '0',
  `MARKUP` varchar(25) NOT NULL DEFAULT '',
  `NAME` varchar(60) NOT NULL DEFAULT '',
  `PHONE` varchar(12) NOT NULL DEFAULT '',
  `EMAIL` varchar(65) NOT NULL DEFAULT '',
  `PASSWORD` varchar(20) DEFAULT NULL,
  `WEBSITE` varchar(65) NOT NULL DEFAULT '',
  `ACCOUNT` varchar(30) DEFAULT NULL,
  `JEDI_MID` int(11) DEFAULT NULL,
  `PARTNER` enum('ATLAST','SHIPWIRE','DOBA','FBA','QB','') DEFAULT '',
  `CREATED_GMT` int(11) DEFAULT NULL,
  `LASTSAVE_GMT` int(11) DEFAULT NULL,
  `INIDATA` text NOT NULL,
  `ITEM_NOTES` tinyint(4) DEFAULT '0',
  `LOCK_GMT` int(11) DEFAULT '0',
  `LOCK_PID` int(11) DEFAULT '0',
  `PRODUCT_CONNECTOR` enum('NONE','JEDI','CSV') DEFAULT NULL,
  `PRODUCT_PARAMS` text NOT NULL,
  `SHIP_CONNECTOR` enum('NONE','JEDI','API','PARTNER','GENERIC','FIXED','ZONE','FREE','FBA') DEFAULT NULL,
  `SHIP_PARAMS` text NOT NULL,
  `INVENTORY_CONNECTOR` enum('NONE','JEDI','API','PARTNER','GENERIC','FBA') DEFAULT NULL,
  `INVENTORY_PARAMS` text NOT NULL,
  `INVENTORY_LOG` text NOT NULL,
  `INVENTORY_NEXT_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `INVENTORY_LAST_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `ORDER_CONNECTOR` enum('NONE','JEDI','EMAIL','FAX','FTP','API','AMZSQS','FBA') DEFAULT NULL,
  `ORDER_PARAMS` text NOT NULL,
  `TRACK_CONNECTOR` enum('NONE','JEDI','API','PARTNER','FBA') DEFAULT NULL,
  `TRACK_LAST_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `TRACK_PARAMS` text NOT NULL,
  `MODE` varchar(1) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`CODE`)
) ENGINE=MyISAM AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SUPPLIER_INVENTORY`
--

DROP TABLE IF EXISTS `SUPPLIER_INVENTORY`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SUPPLIER_INVENTORY` (
  `ID` int(11) NOT NULL DEFAULT '0',
  `MID` int(11) NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `SUPPLIERID` varchar(6) NOT NULL DEFAULT '',
  `SKU` varchar(35) DEFAULT NULL,
  `UPC` varchar(15) DEFAULT NULL,
  `MFGID` varchar(16) DEFAULT NULL,
  `QTY_ON_SHELF` int(11) NOT NULL DEFAULT '0',
  `QTY_ON_ORDER` int(11) NOT NULL DEFAULT '0',
  `UPDATED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`SUPPLIERID`,`SKU`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SUPPLIER_SESSIONS`
--

DROP TABLE IF EXISTS `SUPPLIER_SESSIONS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SUPPLIER_SESSIONS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `TOKEN` varchar(32) NOT NULL DEFAULT '',
  `MID` int(11) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MUSER` varchar(20) NOT NULL DEFAULT '',
  `CREATED_TS` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `EXPIRES_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `IP_ADDRESS` varchar(20) NOT NULL DEFAULT '',
  `SESSIONID` varchar(26) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `U_TOKENMID` (`TOKEN`,`MID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SUPPLIER_SUBSCRIPTIONS`
--

DROP TABLE IF EXISTS `SUPPLIER_SUBSCRIPTIONS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SUPPLIER_SUBSCRIPTIONS` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `CODE` varchar(10) NOT NULL DEFAULT '',
  `SRCMID` int(11) NOT NULL DEFAULT '0',
  `SRCUSER` varchar(20) NOT NULL DEFAULT '',
  `SRCSAFE` varchar(100) NOT NULL DEFAULT '',
  `DSTMID` int(11) NOT NULL,
  `DSTUSER` varchar(20) NOT NULL DEFAULT '',
  `DSTSAFE` varchar(100) NOT NULL DEFAULT '',
  `PRETTY` varchar(100) NOT NULL DEFAULT '',
  `CREATED_GMT` int(11) NOT NULL DEFAULT '0',
  `UPDATED_GMT` int(11) NOT NULL DEFAULT '0',
  `PRODUCT_COUNT` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `DSTMID_2` (`DSTMID`,`SRCMID`,`SRCSAFE`),
  KEY `UNQ_CODE` (`CODE`,`SRCSAFE`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SYNC_LOG`
--

DROP TABLE IF EXISTS `SYNC_LOG`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SYNC_LOG` (
  `USERNAME` varchar(20) DEFAULT NULL,
  `MID` int(11) NOT NULL DEFAULT '0',
  `CREATED` datetime DEFAULT NULL,
  `CLIENT` varchar(30) DEFAULT NULL,
  `HOST` varchar(15) DEFAULT NULL,
  `REMOTEIP` varchar(20) NOT NULL DEFAULT '',
  `PUBLICIP` varchar(20) NOT NULL DEFAULT '',
  `SYNCTYPE` varchar(10) NOT NULL DEFAULT '',
  `OSVER` varchar(25) NOT NULL,
  `FINGERPRINT` varchar(10) NOT NULL DEFAULT '',
  KEY `CREATED` (`CREATED`),
  KEY `USERNAME` (`USERNAME`,`CREATED`),
  KEY `MID` (`MID`,`CREATED`),
  KEY `CREATED_2` (`CREATED`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 ROW_FORMAT=COMPRESSED;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SYNDICATE_REFRESH`
--

DROP TABLE IF EXISTS `SYNDICATE_REFRESH`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SYNDICATE_REFRESH` (
  `PROCESSED_GMT` int(11) NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `PRODUCT` varchar(20) NOT NULL DEFAULT '',
  `EBAY_ID` bigint(20) NOT NULL DEFAULT '0',
  `LOCKED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `LOCKED_PID` int(10) unsigned NOT NULL DEFAULT '0',
  KEY `PROCESSED_GMT` (`PROCESSED_GMT`,`USERNAME`,`PRODUCT`),
  KEY `LOCKED_GMT` (`LOCKED_GMT`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SYNDICATION`
--

DROP TABLE IF EXISTS `SYNDICATION`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SYNDICATION` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `DSTCODE` varchar(3) NOT NULL DEFAULT '',
  `DOMAIN` varchar(50) NOT NULL DEFAULT '',
  `PROFILE` varchar(10) NOT NULL DEFAULT '',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `LASTSAVE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `IS_ACTIVE` tinyint(4) NOT NULL DEFAULT '0',
  `IS_SUSPENDED` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `ERRCOUNT` tinyint(4) NOT NULL DEFAULT '0',
  `NEXTRUN_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `LASTRUN_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `DIAG_MSG` varchar(100) NOT NULL DEFAULT '',
  `DATA` mediumtext NOT NULL,
  `PROD_COUNT` int(10) unsigned NOT NULL DEFAULT '0',
  `LOCK_ID` varchar(10) NOT NULL DEFAULT '',
  `LOCK_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `PRODUCTS_LASTRUN_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `PRODUCTS_COUNT` int(11) NOT NULL DEFAULT '0',
  `PRODUCTS_ERRORS` int(10) unsigned NOT NULL DEFAULT '0',
  `PRODUCTS_NEXTQUEUE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `PRODUCTS_LASTQUEUE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `IMAGES_LASTRUN_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `IMAGES_NEXTQUEUE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `IMAGES_LASTQUEUE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `ORDERS_LASTRUN_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `ORDERS_NEXTQUEUE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `ORDERS_LASTQUEUE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `ORDERSTATUS_LASTRUN_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `ORDERSTATUS_NEXTQUEUE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `ORDERSTATUS_LASTQUEUE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `TRACKING_LASTQUEUE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `TRACKING_LASTRUN_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `TRACKING_NEXTQUEUE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `INVENTORY_LASTQUEUE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `INVENTORY_LASTRUN_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `INVENTORY_COUNT` int(10) unsigned NOT NULL DEFAULT '0',
  `INVENTORY_ERRORS` int(10) unsigned NOT NULL DEFAULT '0',
  `INVENTORY_NEXTQUEUE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `SHIPPING_NEXTQUEUE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `SHIPPING_LASTQUEUE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `SHIPPING_LASTRUN_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `ACCESSORIES_NEXTQUEUE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `ACCESSORIES_LASTQUEUE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `ACCESSORIES_LASTRUN_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `RELATIONS_NEXTQUEUE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `RELATIONS_LASTQUEUE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `RELATIONS_LASTRUN_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `PRICING_LASTRUN_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `PRICING_COUNT` int(10) unsigned NOT NULL DEFAULT '0',
  `PRICING_ERRORS` int(10) unsigned NOT NULL DEFAULT '0',
  `PRICING_NEXTQUEUE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `PRICING_LASTQUEUE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `PRIVATE_FILE_GUID` varchar(36) NOT NULL DEFAULT '0',
  `INFORM_ZOOVY_MARKETING` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `CONSECUTIVE_FAILURES` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `TXLOG` text NOT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `Z` (`MID`,`DSTCODE`,`PROFILE`),
  KEY `IN_DST` (`DSTCODE`,`IS_ACTIVE`)
) ENGINE=MyISAM AUTO_INCREMENT=4 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SYNDICATION_FILES`
--

DROP TABLE IF EXISTS `SYNDICATION_FILES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SYNDICATION_FILES` (
  `ID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `DSTCODE` varchar(3) NOT NULL DEFAULT '',
  `FILENAME` varchar(25) NOT NULL DEFAULT '',
  `TITLE` varchar(60) NOT NULL DEFAULT '',
  `CREATED_GMT` int(11) NOT NULL DEFAULT '0',
  `EXPIRES_GMT` int(11) NOT NULL DEFAULT '0',
  `DATA` mediumtext NOT NULL,
  UNIQUE KEY `MID` (`MID`,`DSTCODE`,`FILENAME`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SYNDICATION_JOBS`
--

DROP TABLE IF EXISTS `SYNDICATION_JOBS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SYNDICATION_JOBS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `PRT` tinyint(3) unsigned DEFAULT NULL,
  `DST` varchar(3) NOT NULL DEFAULT '',
  `JOB_ID` varchar(36) NOT NULL DEFAULT '0',
  `JOB_TYPE` varchar(10) NOT NULL DEFAULT '0',
  `FILENAME` varchar(128) NOT NULL DEFAULT '',
  `CREATED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `PROCESSED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`USERNAME`,`PRT`,`DST`,`JOB_ID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SYNDICATION_LINKSHARE_ID`
--

DROP TABLE IF EXISTS `SYNDICATION_LINKSHARE_ID`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SYNDICATION_LINKSHARE_ID` (
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `SKU` varchar(35) NOT NULL DEFAULT '',
  `ID` bigint(20) NOT NULL DEFAULT '0',
  UNIQUE KEY `MID` (`MID`,`ID`),
  UNIQUE KEY `MID_2` (`MID`,`SKU`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SYNDICATION_ORDERITEMS`
--

DROP TABLE IF EXISTS `SYNDICATION_ORDERITEMS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SYNDICATION_ORDERITEMS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `DST` varchar(3) NOT NULL DEFAULT '',
  `MKT_ORDERID` varchar(20) NOT NULL DEFAULT '',
  `MKT_SKU` varchar(30) NOT NULL DEFAULT '',
  `ZOOVY_ORDERID` varchar(20) NOT NULL DEFAULT '',
  `ZOOVY_STID` varchar(50) NOT NULL DEFAULT '',
  `PLEASE_SYNC_GMT` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`DST`,`MKT_ORDERID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SYNDICATION_ORDERS`
--

DROP TABLE IF EXISTS `SYNDICATION_ORDERS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SYNDICATION_ORDERS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `DST` varchar(3) NOT NULL DEFAULT '',
  `MKT_ORDERID` varchar(20) NOT NULL DEFAULT '',
  `ZOOVY_ORDERID` varchar(30) NOT NULL DEFAULT '',
  `PLEASE_SYNC_GMT` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`DST`,`MKT_ORDERID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SYNDICATION_PID_ERRORS`
--

DROP TABLE IF EXISTS `SYNDICATION_PID_ERRORS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SYNDICATION_PID_ERRORS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `OCCURRED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `ARCHIVE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `DSTCODE` varchar(3) NOT NULL DEFAULT '',
  `PID` varchar(20) NOT NULL DEFAULT '',
  `SKU` varchar(35) NOT NULL DEFAULT '',
  `FEED` smallint(5) unsigned NOT NULL DEFAULT '0',
  `ERRCODE` int(10) unsigned NOT NULL DEFAULT '0',
  `ERRMSG` text,
  `ERRCOUNT` int(11) NOT NULL DEFAULT '0',
  `DOCID` bigint(20) NOT NULL DEFAULT '0',
  `BATCHID` varchar(8) NOT NULL DEFAULT '',
  `LISTING_EVENT_ID` bigint(20) NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`SKU`,`DSTCODE`,`FEED`,`ERRCODE`),
  KEY `MIDPID` (`MID`,`PID`),
  KEY `MIDSSK` (`MID`,`DSTCODE`,`FEED`,`SKU`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SYNDICATION_QUEUED_EVENTS`
--

DROP TABLE IF EXISTS `SYNDICATION_QUEUED_EVENTS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SYNDICATION_QUEUED_EVENTS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `PRODUCT` varchar(20) NOT NULL DEFAULT '',
  `SKU` varchar(35) NOT NULL DEFAULT '',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `PROCESSED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `DST` varchar(3) NOT NULL DEFAULT '',
  `VERB` varchar(10) NOT NULL DEFAULT '',
  `ORIGIN_EVENT` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  KEY `MID` (`MID`,`DST`,`PROCESSED_GMT`)
) ENGINE=MyISAM AUTO_INCREMENT=538 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SYNDICATION_STASH`
--

DROP TABLE IF EXISTS `SYNDICATION_STASH`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SYNDICATION_STASH` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `PROFILE` varchar(10) NOT NULL DEFAULT '',
  `DSTCODE` varchar(3) NOT NULL DEFAULT '',
  `SKU` varchar(35) NOT NULL DEFAULT '',
  `LASTUPDATE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `YAML` text,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`PROFILE`,`DSTCODE`,`SKU`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `SYNDICATION_SUMMARY`
--

DROP TABLE IF EXISTS `SYNDICATION_SUMMARY`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SYNDICATION_SUMMARY` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `DSTCODE` varchar(3) NOT NULL DEFAULT '',
  `PROFILE` varchar(10) NOT NULL DEFAULT '',
  `CREATED` datetime DEFAULT NULL,
  `FEEDTYPE` enum('NOTE','PRODUCTS','IMAGES','INVENTORY','ORDERS','ORDERSTATUS','TRACKING','INVENTORY','SHIPPING','ACCESSORIES','RELATIONS','PRICING','') NOT NULL DEFAULT '',
  `SKU_TOTAL` int(11) NOT NULL DEFAULT '0',
  `SKU_VALIDATED` int(11) NOT NULL DEFAULT '0',
  `SKU_TRANSMITTED` int(11) NOT NULL DEFAULT '0',
  `NOTE` tinytext,
  PRIMARY KEY (`ID`),
  KEY `CREATED` (`CREATED`),
  KEY `MID` (`MID`,`DSTCODE`,`PROFILE`,`FEEDTYPE`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `TASK_LOCKS`
--

DROP TABLE IF EXISTS `TASK_LOCKS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TASK_LOCKS` (
  `CREATED` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `TASKID` varchar(32) NOT NULL DEFAULT '',
  `APPID` varchar(64) NOT NULL DEFAULT '',
  UNIQUE KEY `USERNAME` (`USERNAME`,`TASKID`)
) ENGINE=MEMORY DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `TEMPLATES`
--

DROP TABLE IF EXISTS `TEMPLATES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TEMPLATES` (
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `PROJECTID` varchar(36) NOT NULL DEFAULT '',
  `TEMPLATETYPE` varchar(10) NOT NULL DEFAULT '',
  `SUBDIR` varchar(45) NOT NULL DEFAULT '',
  `VERSION` decimal(6,0) NOT NULL DEFAULT '0',
  `GUID` varchar(36) NOT NULL DEFAULT '',
  `JSON` mediumtext,
  `HTML` mediumtext,
  `CREATED_TS` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `MODIFIED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `LOCK_ID` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`MID`,`TEMPLATETYPE`,`SUBDIR`),
  KEY `MID` (`MID`,`PROJECTID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `TICKETS`
--

DROP TABLE IF EXISTS `TICKETS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TICKETS` (
  `ID` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `TKTCODE` varchar(12) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `PRT` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `PROFILE` varchar(10) NOT NULL DEFAULT '',
  `DOMAIN` varchar(50) NOT NULL DEFAULT '',
  `CID` int(10) unsigned NOT NULL DEFAULT '0',
  `SUBJECT` varchar(60) NOT NULL DEFAULT '',
  `ORDERID` varchar(20) NOT NULL DEFAULT '',
  `NOTE` varchar(2048) NOT NULL DEFAULT '',
  `STATUS` enum('NEW','ACTIVE','WAIT','CLOSED','') NOT NULL DEFAULT '',
  `CLASS` enum('PRESALE','POSTSALE','RETURN','EXCHANGE','') DEFAULT '',
  `IS_REFUND` tinyint(3) unsigned DEFAULT '0',
  `STAGE` varchar(3) DEFAULT 'NEW',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `UPDATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `CLOSED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `UPDATES` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `ESCALATED` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `REFUND_AMOUNT` decimal(10,2) NOT NULL DEFAULT '0.00',
  `LAST_ACCESS_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `LAST_ACCESS_USER` varchar(10) NOT NULL DEFAULT '',
  `CLASSDATA` varchar(100) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`PRT`,`TKTCODE`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `TICKET_UPDATES`
--

DROP TABLE IF EXISTS `TICKET_UPDATES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TICKET_UPDATES` (
  `ID` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `PARENT` int(10) unsigned NOT NULL DEFAULT '0',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `AUTHOR` varchar(20) NOT NULL DEFAULT '',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `NOTE` varchar(2048) NOT NULL DEFAULT '',
  `PRIVATE` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  KEY `MID` (`MID`,`PARENT`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `TODO`
--

DROP TABLE IF EXISTS `TODO`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TODO` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `LUSER` varchar(10) NOT NULL DEFAULT '',
  `PID` varchar(20) NOT NULL DEFAULT '',
  `DSTCODE` varchar(3) NOT NULL DEFAULT '',
  `CLASS` enum('INFO','SETUP','MSG','TODO','WARN','ERROR','') NOT NULL DEFAULT '',
  `PRIORITY` tinyint(3) unsigned DEFAULT '0',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `DUE_GMT` int(10) unsigned DEFAULT '0',
  `EXPIRES_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `COMPLETED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `TITLE` varchar(100) NOT NULL DEFAULT '',
  `DETAIL` text NOT NULL,
  `LINK` varchar(100) NOT NULL DEFAULT '',
  `TICKET_ID` int(10) unsigned NOT NULL DEFAULT '0',
  `GROUPCODE` varchar(25) NOT NULL DEFAULT '',
  `PANEL` varchar(50) DEFAULT NULL,
  `PRIVATEFILE_GUID` varchar(36) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  KEY `MID` (`MID`,`LUSER`)
) ENGINE=MyISAM AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `TOXML`
--

DROP TABLE IF EXISTS `TOXML`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TOXML` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `DOCID` varchar(40) DEFAULT '',
  `TITLE` varchar(60) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `FORMAT` enum('LAYOUT','WRAPPER','WIZARD','DEFINITION','ZEMAIL','INCLUDE','ORDER','') NOT NULL DEFAULT '',
  `SUBTYPE` char(1) NOT NULL DEFAULT '',
  `DIGEST` varchar(32) NOT NULL DEFAULT '',
  `UPDATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `DEFINITION_MGID` char(3) DEFAULT NULL,
  `DEFINITION_INFO_URL` varchar(128) NOT NULL DEFAULT '',
  `DEFINITION_DISPATCH_URL` varchar(128) NOT NULL DEFAULT '',
  `DEFINITION_DOCUMENT_URL` varchar(128) NOT NULL DEFAULT '',
  `DEFINITION_LASTPOLL_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `DEFINITION_SECRET_KEY` varchar(30) NOT NULL DEFAULT '',
  `RANK_SELECTED` int(10) unsigned NOT NULL DEFAULT '0',
  `RANK_REMEMBER` int(10) unsigned NOT NULL DEFAULT '0',
  `WRAPPER_CATEGORIES` int(10) unsigned NOT NULL DEFAULT '0',
  `WRAPPER_COLORS` int(10) unsigned NOT NULL DEFAULT '0',
  `PROPERTIES` int(10) unsigned DEFAULT NULL,
  `STARS` tinyint(4) NOT NULL DEFAULT '0',
  `SYSTEM` tinyint(4) DEFAULT '1',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `FORMAT` (`FORMAT`,`DOCID`,`MID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `TOXML_RANKS`
--

DROP TABLE IF EXISTS `TOXML_RANKS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TOXML_RANKS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `CREATED_GMT` int(11) NOT NULL DEFAULT '0',
  `MID` int(11) NOT NULL DEFAULT '0',
  `MERCHANT` varchar(20) NOT NULL DEFAULT '',
  `DOCID` varchar(55) NOT NULL DEFAULT '',
  `FORMAT` enum('WRAPPER','LAYOUT','WIZARD','') NOT NULL DEFAULT '',
  `SELECTED` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID_2` (`MID`,`FORMAT`,`DOCID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `TXNTEST_LOG`
--

DROP TABLE IF EXISTS `TXNTEST_LOG`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TXNTEST_LOG` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `GATEWAY` varchar(10) NOT NULL DEFAULT '',
  `ORDERID` varchar(20) NOT NULL DEFAULT '',
  `UID` varchar(30) NOT NULL DEFAULT '',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `PS` char(3) NOT NULL DEFAULT '',
  `RESULT` varchar(15) NOT NULL DEFAULT '',
  `TENDER` varchar(15) NOT NULL DEFAULT '',
  `AMT` decimal(10,2) NOT NULL DEFAULT '0.00',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `USER_UID` (`USERNAME`,`UID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `UPIC`
--

DROP TABLE IF EXISTS `UPIC`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `UPIC` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `ORDERID` varchar(30) NOT NULL DEFAULT '',
  `CARRIER` varchar(4) NOT NULL DEFAULT '',
  `TRACK` varchar(20) NOT NULL DEFAULT '',
  `DVALUE` decimal(6,2) NOT NULL DEFAULT '0.00',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `VOID_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`ORDERID`,`TRACK`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `USER_EVENTS_FUTURE`
--

DROP TABLE IF EXISTS `USER_EVENTS_FUTURE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `USER_EVENTS_FUTURE` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `PRT` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `PROFILE` varchar(10) NOT NULL DEFAULT '',
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `DISPATCH_GMT` int(11) NOT NULL DEFAULT '0',
  `PROCESSED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `TYPE` enum('INVENTORY','ORDER','') NOT NULL DEFAULT '',
  `UUID` varchar(45) NOT NULL DEFAULT '',
  `MSGID` varchar(12) NOT NULL DEFAULT '',
  `CID` int(11) DEFAULT '0',
  `EMAIL` varchar(65) NOT NULL DEFAULT '',
  `VARS` tinytext NOT NULL,
  PRIMARY KEY (`ID`),
  KEY `MID` (`MID`,`TYPE`,`UUID`),
  KEY `MID_2` (`MID`,`CID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `USER_EVENTS_TRACKING`
--

DROP TABLE IF EXISTS `USER_EVENTS_TRACKING`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `USER_EVENTS_TRACKING` (
  `ID` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `PRT` tinyint(4) NOT NULL DEFAULT '0',
  `DST` varchar(3) NOT NULL DEFAULT '',
  `OID` varchar(30) NOT NULL DEFAULT '',
  `CARRIER` varchar(4) NOT NULL DEFAULT '',
  `TRACKING` varchar(32) NOT NULL,
  `SHIPPED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `ACK_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `DUE_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`PRT`,`DST`,`OID`,`CARRIER`,`TRACKING`),
  KEY `MID_2` (`MID`,`PRT`,`DST`,`ACK_GMT`),
  KEY `DUE_GMT` (`DUE_GMT`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `USER_EVENT_TIMERS`
--

DROP TABLE IF EXISTS `USER_EVENT_TIMERS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `USER_EVENT_TIMERS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `CREATED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `DISPATCH_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `PROCESSED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `PROCESSED_ID` int(10) unsigned NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `PRT` tinyint(4) NOT NULL DEFAULT '0',
  `EVENT` varchar(27) NOT NULL DEFAULT '',
  `UUID` varchar(20) NOT NULL DEFAULT '',
  `YAML` tinytext,
  `LOCK_ID` smallint(5) unsigned NOT NULL DEFAULT '0',
  `LOCK_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MUE` (`MID`,`UUID`,`EVENT`),
  KEY `IN_PDL` (`PROCESSED_GMT`,`DISPATCH_GMT`,`LOCK_ID`)
) ENGINE=MyISAM AUTO_INCREMENT=3360 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `VENDORS`
--

DROP TABLE IF EXISTS `VENDORS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `VENDORS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `CREATED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `MODIFIED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `VENDOR_CODE` varchar(6) NOT NULL DEFAULT '',
  `VENDOR_NAME` varchar(41) NOT NULL DEFAULT '',
  `QB_REFERENCE_ID` varchar(41) NOT NULL DEFAULT '',
  `ADDR1` varchar(41) NOT NULL DEFAULT '',
  `ADDR2` varchar(41) NOT NULL DEFAULT '',
  `CITY` varchar(31) NOT NULL DEFAULT '',
  `STATE` varchar(21) NOT NULL DEFAULT '',
  `POSTALCODE` varchar(31) NOT NULL DEFAULT '',
  `PHONE` varchar(21) NOT NULL DEFAULT '',
  `CONTACT` varchar(41) NOT NULL DEFAULT '',
  `EMAIL` varchar(100) NOT NULL DEFAULT '',
  `TXLOG` text,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`VENDOR_CODE`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `VENDOR_ORDERITEMS`
--

DROP TABLE IF EXISTS `VENDOR_ORDERITEMS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `VENDOR_ORDERITEMS` (
  `ID` bigint(20) NOT NULL AUTO_INCREMENT,
  `MID` int(11) NOT NULL DEFAULT '0',
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `OUR_ORDERID` varchar(30) NOT NULL DEFAULT '',
  `UUID` varchar(32) NOT NULL DEFAULT '',
  `SKU` varchar(45) NOT NULL DEFAULT '',
  `STID` varchar(100) NOT NULL DEFAULT '',
  `QTY` int(11) NOT NULL DEFAULT '0',
  `COST` decimal(10,2) DEFAULT '0.00',
  `DESCRIPTION` tinytext,
  `STATUS` enum('NEW','MANUAL_DISPATCH','ADDED','ONORDER','CONFIRMED','RECEIVED','RETURNED','FINISHED','CANCELLED','CORRUPT') DEFAULT NULL,
  `CREATED_GMT` int(11) NOT NULL DEFAULT '0',
  `CREATED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `MODIFIED_GMT` int(11) NOT NULL DEFAULT '0',
  `MODIFIED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `VENDOR` varchar(6) NOT NULL DEFAULT '',
  `VENDOR_ORDER_DBID` int(10) unsigned NOT NULL DEFAULT '0',
  `VENDOR_SKU` varchar(25) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `SRCMID_2` (`MID`,`OUR_ORDERID`,`STID`),
  KEY `MID_VENDOR_ORDERID` (`MID`,`VENDOR`,`VENDOR_ORDER_DBID`),
  KEY `STATUS` (`STATUS`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `VENDOR_ORDERS`
--

DROP TABLE IF EXISTS `VENDOR_ORDERS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `VENDOR_ORDERS` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(11) NOT NULL DEFAULT '0',
  `OUR_ORDERID` varchar(30) NOT NULL DEFAULT '',
  `OUR_VENDOR_PO` varchar(20) NOT NULL DEFAULT '',
  `VENDOR` varchar(20) NOT NULL DEFAULT '',
  `VENDOR_REFID` varchar(20) NOT NULL DEFAULT '',
  `FORMAT` enum('DROPSHIP','FULFILL','STOCK','') NOT NULL DEFAULT '',
  `CREATED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `DISPATCHED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `ARCHIVED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `RECEIVED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `DISPATCHED_COUNT` int(11) DEFAULT '0',
  `STATUS` enum('OPEN','HOLD','CLOSED','PLACED','CONFIRMED','RECEIVED','ERROR','CANCELLED','CORRUPT','') DEFAULT NULL,
  `CONF_PERSON` varchar(30) NOT NULL DEFAULT '',
  `CONF_EMAIL` varchar(50) NOT NULL DEFAULT '',
  `CONF_ORDERTOTAL` decimal(10,2) DEFAULT NULL,
  `CONF_GMT` int(11) NOT NULL DEFAULT '0',
  `LOCK_GMT` int(11) NOT NULL DEFAULT '0',
  `LOCK_PID` int(11) NOT NULL DEFAULT '0',
  `WAIT_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `TOTAL_COST` decimal(10,2) DEFAULT '0.00',
  `ATTEMPTS` tinyint(4) NOT NULL DEFAULT '0',
  `TXLOG` tinytext,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `UNQ_ORDER` (`MID`,`VENDOR`,`OUR_VENDOR_PO`),
  KEY `MID_2` (`MID`,`OUR_ORDERID`),
  KEY `SRCMID` (`MID`,`VENDOR`,`VENDOR_REFID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `WAREHOUSES`
--

DROP TABLE IF EXISTS `WAREHOUSES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `WAREHOUSES` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `GEO` varchar(3) NOT NULL DEFAULT '',
  `WAREHOUSE_TITLE` varchar(100) NOT NULL DEFAULT '',
  `WAREHOUSE_ZIP` varchar(12) NOT NULL DEFAULT '',
  `WAREHOUSE_CITY` varchar(30) NOT NULL DEFAULT '',
  `WAREHOUSE_STATE` varchar(2) NOT NULL DEFAULT '',
  `CREATED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `MODIFIED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `SHIPPING_LATENCY_IN_DAYS` tinyint(4) NOT NULL DEFAULT '0',
  `SHIPPING_CUTOFF_HOUR_PST` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`GEO`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `WAREHOUSE_ZONES`
--

DROP TABLE IF EXISTS `WAREHOUSE_ZONES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `WAREHOUSE_ZONES` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `GEO` varchar(3) NOT NULL DEFAULT '',
  `ZONE` varchar(3) NOT NULL DEFAULT '',
  `ZONE_TITLE` varchar(100) NOT NULL DEFAULT '',
  `ZONE_TYPE` enum('RECEIVING','UNSORTED','STANDARD','UNSTRUCTURED','BULK','STASH','VAULT','RETAIL') DEFAULT NULL,
  `ZONE_PREFERENCE` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `CREATED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `CREATED_BY` varchar(10) NOT NULL DEFAULT '',
  `YAML` text NOT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`GEO`,`ZONE`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `WAREHOUSE_ZONE_LOCATIONS`
--

DROP TABLE IF EXISTS `WAREHOUSE_ZONE_LOCATIONS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `WAREHOUSE_ZONE_LOCATIONS` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `WAREHOUSE_CODE` varchar(3) NOT NULL DEFAULT '',
  `ZONE_CODE` varchar(3) NOT NULL DEFAULT '',
  `CREATED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `CREATED_BY` varchar(10) NOT NULL DEFAULT '',
  `COUNTED_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `COUNTED_BY` varchar(10) NOT NULL DEFAULT '',
  `CHANGE_COUNT` int(11) NOT NULL DEFAULT '0',
  `CHANGE_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `ROW` varchar(3) NOT NULL DEFAULT '',
  `SHELF` varchar(3) NOT NULL DEFAULT '',
  `SLOT` varchar(3) NOT NULL DEFAULT '',
  `ACCURACY` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`WAREHOUSE_CODE`,`ZONE_CODE`,`ROW`,`SHELF`,`SLOT`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `WATCHER_SELLERIDS`
--

DROP TABLE IF EXISTS `WATCHER_SELLERIDS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `WATCHER_SELLERIDS` (
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `DST` varchar(3) DEFAULT NULL,
  `SELLERID` varchar(20) DEFAULT '',
  `SELLERNAME` varchar(50) NOT NULL DEFAULT '',
  UNIQUE KEY `UN2` (`MID`,`DST`,`SELLERID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `WHOLESALE_SCHEDULES`
--

DROP TABLE IF EXISTS `WHOLESALE_SCHEDULES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `WHOLESALE_SCHEDULES` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `MID` int(10) unsigned NOT NULL DEFAULT '0',
  `CODE` varchar(4) NOT NULL DEFAULT '',
  `CREATED_TS` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `JSON` mediumtext NOT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`CODE`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `WISHLIST`
--

DROP TABLE IF EXISTS `WISHLIST`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `WISHLIST` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `MID` int(11) NOT NULL DEFAULT '0',
  `MERCHANT` varchar(20) NOT NULL DEFAULT '',
  `CID` int(10) unsigned NOT NULL DEFAULT '0',
  `CUSTOMER` varchar(65) NOT NULL DEFAULT '',
  `SEARCHKEY1` varchar(60) NOT NULL DEFAULT '',
  `SEARCHKEY2` varchar(60) NOT NULL DEFAULT '',
  `EVENTNAME` varchar(80) NOT NULL DEFAULT '',
  `CREATED_GMT` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`CID`),
  KEY `MID_2` (`MID`,`SEARCHKEY1`),
  KEY `MID_3` (`MID`,`SEARCHKEY2`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `WISHLIST_ITEMS`
--

DROP TABLE IF EXISTS `WISHLIST_ITEMS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `WISHLIST_ITEMS` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `MID` int(11) NOT NULL DEFAULT '0',
  `MERCHANT` varchar(20) NOT NULL DEFAULT '',
  `REGISTRYID` int(11) NOT NULL DEFAULT '0',
  `STID` varchar(60) NOT NULL DEFAULT '',
  `QTY_DESIRED` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `QTY_PURCHASED` mediumint(8) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `MID` (`MID`,`REGISTRYID`,`STID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ZUSERS`
--

DROP TABLE IF EXISTS `ZUSERS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ZUSERS` (
  `MID` int(11) NOT NULL AUTO_INCREMENT,
  `USERNAME` varchar(20) NOT NULL DEFAULT '',
  `PASSWORD` varchar(50) NOT NULL DEFAULT '',
  `PASSWORD_CHANGED` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `RESELLER` varchar(12) NOT NULL DEFAULT '',
  `CREATED` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `LAST_LOGIN` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `LOGINS` int(10) unsigned NOT NULL DEFAULT '0',
  `CACHED_FLAGS` varchar(255) NOT NULL DEFAULT '',
  `EMAIL` varchar(65) NOT NULL DEFAULT '',
  `PHONE` varchar(20) NOT NULL DEFAULT '',
  `SALESPERSON` varchar(20) NOT NULL DEFAULT '',
  `TECH_CONTACT` varchar(10) NOT NULL DEFAULT '',
  `OVERDUENOTIFY_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `IPADDR` varchar(16) NOT NULL DEFAULT '',
  `DATA` mediumtext NOT NULL,
  `SUGARGUID` varchar(65) NOT NULL DEFAULT '',
  `BILL_DAY` tinyint(4) NOT NULL DEFAULT '0',
  `BILL_PACKAGE` varchar(8) NOT NULL DEFAULT '',
  `BILL_PROVISIONED` date NOT NULL DEFAULT '0000-00-00',
  `BILL_NEXTRUN` date NOT NULL DEFAULT '0000-00-00',
  `BILL_LASTEXEC` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `BILL_ORDERDATE` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `INVOICE_COUNT` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `BILL_LOCK_ID` int(10) unsigned NOT NULL DEFAULT '0',
  `BILL_LOCK_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `BILL_CUSTOMRATES` tinytext NOT NULL,
  `BILL_PRICING_REVISION` tinyint(4) NOT NULL DEFAULT '0',
  `BPP_MEMBER` tinyint(4) NOT NULL DEFAULT '0',
  `BPP_LASTCHECK_GMT` int(11) NOT NULL DEFAULT '0',
  `PUBLISHED_FILE` varchar(45) NOT NULL DEFAULT '',
  `PUBLISHED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `BPP_REVIEW_COUNT` smallint(5) unsigned NOT NULL DEFAULT '0',
  `CLUSTER` varchar(10) NOT NULL DEFAULT 'beast',
  `BS_RETURNDAYS` tinyint(4) NOT NULL DEFAULT '0',
  `TKTS_AVAILABLE` smallint(5) unsigned NOT NULL DEFAULT '0',
  `TKTS_USED` smallint(5) unsigned NOT NULL DEFAULT '0',
  `TKTS_LASTUSED_GMT` int(10) unsigned NOT NULL DEFAULT '0',
  `IS_NEWBIE` tinyint(4) NOT NULL DEFAULT '1',
  PRIMARY KEY (`MID`),
  UNIQUE KEY `USERNAME` (`USERNAME`),
  UNIQUE KEY `SUGARGUID` (`SUGARGUID`),
  KEY `RESELLER` (`RESELLER`),
  KEY `SALESPERSON` (`SALESPERSON`),
  KEY `PHONE` (`PHONE`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `nagios_status`
--

DROP TABLE IF EXISTS `nagios_status`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `nagios_status` (
  `ID` varchar(64) NOT NULL DEFAULT '',
  `LASTRUN_TS` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `NEXTRUN_TS` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  UNIQUE KEY `ID` (`ID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2014-12-15 22:35:55
