# Trade Concepts

## Overview
We're going to look at some trading desk concepts, we'll cover: what is a trade and how can it be modelled; what you need before booking a trade; and what happens when a trade is booked. 
 
A simple trade API will be defined as we work through the concepts covering trade booking and the basics of pricing, in the final sectionsome of the challenges of building out risk systems will be discussed.       

## What is a trade?
   * A contract to buy or sell something
   * An action that changes positions

There are lots of different types of trade, one of the simplest is cash equity - e.g. buying or selling stock in Tesla ([TSLA](https://finance.yahoo.com/quote/TSLA/)), and this is what we'll focus on.

## Goal of accurate trade modelling
   * Accurate positions
   * No unexplaned PnL
   * Reproducable PnL reports

Every trader needs to be able to _explain_ their PnL (_Profit and Loss_) - for example, did today's 5% increase in book value come from the price movement of existing positions or as a result of new trade activity (or both)?

## What do we need before booking a trade?

### _Book_ - a collection of positions
   * Trade is always executed between two parties - books represent both of those parties/accounts
   * There are different _types_ of book: _trading books_ are linked to a traders risk account/profit centre that generates revenues and PnL; _customer books_ relate to the client. There are also _sales books_, used if there's a sales desk helping with the origination of trading activity. 
   * Things of interest:
      * Book type - profit centre/customer/sales 
      * Positions
      * Instruments (shallow) - instruments taken from those positions (generally non-zero positions to filter out noise)
      * Instruments (deep): recursive instruments for each (shallow) instrument - more complex trade structures will be composed of multiple instruments
      * Price, current value of the book: `price = [sum] for each instrument {price(instrument) * instrument quantity}`

(profit centre could also be associated with a _banking book_ if securities are to be held long-term, even to maturity, the FCA has a good definition [here](https://www.handbook.fca.org.uk/handbook/BIPRU/1/2.html)) 

Example book:
```
Book {
  Denominated: "USD",
  Display Name: "US Eq Flow",
  Book ID: "123456",
  Book Type: "Profit Centre",
  Description: "Cash Equity",
  Trader: "Sammy Bruce",
  Company: "PSCO" // aka legal entity
  ...
}
```
Example operations on a book:

Details for each instrument in a book
```
instruments(book("US Eq Flow")) 
---
{ name: "TSLA" price: 541.21, ..},
{ name" "XS0629974545", price: -0.00456, ..}
...
```
Number of positions in a book
``` 
size(positions(book("US Eq Flow")))
---
{book: "US Eq Flow", size: 591}

```
Current price of entire book (i.e. all positions)
```
price(book("US Eq Flow"))
---
{book: "US Eq Flow", price: -0.003906}
```
We'll come back to the mechanics of pricing - a lot is happening to derive this value. 

## What happens when we book a trade

### Security - financial instrument 
   * Trade is on one security - e.g. cash equity trade on Tesla (TSLA)

### Position - what happens when trade is booked
   * Position = total holding of a particular type of instrument in a book
   * Positions incremented by trade actions
   * Increments can happen in any order, will result in same qty
   * Things of interest:
      * Book name
      * Instrument
      * Qty - amount of instrument held (could be -ve) 
      * `Price = Price (Instrument) * Qty`
      * Trade id's: list of contributing trades and associated qty

List positions in a book:
``` 
positions(book("US Eq Flow"))
---
{book: "US Eq Flow", instrument: "TSLA", quantity: 300, price: 162,363},
{book: "US Eq Flow", instrument: "XS0629974545", quantity: 20, price: 20.42}
...
```
Price is derived from formula: `Price(TSLA) * qty = 541.21 * 300 = 162,363`


### Trade - makes it all happen
   * Drives change in risk/pnl
   * Modifies positions in two books
   * Double entry book keeping - position effects across both books sum to zero (yes, its a bit like an accounting ledger)

Example trade:
```
Trade Details {
  Portfolio_a: "US Eq Flow", 
  Portfolio_b: "Third Rock Investments",
  Trader: "Sammy Bruce",
  Trade Type: "Sell",
  Quantity: 10
  Quantity Unit: "TSLA"
  Unit Price: 540.10
  Unit Currency: "USD"
  ...
}
```
Lets book the trade ..
```
 trade = tradeAPI::book(Trade Details)
```
.. and understand what happens - the trade modifies positions between two books, one book goes up by the quantity bought/sold, the other down by the same amount - the net effect across both books should always be zero. We'd expect the following increments (decrements) on the _position_ for this trade: 
```
Book Name: US Eq Flow
Quantity: -10
Instrument: TSLA
```
```
Book Name: Third Rock Investments
Quantity: 10
Instrument: TSLA
```  
We knew the quantity before the trade was 300:
```
{book: "US Eq Flow", instrument: "TSLA", quantity: 300, price: 162,363},
```
So we'd expect quantity to now be `300 - 10 = 290` and the price to go down also  
```
positions(book("US Eq Flow"), instrument("TSLA"))
---
Book: US Eq Flow
Instrument: TSLA
Price: 156,950
Quantity: 290

Trades: 
| Quantity | Trade Id | Counterparty           |
| -10      | 8        | Third Rock Investments |
| 200      | 7        | Blue Sky               |
| 50       | 6        | Third Rock Investments |
| -50      | 5        | Third Rock Investments |
| 100      | 4        | Third Rock Investments |
```   

In the example transaction Sammy is selling 'Third Rock Investments' 10 shares in TSLA at 540.10 each; he might be providing brokerage facilities for which he'll get a commission (not shown), alternatively he cold be acting as a market maker for a large investment bank, making a profit on the bid /offer spread, or he could be acting as both. If he already owned the stock, his profit will be difference between what he bought it for, and what it was just sold for (plus commission/spread). Buy low, sell high. If he did not own the stock, he's just done a _short trade_ and would have borrowed the stock he just sold; until he gives it back, he'll be charged a bit of interest, but more significantly, will be open to the risk the stock price will go up before he closes out the position (by buying the shares and giving them back to whoever lent them), that risk will be need to carefully managed by the trader.    

### Pricing
What is pricing? The price of an instrument is its value (in a given currency) for a specified set of _market conditions_. 

We've already seen its possible to get the price at different levels of granularity, from lowest to highest:
```
price(instrument("TSLA"))
price(position(book("US Eq Flow"), instrument("TSLA"))
price(book("US Eq Flow"))
 
```
Its really the instrument level price that does the hard work, the others are just scaling or aggregating the instrument level value

Position level:
```
price(position) = price(instrument) * position qty
``` 
Book level: 
```
price = 0.0
for position in book:
   price += price(position)
```

Changing the value of a market condition (also known as a _risk factor_) can change the value of the price. Lets look at a silly example where _jam_ is our instrument - its price is influenced by the cost of its ingredients, these are its risk factors, if they change the cost of the jam changes as well.    
```
price(jam) = price(strawberries) + price(sugar)
           = $1.02 + $0.20
           = $1.22
```
There are other factors, and the more we can model the more accurate the price will be. If some factors are missed off and they subsequently change in value, then this wont be reflected in the price, leading to inaccurate pnl and risk management/reporting.    

#### A simple pricing API

```
pricingContext = ...
price = pricingService.price(instrument("TSLA"), pricingContext)
```

`pricingModelService`

`pricingService`
`dependenciesService`
`productDataProvider` & `marketDataProvider`

```
/instrument/TSLA/
/spot/TSLA/
/dividends/TSLA/
/curve/USD/
```  


What happens inside `price`:
```
// a pricing context is supplied, it contains a valuation date and information to help resolve dependencies
context = ... 

// get the pricing model for given instrument type 
model = pricingModelService.getModel(instrument.type)

// for each risk factor defined in the model derive the market data 
// dependencies and resolve for given instrument/context 
resolvedDependencies = [] // a collection of URIs
for riskFactor in model.riskFactors:
   for marketDataDependency in dependenciesService.getMarketDataDependencies(riskFactor): 
      resolvedDependencies += dependenciesService.resolvedDependency(context, marketDataDependency)

// load market data 
marketData = marketDataProvider.load(resolvedDependencies)

// load product data
productData = productDataProvider.load(instrument)

// transform everything into something the pricing logic understands
pricingData = transform(productData, marketData)

// price 
price = pricingService.price(model, pricingData)
```
  
### Other considerations when designing a trade API
Key things are to have a _clear domain_, _functional segregation_, _business logic barriers_, and excessive _automated regression testing_.

#### Who is helping build and evolve the trade API 
Are the contributors trading and sales, strats, or developers? Trading can also be developers, in the sense that they may develop parts of the API involved in product modelling or pricing, whereas regular developers are generally working on the framework code and the build and deployment process of the application. Strats will typically help with extending and evolving products and models, booking and risk management, working alongside developers to get stuff implemented.     

#### Where is the pricing logic
Does it sit alongside the same code used for the trade API, or is it a separate 'black box' library, perhaps in a different language, that needs to be called from the trade API? Ideally the former, but the latter is a common case given a separate group often own this bit of functionality (and yes,they are normally mathematicians or engineers with a PhD), with their own codebase, build and release cycle which leads to a library dependency. Languages will vary, `C` because its perceived as fast, `python` because thats what front office loves, `java` occasionally, because thats what everyone else can code in and hey, its fast enough. The complete technology stack of the trade API will therefore be influenced by the packaging of the pricing logic.      

#### How easy is it to add new products
The crux of any successful system is its extendability, so how to avoid a lot of effort to add new instruments (and any new pricing models) is key to a successful trade API. A crystal clear domain model, well thought out and organised (risk) business logic code with appropriate re-use will help here. It should be easy to find all of the code and logic associated with a given type of product. The backbone though is a robust testing framework to ensure no pricing regressions get introduced when adding or modifying a product.  

Product evolution is just as important - existing products having new usages and different variants on behaviour. Implementing these in a way that does not introduce convoluted and bloated `if/else` code paths open to logic error is key. 

#### How are pricing models defined and maintained
When an instrument needs pricing, a model that defines the pricing methodology needs choosing to price it. The model drives the approach to pricing and the market data dependencies. As products are added and evolve, it should be easy to wire in how they are priced - in the simplest case, there may be a one-to-one mapping between the instrument type (e.g. cash equity) and how its priced, the pricing model. This will be subject to a banks internal model control, so has to be bullet proof from a process point of view.

#### How to classify an instrument type
Consistent and accurate classification of an instrument is vital to selection of the correct pricing model, and therefore accurate risk. It sounds simple, but different systems will have different views and complexities arise as products evolve and start to have different variants driven by arbitrary product attributes set in the booking systems.  

#### How are market data dependencies defined and resolved 
Market data dependencies define the data needed to price something for a given model. e.g. for our equity cash, we'll need at least the security object, current/spot price, dividends schedule, and yield curve (for discounting). Logic to identify and load market data dependencies will require both product and pricing model attributes.  It may be rules or template based (not in code) and ideally a consistent approach applied for all instrument types.     

Resolution involves loading the actual data from product and market data providers (typically an external group within the bank) - co-ordinates must be constructed to load data of the correct type and variant and for the specified valuation date. This is often a matching exercise, matching `function(pricing model, instrument type)` to a particular type of market data either sourced externally (e.g. Reuters) or saved down internally by the desk strats. Ideally the end point is a type of `URI` - a simple, easy to understand string that can be passed to the data provider. 
 
Loading all of this data can take time, especially if pricing the whole book, whilst once loaded it often has to be transformed and manipulated into a state the pricing code accepts. Unless the data is directly linked to the security (e.g. dividends), it may well be shared across different instruments - yield or funding curves on same ccy are a good example, so intelligent caching and data re-use can help reduce load times.       

#### Where is pricing done
Pricing for cash equities is simple and wont take long (we're talking milliseconds), pricing for other types of instrument like options can go into the minutes. This is where High Performance Compute (HPC) solutions need to be considered. Its a big topic, the main thing to mention here is it needs to be thought about, and will take time to implement, although the advent of cloud based HPC solutions from Azure et al is making it a lot easier. They generally involve some sort of compute grid that scales automatically with demand.   
  
#### Incremental deployment
Given risk systems are part of a complex graph of upstream and downstream system dependencies, how to avoid all-or-nothing approach to migrations and be able to incrementally roll out changes. The _microservice_ architecture pattern can be a great help here.      

#### Pricing optimisation
How to avoid things like reloading same market, or re-pricing for same underlying. Having a clearly defined calculation unit, say, a book, is a a good starting point, as this can be scanned for optimisations e.g. pull out unique set of product and market data and batch load/transform. Optimisations can also exist at the pricing model level, requiring more complex logic in how pricing requests are generated.        
    
      
### Thanks for reading 
That's all for now, thanks for reading, please do leave comments, and in the next article we'll progress onto a simple (sql) data model to help explain the concepts introduced here. 
 
                                                  
