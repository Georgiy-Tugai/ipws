PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS users
(
id INTEGER PRIMARY KEY ASC,
login varchar(255) NOT NULL UNIQUE,
salt varchar(255) NOT NULL,
password varchar(255) NOT NULL,
pwrevid int NOT NULL,
force_change_pw boolean DEFAULT 0, -- temporary password
email varchar(255),
emailok boolean NOT NULL DEFAULT 0, -- email validated
ctime datetime DEFAULT current_timestamp, -- creation time
ltime datetime, -- last login time
laddr char(45), -- last login address
name varchar(255),
locale varchar(32),
FOREIGN KEY(pwrevid) REFERENCES pwrevs(id)
);
CREATE TABLE IF NOT EXISTS pwrevs -- Password algorithm revisions
(
id INTEGER PRIMARY KEY ASC,
ctime datetime DEFAULT current_timestamp,
libver varchar(64) NOT NULL,
hash varchar(64) NOT NULL
);

CREATE TABLE IF NOT EXISTS user_groups
(
userid int NOT NULL,
groupid int NOT NULL,
FOREIGN KEY(userid) REFERENCES users(id),
FOREIGN KEY(groupid) REFERENCES groups(id)
);
CREATE TABLE IF NOT EXISTS user_prefs
(
userid int NOT NULL,
service varchar(255),
service_type varchar(255),
name varchar(255) NOT NULL,
value varchar(255) NOT NULL,
FOREIGN KEY(userid) REFERENCES users(id)
);
CREATE TABLE IF NOT EXISTS user_perms
(
userid int NOT NULL,
service varchar(255),
service_type varchar(255),
name varchar(255) NOT NULL,
value boolean DEFAULT 1,
FOREIGN KEY(userid) REFERENCES users(id)
);
CREATE TABLE IF NOT EXISTS user_blocks
(
userid INTEGER PRIMARY KEY,
blockedid int NOT NULL,
ctime datetime DEFAULT current_timestamp,
FOREIGN KEY(userid) REFERENCES users(id)
FOREIGN KEY(blockedid) REFERENCES users(id)
);
/* Watching a user */
CREATE TABLE IF NOT EXISTS user_watches
(
userid INTEGER PRIMARY KEY,
watchedid int NOT NULL,
ctime datetime DEFAULT current_timestamp,
FOREIGN KEY(userid) REFERENCES users(id),
FOREIGN KEY(watchedid) REFERENCES users(id)
);
/* Favoriting a particular object -- wiki page, blog post, blog comment... */
CREATE TABLE IF NOT EXISTS user_favorites
(
userid INTEGER PRIMARY KEY,
service varchar(255),
objectid int,
objecttype varchar(255), -- XXX: Is this the right way to go about it?
FOREIGN KEY(userid) REFERENCES users(id)
);
CREATE TABLE IF NOT EXISTS groups
(
id INTEGER PRIMARY KEY ASC,
name varchar(255) NOT NULL UNIQUE,
parentid int
);
CREATE TABLE IF NOT EXISTS group_perms
(
groupid int,
service varchar(255),
service_type varchar(255),
name varchar(255) NOT NULL,
value boolean DEFAULT 1,
FOREIGN KEY(groupid) REFERENCES groups(id)
);
CREATE TABLE IF NOT EXISTS group_prefs
(
groupid int NOT NULL,
service varchar(255),
service_type varchar(255),
name varchar(255) NOT NULL,
value varchar(255) NOT NULL,
FOREIGN KEY(groupid) REFERENCES groups(id)
);
CREATE TABLE IF NOT EXISTS user_bans
(
id INTEGER PRIMARY KEY ASC,
userid int, -- user who was banned
modid int, -- moderator who banned
userip char(45), -- IPv6
modip char(45),
ipban int, -- link to IP ban ID, if any
ctime datetime DEFAULT current_timestamp,
etime datetime, -- expiry/end time
reason longtext,
service varchar(255),
FOREIGN KEY(userid) REFERENCES users(id),
FOREIGN KEY(modid) REFERENCES users(id),
FOREIGN KEY(ipban) REFERENCES ip_bans(id)
);
CREATE TABLE IF NOT EXISTS ip_bans
(
id INTEGER PRIMARY KEY ASC,
ip varchar(64), -- FIXME: make IP ban format more user friendly and/or flexible?
ctime datetime DEFAULT current_timestamp,
etime datetime,
reason longtext
);
CREATE TABLE IF NOT EXISTS reports
(
id INTEGER PRIMARY KEY ASC,
service varchar(255),
objectid int,
objecttype varchar(255), -- XXX: Is this the right way to go about it?
userid int NOT NULL, -- reporter
subjectid int, -- reportee
rcontent longtext, -- This might need CHARACTER SET UTF8 on mysql.
icontent longtext, -- This is the content of the ITEM REPORTED, at the time of reporting.
summary varchar(255),
response longtext, -- This might need CHARACTER SET UTF8 on mysql.
ctime datetime DEFAULT current_timestamp,      -- reported at
rtime datetime,      -- responded to at
ubanid int,
FOREIGN KEY(userid) REFERENCES users(id),
FOREIGN KEY(subjectid) REFERENCES users(id),
FOREIGN KEY(ubanid) REFERENCES user_bans(id)
);
