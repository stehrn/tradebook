# Overview 
This article will look at the relational database schema for a trading application and some example queries that could be run for different use cases. A simple way to run and test queries locally using an embedded in-memory database is also presented, and we finish with a quick look at alternatives to hand crafted sql through the use of Object Relational Mapping (ORM)     

# Domain Model
From the previous article, we defined three key parts to the domain:
* _Book_ - represent the parties/accounts involved in a trade, and is essentially a collection of positions
* _Trade_ - modifies positions in two books
* _Position_ - total holding of a particular type of instrument in a book

We should add to that an _Instrument_ which is the thing been traded (e.g. stock in Tesla (TSLA)) 


# Schema 
Lets define the minimal schema to demonstrate what happens when a trade is booked.

The book table will have a type (e.g. profit centre, customer), denominated currency, name of trader (can be null, e.g. if its a customer book), and legal entity. Once set up, this data wont generally change that often.
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

An instrument is the thing been traded, it has a name and type (the type is important, as will be used to derive the pricing model), plus a bunch of attributes that will be used for pricing purposes. There will also be industry standard identifiers for the security (e.g. ISIN, SEDOL)
```sql
CREATE TABLE instrument (
  id INT AUTO_INCREMENT  PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  type VARCHAR(100) NOT NULL
  ...
);
```

The trade table is where most of the action takes place, it has to record the instrument been traded, whether buy/sell, quantity (e.g. number of shares), currency, and unit price (price of instrument at point of trade) 
```sql
CREATE TABLE trade (
  id INT AUTO_INCREMENT  PRIMARY KEY,
  portfolio_a INT NOT NULL,
  portfolio_b INT NOT NULL,
  instrument_id  INT NOT NULL,
  trade_type CHAR(1) NOT NULL,
  quantity INT NOT NULL,
  payment_unit CHAR(3) NOT NULL,
  unit_price DECIMAL(10,5),
  FOREIGN KEY (portfolio_a) REFERENCES book(id),
  FOREIGN KEY (portfolio_b) REFERENCES book(id),
  FOREIGN KEY (instrument_id) REFERENCES instrument(id)
);
```

The position table maintains a relationship between a book and an instrument
```sql
CREATE TABLE position (
  id INT AUTO_INCREMENT PRIMARY KEY,
  book_id INT NOT NULL,
  instrument_id  INT NOT NULL,
  denominated CHAR(3) NOT NULL,
  FOREIGN KEY (book_id) REFERENCES book(id),
  FOREIGN KEY (instrument_id) REFERENCES instrument(id)
);
```

# Sample queries
In all cases portfolio_a is trader book and portfolio_b is client book

## Find the current position of the firm 
How long and short it is on each of the securities it trades. This is a join across all three tables, filtering out zero positions 
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
## A note on dates
You'll notice for simplicity none of the tables contain dates - in reality, they will, and its worth commenting on _bi-temporal chaining_ whereby all changes to a database are tracked along two dimensions:
* Business Time - when the change actually occurred in the world
* Processing Time - when the change actually was recorded in the database

This is a common requirement for end-of-day reporting and useful for support analysis.

Its implemented through the addition of four columns:

* `FROM_Z` and `THRU_Z` to track the validity of the row along the business-time dimension
*  `IN_Z` and`OUT_Z` to track the validity of the row along the processing-time dimension

Check out this very good [goldmansachs](https://goldmansachs.github.io/reladomo-kata/reladomo-tour-docs/tour-guide.html#N408B5) tutorial for more details.   

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


