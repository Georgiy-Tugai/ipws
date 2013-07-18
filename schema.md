Database schema
================

Core
----

CREATE TABLE IF NOT EXISTS Users
(
ID int,
Login varchar(255),
Password char(512),
Email varchar(255),
EmailOK boolean, /* email validated */
CTime int, /* creation time */
LTime int, /* last login time */
LAddr varchar(255), /* last login address */
Name varchar(255)
);

CREATE TABLE IF NOT EXISTS Groups
(
ID int,
Name varchar(255)
);
CREATE TABLE IF NOT EXISTS User_Groups
(
UserID int,
GroupID int
);

CREATE TABLE IF NOT EXISTS Permissions
(
ID int,
Service varchar(255), /* Wiki, Blog, etc. */
Name varchar(255)
);
CREATE TABLE IF NOT EXISTS User_Permissions
(
UserID int,
PermID int
);
CREATE TABLE IF NOT EXISTS Group_Permissions
(
GroupID int,
PermID int
);

CREATE TABLE IF NOT EXISTS User_Bans
(
ID int,
UserID int, /* user who was banned */
ModID int, /* moderator who banned */
UserIP varchar(255),
ModIP varchar(255),
IPBan int, /* link to IP ban ID, if any */
CTime int,
ETime int, /* expiry/end time */
Reason longtext,
Service varchar(255)
);
CREATE TABLE IF NOT EXISTS IP_Bans
(
ID int,
IP varchar(255),
Mask varchar(255), /* FIXME: make IP ban format more user friendly and/or flexible? */
CTime int,
ETime int,
Reason longtext
);

Blog
----

CREATE TABLE IF NOT EXISTS Posts
(
ID int,
UserID int,
Title varchar(255),
Content longtext /* XXX: This might need CHARACTER SET UTF8 on mysql. */
CTime int,
ETime int
);
CREATE TABLE IF NOT EXISTS Comments
(
ID int,
PostID int,
UserID int,
Content longtext, /* This might need CHARACTER SET UTF8 on mysql. */
CTime int,
ETime int
);
CREATE TABLE IF NOT EXISTS Comment_Reports
(
ID int,
CommentID int, /* reported */
UserID int,     /* by */
RContent longtext, /* This might need CHARACTER SET UTF8 on mysql. */
IContent longtext, /* This is the content of the ITEM REPORTED, at the time of reporting. */
CTime int      /* creation time */
Response longtext, /* This might need CHARACTER SET UTF8 on mysql. */
RTime int      /* reported at */
);
