# TVS Stores Order Builder & Inventory Syncer

## description
TVS Stores uses different applications for facilitation of purchase orders and inventory management.
The use case is the following:

### Purchase Order Automation
1. Every week, orders for all the franchises will be created with the past 7 days of sales aggregated. The order will also have any products that the shop doesn't have any inventory for.
2. The warehouse manager will review the purchase order, add / remove certain items, and then go to the custom field
in Lightspeed to check the custom checkbox "ready_for_gecko".
3. I have a job that scans all purchase orders for a flag of "ready_for_gecko" and an unchecked box of "gecko_completed". I process that order and create a purchase order in Shopify. I then update the custom field for gecko_completed, so I don't process that order again.
4. Shopify has an integration with Quickbooks commerce that's managed by Quickbooks, so any purchase order created in Shopify is automatically created in Quickbooks Commerce, where TVS wants the orders to be.

### Inventory Syncing
In order for the mappings to work between Shopify and Lightspeed, we needed a single source of truth that contained references to the shopify and lightspeed product record. That information is housed in the BaseProduct model. When I map the purchase order from Lightspeed into a Sales Order in Shopify, I pluck the BaseRecords in question, get the Shopify IDs, and then I can build out the order lines. To keep this working:

- I have hooks (hooks_controller) on record lifecycle events like creation / deletion, and I will update my database. The TVS team is aware of how to create products in the manner that get picked up by hooks.

### Watch Outs
1. Lightspeed does not allow you to create purchase orders with an array of line items. Each line item needs to be created via API call individually. This makes the creation process take about 4 hours. This runs on Monday night at 12AM EST and goes to about 4AM.
2. Lightspeed has rate limits that were adjusted for TVS to handle this process. They have a leaky bucket rate limiting so in the event the TVS team would like to keep the Lightspeed POS, there are better ways of handling the rate limiting.
3. This project was started with fewer stores, and there wasn't a need for a scaled architecture that would cost more money in hosting. Now that it has gotten larger, there will be a need to go to Redis for the background jobs. These jobs are handled by Heroku Scheduler, which is fine, but intermittent problems like the Lightspeed API being down or throwing erroneous certificate errors will cause the job to break, and require time to get set up to re-run again. Redis can handle this far better than Heroku Scheduler.
4. There is another repo, the dashboard repo, that gives the warehouse an easy way to look at the order alongside what the inventory count is at the warehouse. This is added into the weekly order job to push those.

### Core Components
1. Heroku - Hosts dashboard and API under TVS account
2. Heroku Scheduler - runs syncing jobs for products, and weekly purchase order job
3. Hooks Controller - handles any lifecycle events in product records
4. seed.rake - In the event the job brakes, there are scripts / instructions on handling re-running it.
5. light_api.rb - Where the weekly order job is housed.
