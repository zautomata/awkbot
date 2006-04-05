-- MySQL dump 9.11
--
-- Host: localhost    Database: awkbot
-- ------------------------------------------------------
-- Server version	4.0.23_Debian-1-log

--
-- Table structure for table `karma`
--

CREATE TABLE `karma` (
  `nick` varchar(100) NOT NULL default '',
  `karma` int(11) default NULL,
  PRIMARY KEY  (`nick`)
) TYPE=MyISAM;

--
-- Dumping data for table `karma`
--

INSERT INTO `karma` VALUES ('tag',5);
INSERT INTO `karma` VALUES ('awkbot',0);
INSERT INTO `karma` VALUES ('xmb',1);
INSERT INTO `karma` VALUES ('paul',11);

--
-- Table structure for table `qna`
--

CREATE TABLE `qna` (
  `question` varchar(100) default NULL,
  `answer` varchar(255) default NULL
) TYPE=MyISAM;

--
-- Dumping data for table `qna`
--

INSERT INTO `qna` VALUES ('is','is I use it\r');
INSERT INTO `qna` VALUES ('paul','the man');
INSERT INTO `qna` VALUES ('tag','the author');
INSERT INTO `qna` VALUES ('awk','the tool used to write me');
INSERT INTO `qna` VALUES ('mysql','the RDBM I use, just because tag is too lazy to write a pg.awk too.');
INSERT INTO `qna` VALUES ('mysql_quote','something tag really needs to add to mysql.awk');
INSERT INTO `qna` VALUES ('xmb','the guy with incompatible libraries');
INSERT INTO `qna` VALUES ('mysql.awk','http://www.blisted.org/svn/modules/mysql.awk/ until tag writes documentation');

