# Risk System Concepts - Trade Booking & Pricing

## Overview
This article will give you a flavour of how a risk system works, looking at trading desk concepts including: 
* what is a trade and how can it be modelled 
* what you need before booking a trade
* what happens when a trade is booked 
 
A simple trade API is evolved, starting with trade booking and then pricing, examples and pseudo code are provided to help understand concepts, and some of the challenges of building out risk systems are discussed.       

## What is a trade?
A trade is: 
   * A contract to buy or sell something
   * An action that changes positions

There are lots of different _types_ of trade, one of the simplest is _cash equity_ - e.g. buying or selling stock in Tesla ([TSLA.OQ](https://www.reuters.com/companies/TSLA.OQ)), and this is what we'll focus on.

The thing been traded is the _security_, an alternative term is _instrument_, both can be used interchangeably. 

## Goal of accurate trade modelling
_Trade modelling_ is a term that captures the process of what happens when a trade is booked, pricing and risk management, with the objectives of: 
   * Accurate positions
   * No unexplaned PnL
   * Re-producable PnL reports

Every trader needs to be able to _explain_ their PnL (_Profit and Loss_) - for example, did today's 5% increase in portfolio value come from the price movement of existing positions or as a result of new trade activity (or both)?

## What do we need before booking a trade?
   
### Book 
A trade is always executed between two parties - and a _book_ represent both of those parties/accounts, a book will have following attributes:
 * Name and description
 * Book type
   * _trading book_ linked to a traders risk account/profit centre that generates revenues and PnL
   * _customer book_ relate to the client. 
   * _sales book_ is used if there's a sales desk helping with the origination of trading activity
   *  _banking book_ used if securities are to be held long-term, even to maturity (FCA has a good definition [here](https://www.handbook.fca.org.uk/handbook/BIPRU/1/2.html))  
 * Trader or desk head responsible for the book
 * Company (legal entity) - a distinct ring-fenced part of the business often based on geography with different entities for US , EMEA and APAC but may be broken down further
 * Denominated - currency to report in - likely to be that of country associated with legal entity.

Another name for book could be _portfolio_
 
Example book:
```
{ "book": {
    "id": ": "123456",
    "displayName": "US Eq Flow",
    "description": "Cash Equity",
    "type": "Profit Centre",    
    "trader": "Sammy Bruce",
    "company": "PSCO", // aka legal entity
    "denominated": "USD",
  ...
}}
```
We'll come back to operations on a book after looking at some other concepts

## What happens when a trade is booked
   
### Position 
A _position_ is the total holding (quantity) of a particular security in a book; positions incremented by trade actions - those increments can happen in any order, they will always result in same quantity. A position will have:
 * Book
 * Instrument
 * Quantity - amount of instrument held (could be -ve) 
 * Price, derived as `Price = Price (Instrument) * Qty`
 * Trade list: contributing trades and associated quantity

List positions in a book:
``` 
book("US Eq Flow").positions()
---
{ "book": "US Eq Flow", "instrument": "TSLA", "quantity:" 300, "price": 162,363},
{ "book": "US Eq Flow", "instrument": "XS0629974545", "quantity": 20, "price": 20.42}
...
```
Price for first position is derived from formula: `Price(TSLA) * qty = 541.21 * 300 = 162,363`, how the instrument price is derived will be covered in a bit.

### Trade 
Makes it all happen:
   * Drives change in risk/pnl
   * Modifies positions in two books
   * Double entry book keeping - position effects across both books sum to zero (yes, its a bit like an accounting ledger)

Imagine a trader has agreed to sell 10 shares in TSLA to their client 'Third Rock' at 540.10 USD (the price they have both agreed on), and the trade is booked against the 'US Eq Flow' risk book, the trade details would look something like this:

```
{ "tradeDetails": {
  "book_a": "US Eq Flow", 
  "book_b": "Third Rock",
  "trader": "Sammy Bruce",
  "tradeType": "Sell",
  "quantity": 10
  "quantityUnit": "TSLA"
  "unitPrice": 540.10
  "unitCurrency": "USD"
  ...
}}
```  
  
Lets book the trade ..
```
 trade = tradeService.book(tradeDetails)
```
.. and understand what happens - the trade modifies positions between two books, one book incremented and the other decremented by the quantity bought/sold - the net effect across both books should always be zero. We'd expect the following increments (decrements) on the _position_ for this trade: 
```
Book Name: US Eq Flow
Quantity: -10
Instrument: TSLA
```
```
Book Name: Third Rock
Quantity: 10
Instrument: TSLA
```  
We knew the quantity before the trade was 300:
```
{ "book": "US Eq Flow", "instrument": "TSLA", "quantity": 300, "price": 162,363 },
```
So we'd expect quantity to now be `300 - 10 = 290` and the price to go down also  
```
position(book("US Eq Flow"), instrument("TSLA"))
---
{ "book": "US Eq Flow", "instrument": "TSLA", "quantity": 290, "price": 156,950 
  "trades" [
     { "id:" 8, "quantity": -10, "counterparty": "Third Rock"},
     { "id:" 7, "quantity": 200, "counterparty": "Blue Sky"},
     { "id:" 6, "quantity": 50, "counterparty": "Third Rock"},
     { "id:" 5, "quantity": -50, "counterparty": "Third Rock"},
     { "id:" 4, "quantity": 100, "counterparty": "Third Rock"},
  ]
}
```   

Trade we just did is 1st row (trade ID 8). 

Sidebar: Sammy might be providing brokerage facilities for which he'll get a commission (not shown), alternatively he cold be acting as a market maker for a large investment bank, making a profit on the bid /offer spread, or he could be acting as both. If he already owned the stock, his profit will be difference between what he bought it for, and what it was just sold for (plus commission/spread). Buy low, sell high. If he did not own the stock, he's just done a _short trade_ and would have borrowed the stock he just sold; until he gives it back, he'll be charged a bit of interest, but more significantly, will be open to the risk the stock price will go up before he closes out the position (by buying the shares and giving them back to whoever lent them), that risk will be need to carefully managed by the trader.    

### Book operations
From a book, it should be possible to derive: 
 * Positions - a book is essentially a collection of positions
 * Instruments (shallow) - instruments taken from those positions (generally non-zero quantity to filter out noise)
 * Instruments (deep): recursive instruments for each (shallow) instrument - more complex trade structures will be composed of multiple instruments
 * Price, current value of the book: `price = [sum] for each instrument {price(instrument) * instrument quantity}`

Retrieve instruments in a book
```
book("US Eq Flow").instruments() 
---
{ "name": "TSLA", "price": 541.21, ..},
{ "name" "XS0629974545", "price": -0.00456, ..}
...
```
Number of positions in a book
``` 
book("US Eq Flow").positions().size()
---
{ "book": "US Eq Flow", "size": 591}
```
Current price of entire book (i.e. all positions)
```
book("US Eq Flow").price()
---
{ "book": "US Eq Flow", price: -0.003906}
```
The next section looks into the mechanics of pricing - a lot is happening to derive this value. 


### Pricing
In the context of a trade, the price is the agreed value of the instrument being traded at that point in time, but how was that price derived? The price of an instrument is its value (in a given currency) for a specified set of _market conditions_, changing the value of a market condition (also known as a _risk factor_) will result in a change to the price. Lets look at a silly example where _jam_ is our instrument - its price is influenced by the cost of its ingredients, these are its risk factors, if they change the cost of the jam changes as well.    
```
price(jam) = price(strawberries) + price(sugar)
           = $1.02 + $0.20
           = $1.22
```
If sugar went up by 2 cents the price of jam would go up to $1.24. 

There are other factors, and the more that can modelled the more accurate the price will be. If some factors are missed off and they subsequently change in value, then this wont be reflected in the price, leading to inaccurate pnl and risk management/reporting.    

How would a cash equity instrument be priced? If price was for a trading desk the trader would probably just need the current _spot price_ (market price at which a security is bought or sold for immediate payment and delivery) available from a market data provider like Reuters - [TSLA.OQ](https://www.reuters.com/companies/TSLA.OQ), which would suffice for accurate hedging. Another approach is Net Present Value (NPV) which looks at future dividends and cashflows, discounting them back to derive the PV. To make the example a bit more interesting we'll assume this is the model in use.

#### A simple pricing API
A pricing service provides top level API to price things: instruments, positions, and books. It requires a  _pricing context_ which contains the valuation date, information to help resolve dependencies and other parameters to control pricing. 
```
context = ... 
price = pricingService.price(instrument("TSLA"), pricingContext)
```
What happens inside call to price `price`? There's a few collaborating _services_ and _data providers_: 
* `modelService` - provide the model to price given instrument with, the model is used to derive the risk factors 
* `dependencyService` - determine market data dependencies for given risk factor and resolve dependency using pricing context
* `productDataProvider` & `marketDataProvider` - load product and market data for given set of resolved dependencies
* `pricer` contains the core pricing code  
 
Somewhere in the `modelService` the following instrument type to model mapping will be defined:
```
cash equity --> model (Equity Net Present Value)
``` 
(we've gone for simple 1-to-1 mapping, but it could be something more sophisticated like a rules based approach based on multiple attributes)

What sort of risk factors would be derived from this model? They would include: spot; future cashflows (dividends/non dividend); yield curve (to discount cashflows). 

What might the `dependencyService` resolved market data dependencies look like? Something human readable but understood by a system generally works well, so something like:     

```
/instrument/TSLA/21-04-2020
/spot/TSLA/21-04-2020
/dividends/TSLA/21-04-2020
/cashflows/TSLA/21-04-2020
/curve/USD/21-04-2020
```  
If these look a little bit like the _path_ part of a _URI_ then thats intentional, it should be possible to prefix a protocol and hostname to get the full URI to pass to the `productDataProvider` & `marketDataProvider` to load data. 
 
The format of the product and market data could be json, xml, or something else, based on what the data provider supports, and not necessarily what is required for pricing, so will need transforming into a representation understood by the `pricingService`. The pricing service should provide an API to help construct the relevant representation - it may, for example, have its own object model that needs hydrating and provide a series of factories to create.   

Finally the transformed data will be passed to the `pricingService` to perform the actual pricing, where some sort of mathematical computations as defined in the pricing model will be executed against the data to derive the price.    
  
Putting it all together `pricingService.price(instrument)` will look something like this:
```
// get the pricing model for given instrument type 
model = modelService.getModel(instrument.type)

// for each risk factor defined in the model derive the market data dependencies and resolve for given context/instrument 
resolvedDependencies = [] // a collection of URIs
for riskFactor in model.riskFactors:
   for marketDataDependency in dependencyService.getMarketDataDependencies(riskFactor): 
      resolvedDependencies += marketDataDependency.resolved(context, instrument)

// load market data 
marketData = marketDataProvider.load(resolvedDependencies)

// load product data
productData = productDataProvider.load(instrument)

// transform everything into something the pricing logic understands
pricingData = transform(productData, marketData)

// price 
price = pricer.price(context, model, pricingData)
```

It should be possible to price at different levels of granularity:
```
instrument("TSLA").price()
position(book("US Eq Flow"), instrument("TSLA").price()
book("US Eq Flow").price()
 ```
Both pricing a position and a book just need to call into this instrument level price code, with scaling applied with the position quantity.  

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

### Other considerations when designing a trade API
Key things are to have a _clear domain_, _functional segregation_, _business logic barriers_, and excessive _automated regression testing_.

#### Who is helping build and evolve the trade API? 
Are the contributors trading and sales, strats, or developers? Trading can also be developers, in the sense that they may develop parts of the API involved in product modelling or pricing, whereas regular developers are generally working on the framework code and the build and deployment process of the application. Strats will typically help with extending and evolving products and models, booking and risk management, working alongside developers to get stuff implemented.     

#### Where is the pricing logic?
Does it sit alongside the same code used for the trade API, or is it a separate 'black box' library, perhaps in a different language, that needs to be called from the trade API? Ideally the former, but the latter is a common case given a separate group often own this bit of functionality (and yes,they are normally mathematicians or engineers with a PhD), with their own codebase, build and release cycle which leads to a library dependency. Languages will vary, `C` because its perceived as fast, `python` because thats what front office loves, `java` occasionally, because thats what everyone else can code in and hey, its fast enough. The complete technology stack of the trade API will therefore be influenced by the packaging of the pricing logic.      

#### How easy is it to add new products?
The crux of any successful system is its extendability, so how to avoid a lot of effort to add new instruments (and any new pricing models) is key to a successful trade API. A crystal clear domain model, well thought out and organised (risk) business logic code with appropriate re-use will help here. It should be easy to find all of the code and logic associated with a given type of product. The backbone though is a robust testing framework to ensure no pricing regressions get introduced when adding or modifying a product.  

Product evolution is just as important - existing products having new usages and different variants on behaviour. Implementing these in a way that does not introduce convoluted and bloated `if/else` code paths open to logic error is key. 

#### How are pricing models defined and maintained?
When an instrument needs pricing, a model that defines the pricing methodology needs choosing to price it. The model drives the approach to pricing and the market data dependencies. As products are added and evolve, it should be easy to wire in how they are priced - in the simplest case, there may be a one-to-one mapping between the instrument type (e.g. cash equity) and how its priced, the pricing model. This will be subject to a banks internal model control, so has to be bullet proof from a process point of view.

#### How to classify an instrument type?
Consistent and accurate classification of an instrument is vital to selection of the correct pricing model, and therefore accurate risk. It sounds simple, but different systems will have different views and complexities arise as products evolve and start to have different variants driven by arbitrary product attributes set in the booking systems.  

#### How are market data dependencies identified, resolved, and loaded? 
Market data dependencies define the data needed to price something for a given model. e.g. for equity cash we defined the security object, current/spot price, dividends schedule, and yield curve (for discounting). Logic to identify and load market data dependencies will require both product and pricing model attributes.  It may be rules or template based (not in code) and ideally a consistent approach applied for all instrument types.     

Resolution involves identifying the actual data to load from product and market data providers (typically an external group within the bank) for a given product and model. Co-ordinates must be constructed to load data of the correct type and variant and for the specified valuation date. This is often a matching exercise, matching `function(pricing model, instrument type)` to a particular type of market data either sourced externally (e.g. Reuters) or saved down internally by the desk strats. Ideally the end point is a type of `URI` - a simple, easy to understand string that can be passed to the data provider. 
 
Loading all of this data can take time, especially if pricing the whole book, whilst once loaded it often has to be transformed and manipulated into a state the pricing code accepts. Unless the data is directly linked to the security (e.g. dividends), it may well be shared across different instruments - yield or funding curves on same ccy are a good example, so intelligent caching and data re-use can help reduce load times.       

#### Where is pricing done?
Pricing for cash equities is simple and wont take long (we're talking milliseconds), pricing for other types of instrument like options can go into the minutes. This is where High Performance Compute (HPC) solutions need to be considered. Its a big topic, the main thing to mention here is it needs to be thought about, and will take time to implement, although the advent of cloud based HPC solutions from Azure et al is making it a lot easier. They generally involve some sort of compute grid that scales automatically with demand.   
  
#### Incremental deployment
Given risk systems are part of a complex graph of upstream and downstream system dependencies, how to avoid all-or-nothing approach to migrations and be able to incrementally roll out changes. The _microservice_ architecture pattern can be a great help here.      

#### Pricing optimisation
How to avoid things like reloading same market, or re-pricing for same underlying. Having a clearly defined calculation unit, say, a book, is a a good starting point, as this can be scanned for optimisations e.g. pull out unique set of product and market data and batch load/transform. Optimisations can also exist at the pricing model level, requiring more complex logic in how pricing requests are generated.        

Partial re-pricing can also help avoid executing a full re-price if just one or two risk factors have been modified. The risk factors form a type of pricing graph (although most times its just a tree), and re-computation only needs to be appplied to the parent nodes of the risk factors that have changed. In the following exmample, if only risk factor 'e' is modified, then only 'e', 'c', and 'price' need to be recomputed.

```
           +---+    +---+
      +--->+ a +--->+ b |
      |    +---+    +---+
+-----+-+
| price |
+-----+-+
      |    +---+    +---+
      +--->+ c +--->+ d |
           +--++    +---+
              |     +---+
              +---->+ e |
                    +---+
```   
(generated with [asciiflow](http://asciiflow.com))    
 
### Recap 
Alright, we made it to the end, we've covered what happens when a trade is booked, some of the key concepts like a _book_, _position_, _trade_, and _instrument_; how to price an instrument with some pseudo code for a simple pricing service, and discussed some of the other challenges building out these types of system.   

In the next article we'll look at the relational database schema for a trading application and some example queries that could be run for different use cases. A simple way to run and test queries locally using an embedded in-memory database is presented, followed by a look at Object Relational Mapping (ORM).    

Thanks for reading and please do leave comments! 
 
                                                  
