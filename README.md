# Overview
Design some tables to model a small trading desk. There are a few traders who each have a book, they maintain positions on a number of securities, and execute trades against those positions. 

# Some terminology
A review of trading terminology to help with understanding schemas, and some pseudo code to help understand relationships and cardinality

## What is a trade?
   * A contract to buy or sell something
   * An action that changes positions

## Goal of accurate trade modelling
   * Accurate positions
   * No unexplaned PnL
   * Reproducable PnL reports

## What do we need before booking a trade?

### Book - a collection of positions
   * Trade always executed between two parties. Books represent both of those parties/accounts
   * Can have trading risk account books linked to a traders profit centre, customer and sales books
   * Things of interest:
      * Book type - profit centre, customer, sales (both of previous)
      * Positions - all positions for which `book(position) == book`
      * Children - tradables taken from those positions (non-zero positions)
      * Leaves: recursive tradables for each child
      * Price: `[sum] for each leaf: (price(leaf) * leaf quantity)`

Example book:
```
Book {
  Denominated: "USD",
  Display Name: "ATEMK01",
  Book ID: "1244356",
  Book Type: "Profit Centre",
  Description: "Corp Bond",
  Trader: "Nik Stehr",
  Company: "PSCO" // aka legal entity
  ...
}
```
Similar for sales and client books.

Example operations on a book:

Get the leaves (tradables)
```
Leaves("ATEMK01") 
---
Instrument A: 0.000654
Instrument B: -0.00456
...
```
Position information
```
Size(Positions("ATEMK01"))
---
798
```
Price:
```
Price("ATEMK01")
---
-0.003906
```

### Group
* A group is a business or desk
* Book has one group
* Traders can trade to one or more groups, with user entitlements to tades and positions derived from groups
* Notable properties:
   * Children: profit centres for the group
   * Group portfolio - used by traders to aggregate risk
   * strat/technology owner
   * trade db, holiday calendar etc

### Security (aka tradable) - financial instrument 
   * Trade is on one security (moved it form one book to another)
   * An idealised tradeable: 
      * can price itself
      * defines support trade types (buy/sell, expire etc)
      * is immutable
      * has blessed (and passing) price and trade tests to allow trading

XXX

### Position - what happens when trade is booked
   * Position = total holding of a tradable in a book
   * Positions incremented by trade actions
   * Increments can happen in any order, will result in same qty
   * Things of interest:
      * Book name
      * Qty unit == security
      * Qty
      * Price = Price (Qty unit) * Qty
      * Trade id's: list of contributing trades and associated qty

### Trade - makes it all happen
   * Drives change in risk/pnl
   * Modifies positions in two books
   * Double entry book keeping - position effects across both books sum to zero

```
Trade Info {
  Portfolio1: "ATEMK01",
  Portfolio2: "Client A",
  Trader: "Nik Stehr",
  Trade Type: "Sell",
  // tradeable info
  Expiration Date: "18Dec2019"
  Quantity: 10
  Quantity Unit: "XS0104440986"
  Payment Unit: "USD"
  Unit Price: 2.3292
}
```

# Schema 
see [data.sql](src/main/resources/data.sql)

Note some [TODO](TODO.md) 

# Sample queries
Been a while since I wrote any sql, a modern ORM would provide a compelling alternative

In all cases portfolio_a i trader book (portfolio_b is client book)

## Find the current position of the firm (how long and short it is on each of the securities it trades).
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

## Find the ten securities to which the firm has the greatest exposure (either long or short). 
Lets take exposure here to mean amount, there's an open TODO to apply fx conversion,
we'll get away with it for test data as everything in GBP, otherwise we've be mixing up ccy's

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
Wow, this is a trickier query, ROW_NUMBER and PARTITION are the key to the solution. 
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

# Using embedded H2 database inside browser to run above sql
   * Run [SpringBootH2Application](src/main/java/com/stehnik/tradebook/SpringBootH2Application.java) 
   * Go to http://localhost:8080/h2-console (check _JDBC URL_ is `jdbc:h2:mem:mydb`)

# Adding a Java ORM layer
Quick spike to use [jooq](https://www.jooq.org) to generate Java objects from sql schema defined in [data.sql](src/main/resources/data.sql). 
[pom](pom.xml) contains maven profile to generate, run:
```
mvn generate-sources -P jooq
```
When [SpringBootH2Application](src/main/java/com/stehnik/tradebook/SpringBootH2Application.java)
 is running get list of positions from http://localhost:8080/listPositions

(see [TradebookController](src/main/java/com/stehnik/tradebook/TradebookController.java))

I'm not overly keen on jooq, tried using API to replicate some of above sql and its heavy going. As an exercise worth looking into how this could be done a bit more easily/what other frameworks are out there (hibernate still any good?) 

#  Links to some of references used
   * https://www.baeldung.com/spring-boot-h2-database
   * https://docs.spring.io/spring-boot/docs/current/reference/html/boot-features-sql.html#boot-features-jooq

