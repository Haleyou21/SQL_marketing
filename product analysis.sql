-- 1)product-level sales analysis
SELECT YEAR(created_at) AS yr, MONTH(created_at) AS mo, COUNT(DISTINCT order_id) AS number_of_sales, SUM(price_usd) AS total_revenue, SUM(price_usd-cogs_usd) AS total_margin FROM orders
WHERE created_at<'2013-01-04'
GROUP BY 1,2;



-- 2)analyzing product lanches
SELECT YEAR(website_sessions.created_at) AS yr, MONTH(website_sessions.created_at) AS mo, COUNT(DISTINCT order_id) AS orders,
COUNT(DISTINCT order_id)/COUNT(website_sessions.website_session_id) AS conv_rate,
COUNT(price_usd)/COUNT(website_sessions.website_session_id) AS revenue_per_session,
COUNT(DISTINCT CASE WHEN primary_product_id=1 THEN order_id ELSE NULL END) AS product_one_orders,
COUNT(DISTINCT CASE WHEN primary_product_id=2 THEN order_id ELSE NULL END) AS product_two_orders
FROM website_sessions
LEFT JOIN orders ON orders.website_session_id=website_sessions.website_session_id
WHERE website_sessions.created_at BETWEEN '2012-04-01' AND '2013-04-05'
GROUP BY 1,2;



-- 3)analyzing product-level-website pathing

-- STEP1: find relevant /products pageviews with website_session_id
CREATE TEMPORARY TABLE products_pageviews
SELECT website_session_id, website_pageview_id, created_at,
CASE WHEN created_at<'2013-01-06' THEN 'pre_product_2'
WHEN created_at>='2013-01-06' THEN 'post_product_2'
ELSE 'check again' END AS time_period
FROM website_pageviews
WHERE pageview_url='/products' AND created_at BETWEEN '2012-10-06' AND '2013-04-06';

-- STEP2: find the next pageview id that occurs after the product pageview
CREATE TEMPORARY TABLE sessions_w_next_pageview_id
SELECT time_period, products_pageviews.website_session_id, MIN(website_pageviews.website_pageview_id) AS min_next_pageview_id
FROM products_pageviews
LEFT JOIN website_pageviews 
	ON products_pageviews.website_session_id=website_pageviews.website_session_id 
		AND website_pageviews.website_pageview_id>products_pageviews.website_pageview_id
GROUP BY 1,2;

-- STEP3: find the pageview_url associated with any applicable next pageview id
CREATE TEMPORARY TABLE sessions_w_next_pageview_url
SELECT time_period, sessions_w_next_pageview_id.website_session_id, sessions_w_next_pageview_id.min_next_pageview_id, website_pageviews.pageview_url
FROM sessions_w_next_pageview_id
LEFT JOIN website_pageviews ON website_pageviews.website_pageview_id=sessions_w_next_pageview_id.min_next_pageview_id;

-- STEP4: summarize the data and analyze the pre vs post periods
SELECT time_period,
COUNT(DISTINCT website_session_id) AS sessions,
COUNT(DISTINCT CASE WHEN min_next_pageview_id IS NOT NULL THEN website_session_id ELSE NULL END) AS w_next_pg,
COUNT(DISTINCT CASE WHEN min_next_pageview_id IS NOT NULL THEN website_session_id ELSE NULL END)/COUNT(DISTINCT website_session_id) AS pct_w_next_pg,
COUNT(DISTINCT CASE WHEN pageview_url='/the-original-mr-fuzzy' THEN website_session_id ELSE NULL END) AS to_mrfuzzy,
COUNT(DISTINCT CASE WHEN pageview_url='/the-original-mr-fuzzy' THEN website_session_id ELSE NULL END) / COUNT(DISTINCT website_session_id) AS pct_to_mrfuzzy,
COUNT(DISTINCT CASE WHEN pageview_url='/the-forever-love-bear' THEN website_session_id ELSE NULL END) AS to_lovebear,
COUNT(DISTINCT CASE WHEN pageview_url='/the-forever-love-bear' THEN website_session_id ELSE NULL END)/COUNT(DISTINCT website_session_id) AS pct_to_lovebear
FROM sessions_w_next_pageview_url
GROUP BY 1;



-- 4)building product-level conversion funnels
-- STEP0: finding the right pageview_url to build funnels
DROP TEMPORARY TABLE IF EXISTS sessions_seeing_product_pages;
CREATE TEMPORARY TABLE sessions_seeing_product_pages
SELECT website_session_id, website_pageview_id, pageview_url AS product_page_seen 
FROM website_pageviews 
WHERE created_at BETWEEN '2013-01-06'  AND '2013-04-10' AND pageview_url IN ('/the-forever-love-bear','/the-original-mr-fuzzy');

SELECT DISTINCT pageview_url from sessions_seeing_product_pages 
LEFT JOIN website_pageviews
	ON sessions_seeing_product_pages.website_session_id=website_pageviews.website_session_id 
		AND website_pageviews.website_pageview_id>sessions_seeing_product_pages.website_pageview_id; -- find the page url after landed on the product page

-- STEP1: convert them all to 0,1
DROP TEMPORARY TABLE IF EXISTS session_id_convert_number;
CREATE TEMPORARY TABLE session_id_convert_number
SELECT website_session_id,
CASE WHEN pageview_url='/cart' THEN 1 ELSE NULL END AS to_cart,
CASE WHEN pageview_url='/shipping' THEN 1 ELSE NULL END AS to_shipping,
CASE WHEN pageview_url='/billing-2' THEN 1 ELSE NULL END AS to_billing,
CASE WHEN pageview_url='/thank-you-for-your-order' THEN 1 ELSE NULL END AS to_thankyou
FROM website_pageviews
WHERE created_at BETWEEN '2013-01-06' AND '2013-04-10';

-- STEP2: group by sessions
DROP TEMPORARY TABLE IF EXISTS groupby_sessions;
CREATE TEMPORARY TABLE groupby_sessions
SELECT website_session_id, MAX(to_cart) AS to_cart, MAX(to_shipping) AS to_shipping, MAX(to_billing) AS to_billing, MAX(to_thankyou) AS to_thankyou FROM session_id_convert_number
GROUP BY 1;

-- STEP3: add by two products
DROP TEMPORARY TABLE IF EXISTS filter_sessions;
CREATE TEMPORARY TABLE filter_sessions
SELECT CASE WHEN pageview_url='/the-forever-love-bear' THEN 'lovebear' WHEN pageview_url='/the-original-mr-fuzzy' THEN 'mrfuzzy' ELSE NULL END AS product_seen,
groupby_sessions.website_session_id, to_cart, to_shipping, to_billing, to_thankyou FROM groupby_sessions 
LEFT JOIN website_pageviews ON website_pageviews.website_session_id=groupby_sessions.website_session_id
WHERE pageview_url IN ('/the-forever-love-bear','/the-original-mr-fuzzy');

-- STEP4: calculate
-- final output part 1
SELECT product_seen, COUNT(DISTINCT website_session_id) AS sessions,
COUNT(to_cart) AS to_cart,COUNT(to_shipping) AS to_shipping, COUNT(to_billing) AS to_billing, COUNT(to_thankyou) AS to_thankyou
FROM filter_sessions
GROUP BY 1;
-- final output part 2 - click rates
SELECT product_seen,COUNT(DISTINCT website_session_id) AS sessions,
COUNT(to_cart)/COUNT(DISTINCT website_session_id) AS product_page_click_rt,
COUNT(to_shipping)/COUNT(to_cart) AS cart_click_rt, 
COUNT(to_billing)/COUNT(to_shipping) AS shipping_click_rt, 
COUNT(to_thankyou)/COUNT(to_billing) AS billing_click_rt
FROM filter_sessions
GROUP BY 1;




-- 5)cross-selling & product portfolio analysis

-- 1/ cross-sell analysis
-- STEP1: find the /cart sessions
CREATE TEMPORARY TABLE go_cart_sessions
SELECT 
CASE WHEN created_at<'2013-09-25' THEN 'A.post_cross_sell'
	 WHEN created_at>'2013-09-25' THEN 'B.post_cross_sell'
     ELSE 'WRONG' END AS time_period,
website_pageview_id,
website_session_id
FROM website_pageviews
WHERE created_at BETWEEN '2013-08-25' AND '2013-10-25' AND pageview_url='/cart';

-- STEP2: find clickthroughs after cart
CREATE TEMPORARY TABLE after_cart_sessions
SELECT go_cart_sessions.time_period, go_cart_sessions.website_session_id, 
MIN(website_pageviews.website_pageview_id) AS after_cart_pageview_id -- make sure it has after cart session, otherwise it's NULL
FROM go_cart_sessions 
LEFT JOIN website_pageviews
ON website_pageviews.website_session_id=go_cart_sessions.website_session_id
	AND website_pageviews.website_pageview_id>go_cart_sessions.website_pageview_id
GROUP BY time_period, website_session_id
HAVING MIN(website_pageviews.website_pageview_id) IS NOT NULL;

-- STEP3: find orders associated with /cart sessions
CREATE TEMPORARY TABLE order_sessions
SELECT time_period, after_cart_sessions.website_session_id, after_cart_pageview_id, order_id, items_purchased, price_usd FROM after_cart_sessions
LEFT JOIN orders
	ON orders.website_session_id=after_cart_sessions.website_session_id;


-- STEP4: calculate
SELECT
time_period,
COUNT(DISTINCT website_session_id) AS sessions,
SUM(click_to_another_page) AS clickthroughs,
SUM(click_to_another_page)/COUNT(DISTINCT website_session_id) AS cart_ctr,
SUM(items_purchased)/SUM(place_order) AS products_per_order,
SUM(price_usd)/SUM(place_order) AS aov,
SUM(price_usd)/COUNT(DISTINCT website_session_id) AS rev_per_cart_session
FROM (
SELECT go_cart_sessions.time_period, 
go_cart_sessions.website_session_id,
CASE WHEN after_cart_sessions.website_session_id IS NULL THEN 0 ELSE 1 END AS click_to_another_page,
CASE WHEN order_sessions.order_id IS NULL THEN 0 ELSE 1 END AS place_order,
order_sessions.items_purchased, 
order_sessions.price_usd
FROM go_cart_sessions
	LEFT JOIN after_cart_sessions ON after_cart_sessions.website_session_id=go_cart_sessions.website_session_id
		LEFT JOIN order_sessions ON order_sessions.website_session_id=go_cart_sessions.website_session_id
) AS full_data
GROUP BY 1;



-- 2/ product portfolio expansion
SELECT 
CASE WHEN website_sessions.created_at < '2013-12-12' THEN 'A.Pre_Birthday_Bear' -- CANNOT USE BETWEEN TO LIMIT TIME PERIOD HERE, ONLY CAN PUT THIS LIMIT IN WHERE QUERY
	 WHEN website_sessions.created_at >= '2013-12-12' THEN 'B.Post_Birthday_Bear' ELSE 'WRONG' END AS time_period,
COUNT(DISTINCT order_id)/COUNT(DISTINCT website_sessions.website_session_id) AS conv_rate, 
SUM(price_usd)/COUNT(DISTINCT order_id) AS aov,
SUM(items_purchased)/COUNT(DISTINCT order_id) AS products_per_order,
SUM(price_usd)/COUNT(DISTINCT website_sessions.website_session_id)
FROM website_sessions -- do not use website_pageviews because it can cause duplicate data
LEFT JOIN orders ON orders.website_session_id=website_sessions.website_session_id
WHERE website_sessions.created_at BETWEEN '2013-11-12' AND '2014-01-12'
GROUP BY 1;




-- 6)analyzing product refund rate: suppliers has some problem at first
SELECT YEAR(order_items.created_at) AS yr, MONTH(order_items.created_at) AS mo,
COUNT(DISTINCT CASE WHEN product_id=1 THEN order_items.order_id ELSE NULL END) AS p1_orders,
COUNT(DISTINCT CASE WHEN product_id=1 THEN order_item_refunds.order_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN product_id=1 THEN order_items.order_id ELSE NULL END) AS p1_refund_rt,
COUNT(DISTINCT CASE WHEN product_id=2 THEN order_items.order_id ELSE NULL END) AS p2_orders,
COUNT(DISTINCT CASE WHEN product_id=2 THEN order_item_refunds.order_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN product_id=2 THEN order_items.order_id ELSE NULL END) AS p2_refund_rt,
COUNT(DISTINCT CASE WHEN product_id=3 THEN order_items.order_id ELSE NULL END) AS p3_orders,
COUNT(DISTINCT CASE WHEN product_id=3 THEN order_item_refunds.order_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN product_id=2 THEN order_items.order_id ELSE NULL END) AS p3_refund_rt,
COUNT(DISTINCT CASE WHEN product_id=4 THEN order_items.order_id ELSE NULL END) AS p4_orders,
COUNT(DISTINCT CASE WHEN product_id=4 THEN order_item_refunds.order_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN product_id=2 THEN order_items.order_id ELSE NULL END) AS p4_refund_rt
FROM order_items
LEFT JOIN order_item_refunds ON order_item_refunds.order_item_id=order_items.order_item_id
WHERE order_items.created_at<'2014-10-15'
GROUP BY 1,2

