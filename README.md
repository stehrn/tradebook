# Overview
Design some tables to model a small trading desk. There are a few traders who each have a book, they maintain positions on a number of 
securities, and execute trades against those positions. 
   * Query those tables to find the current position of the firm (how long and short it is on each of the securities it trades). 
   * Query those tables to find the ten securities to which the firm has the greatest exposure (either long or short). 
   * Query those tables to find the trader with the highest aggregate exposure among their top five securities. 

# Using embedded H2 database 
   * Run SpringBootH2Application, 
   * Go to http://localhost:8080/h2-console (check _JDBC URL_ is `jdbc:h2:mem:mydb`)

   
# Some terminology

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
   * Can have trading risk account books linked to a profit centre and customer books
   * Things of interest:
      * Book type - profit centre, customer, sales (both of previous)
      * Positions
      * Children - tradables taken from those positions (non-zero positions)
      * Leaves: recursive tradables for each child
      * Price: [sum] for each leaf {price(leaf) * leaf quantity}

Example book
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

### Group - one business or desk
   * Book has one group
   * Trader has one or more groups they can trade to
   * Tie entitlements to groups

```
Group {
  Group Name: "CORPBOND",
   Group Type: "Trader",
   Group Book Type: "Profit Centre",
   Location: "LDN",
   Holiday Calendar: "UK",
   Business Name: "Corp Bonds",
   ...
}
```

### Tradeable - financial instrument (aka security)
   * Trade is on one tradable
   * Tradable should be able to price itself
   * Knows what actions cna be done
   * Immutable

### Position - what happens when trade is booked
   * Position = total holding of a tradable in a book
   * Positions incremented by trade actions
   * Increments can happen in any order, will result in same qty
   * Things of interest:
      * Book name
      * Qty unit == tradable
      * Qty
      * Price = Price (Qty unit) * Qty
      * Trade id's: lis tof contributing trades and associated qty

### Trade - makes it all happen
   * Drives change in risk/pnl
   * Modifies position sin two books
   * Double entry book keeping - position effects across both books sum to zero

```
Trade Info {
  // trade info
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

Trade = @TradeAPI::add(Trade Info)

```