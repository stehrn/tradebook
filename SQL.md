# Overview 
This article will look at the relational database schema for a trading application and some example queries that could be run for different use cases. A simple way to run and test queries locally using an embedded in-memory database is presented, and we finish with a quick look at alternatives to hand crafted sql through the use of Object Relational Mapping (ORM) .    

# Domain Model
From the previous article, we defined three key parts to the domain:
* _Book_ - represent the parties/accounts involved in a trade, and is essentially a collection of positions
* _Trade_ - modifies positions in two books
* _Position_ - total holding of a particular type of instrument in a book

We should add to that an _Instrument_ which is the thing been traded (e.g. stock in Tesla (TSLA)) 


# Schema 
Lets define the minimal schema to demonstrate what happens when a trade is booked.

The `book` table will have a type (e.g. profit centre, customer), denominated currency, name of trader (likely the desk head in charge, can be null if its a customer book), and legal entity - a distinct ring-fenced part of the business (e.g. US versus EMEA). Once set up, this data wont generally change that often.
```sql
CREATE TABLE book (
  id INT AUTO_INCREMENT  PRIMARY KEY,
  book_type VARCHAR(20) NOT NULL,
  denominated CHAR(3) NOT NULL,
  display_name VARCHAR(50) NOT NULL,
  trader VARCHAR(50) NULL,
  entity CHAR(4) NOT NULL
  ...
);
```

An `instrument` is the thing been traded, it has a name, type plus a bunch of attributes that will be used for pricing purposes; there will also be industry standard identifiers for the security (e.g. ISIN, SEDOL)
```sql
CREATE TABLE instrument (
  id INT AUTO_INCREMENT  PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  type VARCHAR(100) NOT NULL
  ...
);
```

The `trade` table records the two parties involved in the trade (via a reference to a book) and the trader themselves, the direction of the trade - whether it was a buy (`B`) or sell (`S`), the quantity traded, and the details on the instrument including its price and base currency. 

```sql
CREATE TABLE trade (
  id INT AUTO_INCREMENT  PRIMARY KEY,
  portfolio_a INT NOT NULL,
  portfolio_b INT NOT NULL,
  trader VARCHAR(100) NOT NULL,
  trade_type CHAR(1) NOT NULL,  
  quantity INT NOT NULL,
  instrument_id  INT NOT NULL,
  unit_price DECIMAL(10,5),
  unit_ccy CHAR(3) NOT NULL,
  FOREIGN KEY (portfolio_a) REFERENCES book(id),
  FOREIGN KEY (portfolio_b) REFERENCES book(id),
  FOREIGN KEY (instrument_id) REFERENCES instrument(id)
);
```
(other possible names for this table - `order` or `transaction`?)

The position table holds the _total_ holdings of an instrument in a book at a particular point in time. It could be tempting to use the trade table to derive the same aggregate view of the open position quantity, in practice its a bit more efficient to store position separately and avoid the trade table queries (even with well thought out indexes). Bear in mind this introduces the risk the trade and position tables don't match if an edit is done in one table but not the other. It should, however, always be possible to regenerate the position table from the trade table.      
```sql
CREATE TABLE position (
  id INT AUTO_INCREMENT PRIMARY KEY,
  book_id INT NOT NULL,
  instrument_id  INT NOT NULL,
  quantity INT NOT NULL,
  FOREIGN KEY (book_id) REFERENCES book(id),
  FOREIGN KEY (instrument_id) REFERENCES instrument(id)
);
```

This in the final schema and relationships:

![Database Schema](img/schema.png)

(created using [dbdiagram.io](http://dbdiagram.io))
 
# What happens when a trade is booked?

Lets continue the example from the first article where we had this trade:
```
Trade Details {
  Portfolio1: "MKEIT01", 
  Portfolio2: "Third Rock Investments",
  Trader: "Sammy Bruce",
  Trade Type: "Sell",
  Quantity: 10
  Quantity Unit: "TSLA"
  Unit Price: 540.10
  Unit Currency: "USD"
  ...
}
```
Lets assume ops have set up our books and the product team have set up the TSLA security (our entity is made up, the denomination is USD so it would probably be a US business line)

`select * from book where entity = 'GRUS';`

|ID |BOOK_TYPE  	|DENOMINATED  	|DISPLAY_NAME  	        |TRADER  	 |ENTITY  |
|---|---------------|---------------|-----------------------|------------|--------|
|5	|Profit Centre	|USD	        |MKEIT01	            |Sammy Bruce |EUCE    |
|6	|Client Book	|USD	        |Third Rock Investments	|null	     |EUCE    |

`select * from instrument where NAME = 'TSLA'`

|ID|NAME|
|---|---|
|5|TSLA|  
 (yes, light on detail)

From this trade we'd expect one new row in the `trade` table as per the above trade details with an insert to capture:
```
Portfolio1: "MKEIT01", 
Portfolio2: "Third Rock Investments",
Trader: "Sammy Bruce",
Trade Type: "Sell",
Quantity: 10
Quantity Unit: "TSLA"
Unit Price: 540.10
Unit Currency: "USD"
``` 
sql (portfolio id's are from the book table):
```sql
INSERT INTO trade (portfolio_a, portfolio_b, trader, trade_type, quantity, instrument_id, unit_price, unit_ccy) VALUES
  (5, 6, 'Sammy Bruce', 'B', 10, 5, 540.10, 'USD')
``` 

A trade modifies positions in two books, one book goes up by the quantity bought/sold, the other down by the same amount - the net effect across both books should always be zero. We' expect the following increments (decrements) on the `position` table for our trade: 
```
Book Name: MKEIT01
Quantity: -10
Instrument: TSLA
```
```
Book Name: Third Rock Investments
Quantity: 10
Instrument: TSLA
```  
  
sql: 
```sql
update position 
set quantity      = quantity - 10 
where book_id     = 5 // risk book 
and instrument_id = 5 // TSLA
```
```sql
update position 
set quantity      = quantity + 10 
where book_id     = 6 // client book 
and instrument_id = 5 // TSLA
```
What just happened? Running the above query blew away what our position was previously, we can no longer go back in time, which is a big problem given the many use cases in a trading and risk system that require data as-of a given business date. How do we fix this? The next section explains ...   

## A note on dates
You'll notice for simplicity none of the tables contain dates - in reality, they will, and its worth commenting on _bi-temporal chaining_ whereby all changes to a database are tracked along two dimensions:
* Business Time - when the change actually occurred in the world
* Processing Time - when the change actually was recorded in the database

This is a common requirement for end-of-day reporting and useful for support analysis.

Its implemented through the addition of four columns:

* `FROM_Z` and `THRU_Z` to track the validity of the row along the business-time dimension
*  `IN_Z` and`OUT_Z` to track the validity of the row along the processing-time dimension

Coming back to the position example, lets look at how to increment position by 10 on client book - assume we start with a position of 100 for given book/instrument:  

|BOOK_ID  |INSTRUMENT_ID  |QUANTITY   |FROM_Z|THRU_Z  |IN_Z  |OUT_Z   |
|--------|------|--------|------|--------|------|--------|
|6|5|100|Apr 20|Infinity|Apr 20|Infinity|

`IN_Z` is Apr 20 which tells us trade executed on this date, `OUT_Z` Infinity which tells us this row is latest state of the position 

First invalidate (aka chain out) the old row by setting `OUT_Z` to the current business date (pretend today is Apr 23): 

|BOOK_ID  |INSTRUMENT_ID  |QUANTITY   |FROM_Z|THRU_Z  |IN_Z  |OUT_Z   |
|--------|------|--------|------|--------|------|--------|
|6|5|100|Apr 20|Infinity|Apr 20|Apr 23|


Next insert a new row with previous position + 10, 

|BOOK_ID  |INSTRUMENT_ID  |QUANTITY   |FROM_Z|THRU_Z  |IN_Z  |OUT_Z   |
|--------|------|--------|------|--------|------|--------|
|6|5|110|Apr 23|Infinity|Apr 23|Infinity|

These table entries tell us:
* From Apr 20 to Apr 23, position = 100 
* From Apr 23 to Infinity, position = 110 (previous position + 10)
 
To get the _current_ position (i.e `OUT_Z=Infinity`) as-of current business date: 
```sql
select * from position 
where book_id = 6
and instrument_id = 5 
and FROM_Z <= '2020-04-23 00:00:00.000' 
and THRU_Z > '2020-04-23 00:00:00.000' 
and OUT_Z = '9999-12-01 23:59:00.000'
```
To get position as-of a point in the past, lets say before the increment came in (Apr 21): 
```sql
select * from position 
where book_id = 6
and instrument_id = 5 
and FROM_Z <= '2020-04-21 00:00:00.000' 
and THRU_Z > '2020-04-21 00:00:00.000'
and IN_Z <= '2020-04-21 00:00:00.000' 
and OUT_Z > '2020-04-21 00:00:00.000'
```

Check out this very good [goldmansachs](https://goldmansachs.github.io/reladomo-kata/reladomo-tour-docs/tour-guide.html#N408B5) tutorial for more details (including how `THRU_Z` is used to capture same business day changes).   

# Sample queries
In all cases portfolio_a is trader book and portfolio_b is client book

TODO; put in some for above.

## Find the current position of the firm 
How long and short it is on each of the securities it trades. The position table makes this simple, just need to decide whether to filter out zero positions 
```
SELECT i.name          AS instrument, 
       SUM(t.quantity) AS position 
FROM   trade t, 
       position p, 
       instrument i
WHERE  t.instrument_id = p.instrument_id 
AND    t.portfolio_a = p.book_id
AND    p.instrument_id = i.id     
GROUP  BY ( instrument ) 
HAVING position != 0 
ORDER  BY position DESC 
```

## Find the ten securities to which the firm has the greatest exposure (either long or short)
Lets take exposure here to mean amount, we dont apply fx conversion,
we'll get away with it for test data as everything in GBP, otherwise we've be mixing up ccy's. One way we could implement this is to have a FX table to load fx rate for given ccy pair and date.
```
SELECT TOP 10 i.name                         AS instrument, 
       SUM(t.quantity * t.unit_price)        AS exposure 
FROM   trade t, 
       position p, 
       instrument i 
WHERE  t.instrument_id = p.instrument_id 
AND    t.portfolio_a = p.book_id
AND    p.instrument_id = i.id 
GROUP  BY ( i.name ) 
ORDER  BY ABS(SUM(t.quantity * t.unit_price)) DESC 
```

## Query those tables to find the trader with the highest aggregate exposure among their top five securities.
This is a non trivial query that makes use of [ROW_NUMBER](https://www.sqltutorial.org/sql-window-functions/sql-row_number/) and [PARTITION](https://www.sqltutorial.org/sql-window-functions/sql-partition-by/): to find the nth highest value per group
 
* the PARTITION BY clause distributes the trades by (trading) portfolio
* the ORDER BY clause sorts the trades in each portfolio by exposure
* the ROW_NUMBER() assigns each row a sequential integer number, it resets the number when the portfolio changes

```
SELECT TOP 1 b.trader, 
       SUM(aggregate.exposure) AS exposure 
FROM   (SELECT portfolio_a                                   AS trader, 
               instrument_id, 
               SUM(quantity * unit_price)                    AS exposure, 
               ROW_NUMBER() 
                 OVER( 
                   PARTITION BY portfolio_a 
                   ORDER BY SUM(quantity * unit_price) DESC) AS rank 
        FROM   trade 
        GROUP  BY portfolio_a, 
                  instrument_id 
        ORDER  BY trader, 
                  rank) aggregate, 
       book b 
WHERE  aggregate.rank <= 5 
AND    b.id = aggregate.trader 
GROUP  BY aggregate.trader 
ORDER  BY exposure DESC 
```

# Using embedded H2 database inside browser to run sql queries
A simple [Spring Boot](https://spring.io/projects/spring-boot) app using an embedded in memory [H2 database](https://www.h2database.com/html/main.html) has been created to test the schema and queries (based on this great [baeldung tutorial](https://www.baeldung.com/spring-boot-h2-database))

To use, check out [tradebook](https://github.com/stehrn/tradebook) GitHub repo and: 

   * Run [SpringBootH2Application](src/main/java/com/stehnik/tradebook/SpringBootH2Application.java) 
   * Go to http://localhost:8080/h2-console (check _JDBC URL_ is `jdbc:h2:mem:mydb`, and password intentionally left blank)

You should see this:

TODO

The output from above was obtained from running queries in the browser.

# Adding a Java ORM layer
So how do we use what we've looked at so far in a Java application? We started with a database schema and  could use [JDBC](https://docs.oracle.com/javase/tutorial/jdbc/basics/index.html) to execute the sql defined above, and this may be fine for some teams who have decent sql experience and are happy with the tight coupling to the persistence layer.  

Many teams try and avoid hand crafting and maintaining sql queries for specific database vendors, relying instead on Object Relational Mapping (ORM). This lets us deal in Java objects (typically POJOs), database specifics are abstracted away, and different data providers can be plugged in with a bit of configuration, no sql needs to be written.   
 
There are lots of ORM libraries out there, we'll look at [jOOQ Object Oriented Querying (jooq)](https://www.jooq.org) which generates Java objects from an existing table schema and will let us build type-safe SQL queries through a fluent API.
 
ORMs let you do it the other way round as well - if you have a set of Java objects with relevant annotations a database schema can be auto-generate.    
 
The maven project [pom](pom.xml) contains a profile to auto-generate Java source using jooq - it  points to the schema file and the package name and directory for generated source. To create source run:
```
mvn generate-sources -P jooq
```
This will create a bit of framework code, Data Access Objects (DAOs), and simple POJOs for book, instrument, position, and trade, e.g.:
```java
/**
 * This class is generated by jOOQ.
 */
@Generated(
    value = {
        "http://www.jooq.org",
        "jOOQ version:3.11.11"
    },
    comments = "This class is generated by jOOQ"
)
@SuppressWarnings({ "all", "unchecked", "rawtypes" })
public class Book implements Serializable {

    private static final long serialVersionUID = 1793092507;

    private Integer id;
    private String  bookType;
    private String  denominated;
    private String  displayName;
    private String  trader;
    private String  entity;

...
```
Wiring jooq into Spring Boot is easy (see [Spring Boot documentation](https://docs.spring.io/spring-boot/docs/current/reference/html/spring-boot-features.html#boot-features-jooq)). 

To see it in use in the demo app, go to `http://localhost:8080/listPositions`, which is running this code:

```java
Configuration jooqConfiguration = <autowired by Spring Boot>
PositionDao positionDao = new PositionDao(jooqConfiguration);
List<Position> positions = positionDao.findAll();
```
(see [TradebookController](src/main/java/com/stehnik/tradebook/TradebookController.java))

# Recap
TODO 
