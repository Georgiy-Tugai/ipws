CREATE TABLE IF NOT EXISTS users
(
id INTEGER PRIMARY KEY ASC,
login varchar(255) NOT NULL,
password char(512) NOT NULL,
email varchar(255),
emailok boolean NOT NULL DEFAULT 0, -- email validated
ctime int unsigned NOT NULL, -- creation time
ltime int unsigned, -- last login time
laddr char(45), -- last login address
name varchar(255),
locale varchar(32)
);

CREATE TABLE IF NOT EXISTS groups
(
id INTEGER PRIMARY KEY ASC,
name varchar(255) NOT NULL,
parentid int
);
CREATE TABLE IF NOT EXISTS user_groups
(
userid int NOT NULL,
groupid int NOT NULL
);
CREATE TABLE IF NOT EXISTS user_prefs
(
userid int,
service varchar(255),
name varchar(255) NOT NULL,
value varchar(255) NOT NULL
);
CREATE TABLE IF NOT EXISTS user_perms
(
userid int,
service varchar(255),
name varchar(255) NOT NULL
);
CREATE TABLE IF NOT EXISTS user_blocks
(
userid INTEGER PRIMARY KEY,
blockedid int,
ctime int
);
/* Watching a user */
CREATE TABLE IF NOT EXISTS user_watches
(
userid INTEGER PRIMARY KEY,
watchedid int,
ctime int
);
/* Favoriting a particular object -- wiki page, blog post, blog comment... */
CREATE TABLE IF NOT EXISTS user_favorites
(
user_id INTEGER PRIMARY KEY,
service varchar(255),
objectid int,
objecttype varchar(255) -- XXX: Is this the right way to go about it?
);
CREATE TABLE IF NOT EXISTS group_perms
(
groupid int,
service varchar(255),
name varchar(255) NOT NULL
);

CREATE TABLE IF NOT EXISTS user_bans
(
id INTEGER PRIMARY KEY ASC,
userid int, -- user who was banned
modid int, -- moderator who banned
userip char(45), -- IPv6
modip char(45),
ipban int, -- link to IP ban ID, if any
ctime int,
etime int, -- expiry/end time
reason longtext,
service varchar(255)
);
CREATE TABLE IF NOT EXISTS ip_bans
(
id INTEGER PRIMARY KEY ASC,
ip varchar(64), -- FIXME: make IP ban format more user friendly and/or flexible?
ctime int,
etime int,
reason longtext
);
CREATE TABLE IF NOT EXISTS reports
(
id INTEGER PRIMARY KEY ASC,
service varchar(255),
objectid int,
objecttype varchar(255), -- XXX: Is this the right way to go about it?
userid int, -- reporter
rcontent longtext, -- This might need CHARACTER SET UTF8 on mysql.
icontent longtext, -- This is the content of the ITEM REPORTED, at the time of reporting.
summary varchar(255),
response longtext, -- This might need CHARACTER SET UTF8 on mysql.
ctime int,      -- reported at
rtime int,      -- responded to at
uban_id int
);
