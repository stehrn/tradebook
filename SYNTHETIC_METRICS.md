# Using Synthetic Metrics to Help Reduce the Cost of Your Hardware Infrastructure

This blog explores the use of *synthetics metrics* to help reduce the runnings costs of application platforms. We’ll discuss the infrastructure management process, which metrics are important and why, and how they can be combined into a synthetic metric to help with decision making.

It covers some of the things an engineer building out and supporting an application needs to be mindful of, including CPU and memory characteristics to look out for when an application is running.

# The problem with change
What do you do with a server that costs a lot of money and does not do much work? It sounds like the start of a (bad) joke, the answer, obviously, is to understand why its not doing much, and if there’s no good reason, save your cost centre some money and get rid of it. 

Why would you find yourself in this situation? It could be you’ve evolved your architecture and migrated onto a managed service platform like Azure, leaving behind your old servers, or perhaps the engineering team has changed size and you now have some ideal dev blades. 

There are many reasons why servers become under-utilised, all result from the fact that things don’t stand still, business strategies, technology and teams all change, and any const sensitive team (everyone?) should be actively tracking the impact if change on our hardware infrastructure. 

#### *Sidebar - Physical servers*
In an ideal situation, teams don’t actually own their own hardware, rather everything is managed by someone else and they pay for what they use. Containerisation and the introduction of cloud platforms have helped teams move in this direction.

#### *Sidebar - Virtual Machines (VMs)*
A VM offers some sort of middle ground between owning a physical server and running on a manage platform like Openshift. You don’t own the physical server, but rather pay for the VM thats hosted on that server, multiple VMs will run on the same server thereby reducing costs, which is why most will prefer a VM over physical. 

# Infrastructure Management Process
So what would a process for managing and maintaining infrastructure look like? It would involve a review process of the running costs of application platforms, the following questions would be posed for each host:
* Do we need it
* Can we reduce 
* Can we downgrade - e.g. use fewer CPUs or less memory
* Can we consolidate - migrate applications onto same hardware

The whole process will involve a diverse group of people including portfolio owners, ITAO’s, lead engineers, with information bubbling up to CIO-1 and ultimately CIO. 

A range of metrics will already be used to help decision making, synthetic metrics should help quickly identity areas of focus. 

## Remind me what my servers where?
You’re starting point is a decent inventory of all of your servers, including metadata on things like: Model, OS, Core Count, Memory, and people information like ITAO and CIO-1. 

# Quantifying the problem
So what are the main things of interest when managing application infrastructure, and if there’s a large number of servers how best to prioritise things?

## Cost
The cost of a server is one of the most significant things to consider when maintaining infrastructure, with higher cost servers requiring more scrutiny to determine if the higher cost is justified or not. 

*High cost bad, low cost good*

## Server Resources
In the context of managing infrastructure we want to find out which applications are not making full use of the available server resources, this comes down to finding out how 'busy' an application is.

### CPU
CPU usage is typically divided into two categories: *user time* and *system time*. User time is the % of time the system is executing application code, whereas system time is spent in the kernel. If an application is doing a lot of I/O, the kernel will execute the code to, say, read a file from the filesystem. A high performing app will drive the CPU usage as high as possible for as short a time as possible. The CPU number is an average over an interval like 5 seconds, and is an indicator of how effectively a process is using the CPU.

*High CPU good, low CPU bad*

#### When is the CPU idle?
If you have one or more applications running on a host, and the CPU is idle, there are a number of possible reasons, the application may:
* Be blocked internally on a lock or some other point of synchronisation
* Be waiting for something  - like a response from a database call or a thread from a thread pool to execute some work
* Have nothing to do

Its up to application developers to address the first two items through changes to the application code and configuration. If the application can run faster, then the average CPU usage will go up. If the application is batch based, then we’d expect it to try and drive the CPU as high as possible; however, if its driven by external requests, possibly client based (e.g. a web server), then there may be long periods where CPU usage is low because there really is nothing to do, and then sudden moments of bursty activity where the CPU spikes.

#### Is (near continuous) 100% CPU good? 
It depends - when CPU is consistently high other server metrics should be  checked at this point to verify that the applications running on the server are not performing poorly, these include:

* CPU run queue - monitor the number of threads that could be run (not blocked by I/O or sleeping) if a CPU is available. If there are more threads than available CPU, then performance will degrade. A rule of thumb is to ensure: `run queue ~< number of CPUs`
* Context switching - actually linked to the run queue size, if too many application threads are contending for a slice of the CPU then there’s going to be a lot of context switching as the OS swaps application threads in and out, an expensive operation which can slow down the performance of an application
* Load averages - means the CPU load and what is actively demanding CPU time

(`vmstat` will provide the first two metrics, top the last)

Only certain classes of application will consistently utilise near 100% of the CPU for extended periods of time, and they would generally be some sort of platform service - a heavily used pricing service is a good example, where the goal would really be to keep the CPU as hot as possible for as long as those requests continue, although even here there could be lulls during out of market hours (unless we were really clever and leveraged the same services across multiple regions, and assuming the greater network latency was not an issue)

For Java specific applications, teams should also be monitoring Garbage Collector (GC) logs as (depending on how its been configured) GC cycles can consume a lot of CPU, and it may be high because the JVM is thrashing trying to clear down objects from the heap to avoid an out of memory (OOM) exception!

#### CPU and core count
Is 50% average CPU usage on a 1 core machine any different to 50% CPU usage on a 2 core machine? Yes! In very simple terms, 50% usage on 2 CPU is the same as 100% usage on a 1 CPU machine, so the core count of a server matters when interpreting the average CPU usage and a bit of scaling should be applied to get the “actual” (real?) usage:
```
actual CPU usage = average CPU * core count
```
### Memory
If we’re paying for a server that has a decent amount of RAM then we’d hope its been used by the applications running on the server.

Its worth noting high memory does not necessarily mean an application is busy doing stuff - it just means its reserved a large amout of memory, perhaps getting ready for when it does need to do a lot of stuff, this is typicaly of larger Java applications which might fix the heap at, say, 120GB; so the take-away here is to use this metric alongside other metrics like CPU usage.  

*High memory good, low memory bad*
 
#### Is (near continuous) 100% memory good?
If no swapping is taking place then it should be fine. If, however, the server is running low on physical memory and has to do a lot of paging, then best case an application slows down a bit, worse case, the OS decides to kill the process holding onto memory. 

### Disc Usage
Some applications do a lot of reading and writing to disk, some don’t, so a low IO is not necessarily a bad thing. As IO increases though, it does become relevant, since it represents a measure of application busyness not captured via user CPU. If an application is doing a lot of IO, we want to factor this in somehow, the obvious way is to take into account kernel time via system CPU usage.

### Network Usage
If you have a lot of distributed apps they will make use of the network, which implies we can monitor network traffic to infer server busyness, but what could we infer without further context on the application(s) running on the server? 

Is a low level of network traffic a negative indicator? It’s impossible to tell on its own, the server may, for example, be hosting a web-queue-worker application that reads a relatively small number of requests over the network but then spends are large amount of time crunching through each request, driving up CPU usage, and then returns a relatively small response - in this case, network traffic is low, but not a bad thing. On the other hand, a server running a content delivery network (CDN) would be expected to be sending much more data over the network. 

*Without more context, making use of this metric is tricky*  

### Sourcing server metrics
You’re going to want the following metrics:

| Metric        | Description           | Calculation  | (Suggested) Frequency  |
| ------------- |:---------------------:|:------------:| ----------------------:|
|CPU usage (%). |Percentage of CPU time spent running user applications and system functions|Add the average User, System, and Wait values|1 minute|
|CPU number (cores)|Total number of CPU cores|Read from `/proc/cpuinfo`|60 minutes|
|mem usage (%)|Percentage of virtual memory used|Read from `/proc/meminfo`|1 minute|
(Assumed Linux host)

Real CPU usage can be derived as:
```
   (Real) CPU Usage (%) =  CPU usage (%) * CPU number
```
How these are sourced depends on your setup, best case agents have been installed on the host to collect metrics into some sort of central repository which can be queried manually or programatically; Nimsoft probes are not uncommon, and prometheus and grafana are a decent  tool pair to provide reporting capabilities.

TODO: link to prometheus and grafana. 

#### Percentiles and the problem with averages
What does 50% average CPU usage tell you? That on average, across a sampling period of, say, 24 hours, the CPU’s where 50% busy - but that could mean they were 50% for 100% of the time, or 100% busy for 50% of the time, or some variant in-between -the average does not tell us much about how the CPU usage was distributed over time.

There is where percentiles can help - lets start with the 90th percentile CPU usage - if 90% of the time the CPU is less than 50% and 10% of the time CPU usage is great than 50%, then 50% is the 90th percentile CPU usage. The same principal applies to any other percentile measure, common ones are 50, 75, 90, 95, and 99.

One difference between the average and the percentile is the way outliers or extreme values affect the result - large outliers have a large impact on the average, since they are included as part of the average calculation. A host burst of very high CPU activity can pull the average up significantly, but assuming the burst was less than 5% of the total time, it would not impact the 95 percentile. 

Here is an example where the 95 percentile is ~1% and the average is ~30% due to a continued high (near 100%) CPU usage for a short duration, whilst the rest of the time it was near zero. 

TODO: chart

Both metrics are clearly relevant, but they are telling us different things.

## Decommission Status
Decommissioning a bit of kit can be a long process, and it will often take time before a server drops off from your view. In the interim, you want to be sure that little, if anything, is running on the server as the decommission date approaches. If you still have high CPU one day before decommissioning then you may be in for a surprise when an SA pulls the plug on the machine.

So for hosts which are been decommissioned, things are reversed: 

*High cpu & memory bad, low cpu & memory good*
  
# Putting everything together

## Synthetic metrics
A synthetic metric (or indicator) is a value derived form the combination of other metrics, the metrics themselves are measuring some property or feature of something you are interested in understanding more about.

We’ve already seen there are multiple metrics to the problem space related to:
* Cost
* Resource Utilisation: CPU and memory
* Decomission status

A synthetic metric can combine these together through the use of a weighted equation of the form:

```
synthetic metric = (cost * cost weight)
                 + (1 - cpu percentile * cpu percentile weight)
                 + (1 - cpu average * cpu average weight)
                 + (1 - mem percentile * mem percentile weight)
                 + (cpu average * (1 / number of dates to retirement)) * retirement date
```

*High synthetic weight bad, low synthetic weight good*

Note how we take the inverse (1 - x) in cases where high is good, and this is just one of many variants of the metric possible.
