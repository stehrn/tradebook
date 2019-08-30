# Overview
Design some tables to model a small trading desk. There are a few traders who each have a book, they maintain positions on a number of 
securities, and execute trades against those positions. 

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
   * Can have trading risk account books linked to a traders profit centre and customer books
   * Things of interest:
      * Book type - profit centre, customer, sales (both of previous)
      * Positions
      * Children - tradables taken from those positions (non-zero positions)
      * Leaves: recursive tradables for each child
      * Price: [sum] for each leaf {price(leaf) * leaf quantity}

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
Example operations:
```
Leaves("ATEMK01") 
---
Instrument A: 0.000654
Instrument B: -0.00456

Size(Positions("ATEMK01"))
---
798

Price("ATEMK01")
---
-0.003906
```

### Security - financial instrument 
   * Trade is on one security

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
TODO
```
```


# Using embedded H2 database inside browser to run above sql
   * Run [SpringBootH2Application](src/main/java/com/stehnik/tradebook/SpringBootH2Application.java) 
   * Go to http://localhost:8080/h2-console (check _JDBC URL_ is `jdbc:h2:mem:mydb`)

#  Links to some of references used
   * https://www.baeldung.com/spring-boot-h2-database
