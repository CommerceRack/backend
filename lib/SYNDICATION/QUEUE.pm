package SYNDICATION::QUEUE;



#+---------------+------------------+------+-----+---------+----------------+
#| Field         | Type             | Null | Key | Default | Extra          |
#+---------------+------------------+------+-----+---------+----------------+
#| ID            | int(10) unsigned | NO   | PRI | NULL    | auto_increment |
#| USERNAME      | varchar(20)      | NO   |     | NULL    |                |
#| MID           | int(10) unsigned | NO   | MUL | 0       |                |
#| PRODUCT       | varchar(20)      | NO   |     | NULL    |                |
#| SKU           | varchar(35)      | NO   |     | NULL    |                |
#| CREATED_GMT   | int(10) unsigned | NO   |     | 0       |                |
#| PROCESSED_GMT | int(10) unsigned | NO   |     | 0       |                |
#| DST           | varchar(3)       | NO   |     | NULL    |                |
#| VERB          | varchar(10)      | NO   |     | NULL    |                |
#| ORIGIN_EVENT  | int(10) unsigned | NO   |     | 0       |                |
#+---------------+------------------+------+-----+---------+----------------+
#10 rows in set (0.01 sec)


