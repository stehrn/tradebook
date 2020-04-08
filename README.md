# Trade Concepts

## Overview
We're going to look at some trading desk concepts, we'll cover: what is a trade and how can it be modelled; what you need before booking a trade; and what happens when a trade is booked. This is based on first hand knowledge of front-office trading systems, there's nothing proprietary here - given most trading systems are based on common sense designs, there's generally no big surprises once you've seen one. The differences are generally in how they've been implemented and integrated into other parts of the booking process, front to back, and how risk and pnl are calculated. 

A simple trade API will be defined as we work through the concepts, and discussed in a bit more detail in the final section.      

## What is a trade?
   * A contract to buy or sell something
   * An action that changes positions

A trade could be a cash equity - e.g. stock in Tesla (TSLA), or an equity index or Exchange Traded Fund (ETF) that tracks the S&P 500; a debt instrument like a bond; a commodity; fx; or something more sophisticated like a equity derivative

## Goal of accurate trade modelling
   * Accurate positions
   * No unexplaned PnL
   * Reproducable PnL reports

Every trader needs to be able to _explain_ their PnL (_Profit and Loss_) - for example, did today's 5% increase in book value come from the price movement of existing positions or as a result of new trade activity (or both)?

## What do we need before booking a trade?

### _Book_ - a collection of positions
   * Trade always executed between two parties. Books represent both of those parties/accounts
   * Can have trading risk account books linked to a traders profit centre and customer books (a profit centre is a business unit or department within an organization that generates revenues and PnL)
   * Things of interest:
      * Book type - profit centre, customer, sales (both of previous)
      * Positions
      * Children - tradable instruments taken from those positions (generally non-zero positions to filter out noise)
      * Leaves: recursive instruments for each child
      * Price, current value of the book: `price = [sum] for each leaf {price(leaf) * leaf quantity}`

Profit centre could be associated with either a _trading book_ (securities are not intended to be held until maturity) or _banking book_ (securities held long-term), the FCA has a good definition [here](https://www.handbook.fca.org.uk/handbook/BIPRU/1/2.html)  

Example book:
```
Book {
  Denominated: "USD",
  Display Name: "MKEIT01",
  Book ID: "123456",
  Book Type: "Profit Centre",
  Description: "Cash Equity",
  Trader: "Sammy Bruce",
  Company: "PSCO" // aka legal entity
  ...
}
```
Example operations on a book to show:

Price for each instrument in a book
```
Leaves("MKEIT01") 
---
Instrument A: 0.000654
Instrument B: -0.00456
...
```
Number of positions in a book
``` 
Size(Positions("MKEIT01"))
---
591
```

Current price of a book
```
Price("MKEIT01")
---
-0.003906
```
## What happens when we book a trade

### Security - financial instrument 
   * Trade is on one security - e.g. Tesla (TSLA)

### Position - what happens when trade is booked
   * Position = total holding of a particular type of instrument in a book
   * Positions incremented by trade actions
   * Increments can happen in any order, will result in same qty
   * Things of interest:
      * Book name
      * Qty unit == security
      * Qty
      * `Price = Price (Qty unit) * Qty`
      * Trade id's: list of contributing trades and associated qty

### Trade - makes it all happen
   * Drives change in risk/pnl
   * Modifies positions in two books
   * Double entry book keeping - position effects across both books sum to zero (yes, its a bit like an accounting ledger)

Example trade:
```
Trade Details {
  Portfolio1: "MKEIT01", 
  Portfolio2: "Third Rock Investments",
  Trader: "Sammy Bruce",
  Trade Type: "Sell",
  // tradeable info
  Quantity: 10
  Quantity Unit: "TSLA"
  Payment Unit: "USD"
  Unit Price: 540.10
  ...
}
```
A trade API may look like this:
```
 Trade = TradeAPI::book(Trade Details)
```
The following position changes would be expected:
```
Book: TODO.
```
 
In reality, the risk book would trade with a sales book.  

In our example transaction, trader Sammy is selling 'Third Rock Investments' 10 shares in TSLA at 540.10 each; Sammy might be providing brokerage facilities for which he'll get a commission (not shown), alternatively he cold be acting as a market maker for a large investment bank, making a profit on the bid /offer spread, or he could be acting as both.
  
After booking the trade the price associated with this instrument in the trading book will change by (10*540.10 = 5401.00 USD)

  
If he already owned the stock, his profit will be difference between what he bought it for, and what it was just sold for (plus any commission) Buy low, sell high. If he did not own the stock, he's just done a _short trade_ and at settlement would have borrowed the stock he just sold; until he gives it back, he'll be charged a bit of interest, but more significantly, will be open to the risk the stock price will go up before he closes out the short position by buying the shares and giving them back to whoever lent them - that risk will be need to carefully managed by our trader.    
  
  
### Other considerations when designing a trade API
Key things are to have a _clear domain_, _functional segregation_, _business logic barriers_, and excessive _automated regression testing_.

#### Who is helping build and evolve the trade API 
Are the contributors trading and sales, strats, or developers? Trading can also be developers, in the sense that they may develop parts of the API involved in product modelling or pricing, whereas regular developers are generally working on the framework code and the build and deployment of the application. Strats will typically help with extending and evolving products and models, booking and risk management, working alongside developers to get stuff implemented.     

#### Where is the pricing logic
Does it sit alongside the same code used for the trade API, or is it a separately 'black box' library, perhaps in a different language, that needs to be called form the trade API? Ideally the former, but the latter is a common case given a separate group often own this bit of functionality (and yes,they are normally mathematicians or engineers with a PhD), with their own codebase, build and release cycle which leads to a library dependency. Languages will vary, `C` because its perceived as fast, `python` because thats what front office loves, `java` occasionally, because thats what everyone else can code in and hey, its fast enough. The complete technology stack of the trade API will therefore be influenced by the packaging of the pricing logic.      

#### How easy is it to add new products
The crux of any decent system is its extendability, so how to avoid a lot of effort to add new instruments (and any new pricing models) is key to a successful trade API. A crystal clear domain model, well thought out and organised (risk) business logic code with appropriate re-use will help here. It should be easy to find all of the code and logic associated with a given type of product. The backbone though is a robust testing framework to ensure no pricing regressions get introduced.  

Product evolution is just as important - existing products having new usages and different variants on behaviour. Implementing these in a way that does not introduce convoluted and bloated `if/else` code paths open to logic error is key. 

#### How are pricing models defined and maintained
When an instrument needs pricing, a model that defines the pricing methodology needs choosing to price it. The model drives the approach to pricing and the market data dependencies. As products are added and evolve, it should be easy to wire in how they are priced - in the simplest case, there may be a one-to-one mapping between the instrument type (e.g. cash equity) and how its priced, the pricing model. This will be subject to a banks internal model control, so has to be bullet proof from a process point of view.

#### How to classify an instrument type
Consistent and accurate classification of an instrument is vital to selection of the correct pricing model, and therefore accurate risk. It sounds simple, but different systems will have different views and complexities arise as products evolve and start ot have different variants driven by arbitrary product attributes set in the booking system.  

#### How are market data dependencies defined and resolved 
Market data dependencies are the things we need to price something for a given model. e.g. for our equity cash, we'll need at least the security object, current/spot price, dividends schedule, and yield curve (for discounting). Logic to identify and load market data dependencies will require both product and pricing model attributes.  It may be rules or template based (not in code) and ideally a consistent approach applied for all instrument types.     

Resolution involves loading the actual data from product and market data providers (typically an external group within the bank) - co-ordinates must be constructed to load data of the correct type and variant and for the specified valuation date. This is often a matching exercise, matching `function(pricing model, instrument type)` to a particular type of market data either sourced externally or saved down internally by the desk strats. Ideally the end point is a type of `URI`, a simple, easy to understand string that can be passed to the external data provider. 
 
Loading all of this data can take time, especially if pricing the whole book, whilst once loaded it often has to be transformed and manipulated into a state acceptable for pricing. Unless the data is directly linked to the security (e.g. dividends), it may well be shared across different instruments - yield or funding curves on same ccy are a good example, so intelligent caching and data re-use can help reduce load times.       

#### Where is pricing done
Pricing for cash equities is simple and wont take long (we're talking ms'), pricing for other types of instrument like options can go into the minutes. This is where High Performance Compute (HPC) solutions need to be considered. Its a big topic, the main thing to mention here is it needs to be thought about, and will take time to implement, although the advent of cloud based HPC solutions from Azure et al is making it a lot easier. They generally involve some sort of compute grid that scales automatically with demand.   
  
#### Incremental deployment
Given risk systems are part of a complex graph of upstream and downstream system dependencies, how to avoid all-or-nothing approach to migrations and be able to incrementally roll out changes. The _microservice_ architecture pattern can be a great help here.      

#### Pricing optimisation
How to avoid things like reloading same market, or re-pricing for same underlying. Having a clearly defined calculation unit, say, a book, is a a good starting point, as this can be scanned for optimisations e.g. pull out unique set of product and market data and batch load/transform. Optimisations can also exist at the pricing model level, requiring more complex logic in how pricing requests are generated.        
    
      
### Thanks for reading 
That's all for now, thanks for reading, please do leave comments, and in the next article we'll progress onto a simple (sql) data model to help explain the concepts introduced here. 
 
                                                  
