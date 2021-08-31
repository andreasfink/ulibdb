# ulibdb

ulibdb is a database client driver which allows universal queries to various types of databases:

- MySQL
- MariaDB
- Postgresql 
- Redis

It uses ulib as its base and depends on mysqlclient/mariadbclient to build but not to deploy (statically linked).
Under MacOS you should install the two pkg files before buidling.
