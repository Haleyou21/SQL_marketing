/*
1. First, show our volume growth. Pull overall session and order volume, 
trended by quarter for the life of the business. 
*/ 
select 
year(website_sessions.created_at) as yr,
quarter(website_sessions.created_at) as qtr,
count(distinct website_sessions.website_session_id) as sessions_volume,
count(distinct orders.website_session_id) as order_volume
from website_sessions left join orders
on orders.website_session_id=website_sessions.website_session_id
group by 1,2;

/*
2. Next, showcase all of efficiency improvements. Show quarterly figures 
since launched, for session-to-order conversion rate, revenue per order, and revenue per session. 

*/
select 
year(website_sessions.created_at) as yr,
quarter(website_sessions.created_at) as qtr,
count(distinct orders.website_session_id)/count(distinct website_sessions.website_session_id) as sessions_to_order_conv_rate,
sum(price_usd)/count(distinct orders.website_session_id) as rev_per_order,
sum(price_usd)/count(distinct website_sessions.website_session_id) as rev_per_session

from website_sessions left join orders
on orders.website_session_id=website_sessions.website_session_id
group by 1,2;

/*
3. Show how we’ve grown specific channels. Pull a quarterly view of orders from Gsearch nonbrand, 
Bsearch nonbrand, brand search overall, organic search, and direct type-in
*/
select 
year(website_sessions.created_at) as yr,
quarter(website_sessions.created_at) as qtr,
count(distinct case when utm_source='gsearch' and utm_campaign='nonbrand' then orders.order_id else null end) as gsearch_nonbrand,
count(distinct case when utm_source='bsearch' and utm_campaign='nonbrand' then orders.order_id else null end) as bsearch_nonbrand,
count(distinct case when utm_campaign='brand' then orders.order_id else null end) as brandsearch_overall,
count(distinct case when utm_source is null and http_referer is not null then orders.order_id else null end) as organic_search,
count(distinct case when utm_source is null and http_referer is null then orders.order_id else null end) as direct_type_in
from website_sessions left join orders
on orders.website_session_id=website_sessions.website_session_id
group by 1,2;

/*
4. Next, show the overall session-to-order conversion rate trends for those same channels, 
by quarter
*/
SELECT 
	YEAR(website_sessions.created_at) AS yr,
	QUARTER(website_sessions.created_at) AS qtr, 
    COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' AND utm_campaign = 'nonbrand' THEN orders.order_id ELSE NULL END)
		/COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' AND utm_campaign = 'nonbrand' THEN website_sessions.website_session_id ELSE NULL END) AS gsearch_nonbrand_conv_rt, 
    COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' AND utm_campaign = 'nonbrand' THEN orders.order_id ELSE NULL END) 
		/COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' AND utm_campaign = 'nonbrand' THEN website_sessions.website_session_id ELSE NULL END) AS bsearch_nonbrand_conv_rt, 
    COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN orders.order_id ELSE NULL END) 
		/COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN website_sessions.website_session_id ELSE NULL END) AS brand_search_conv_rt,
    COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN orders.order_id ELSE NULL END) 
		/COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN website_sessions.website_session_id ELSE NULL END) AS organic_search_conv_rt,
    COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NULL THEN orders.order_id ELSE NULL END) 
		/COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NULL THEN website_sessions.website_session_id ELSE NULL END) AS direct_type_in_conv_rt
FROM website_sessions 
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
GROUP BY 1,2
ORDER BY 1,2
;

/*
5. We’ve come a long way since the days of selling a single product. Let’s pull monthly trending for revenue 
and margin by product, along with total sales and revenue. Note anything you notice about seasonality.
*/
SELECT
	YEAR(created_at) AS yr, 
    MONTH(created_at) AS mo, 
    SUM(CASE WHEN product_id = 1 THEN price_usd ELSE NULL END) AS mrfuzzy_rev,
    SUM(CASE WHEN product_id = 1 THEN price_usd - cogs_usd ELSE NULL END) AS mrfuzzy_marg,
    SUM(CASE WHEN product_id = 2 THEN price_usd ELSE NULL END) AS lovebear_rev,
    SUM(CASE WHEN product_id = 2 THEN price_usd - cogs_usd ELSE NULL END) AS lovebear_marg,
    SUM(CASE WHEN product_id = 3 THEN price_usd ELSE NULL END) AS birthdaybear_rev,
    SUM(CASE WHEN product_id = 3 THEN price_usd - cogs_usd ELSE NULL END) AS birthdaybear_marg,
    SUM(CASE WHEN product_id = 4 THEN price_usd ELSE NULL END) AS minibear_rev,
    SUM(CASE WHEN product_id = 4 THEN price_usd - cogs_usd ELSE NULL END) AS minibear_marg,
    SUM(price_usd) AS total_revenue,  
    SUM(price_usd - cogs_usd) AS total_margin
FROM order_items 
GROUP BY 1,2
ORDER BY 1,2
;


/*
6. Dive deeper into the impact of introducing new products. Pull monthly sessions to 
the /products page, and show how the % of those sessions clicking through another page has changed 
over time, along with a view of how conversion from /products to placing an order has improved.
*/
CREATE TEMPORARY TABLE prodcut_pages
select website_pageview_id,website_session_id, created_at
from website_pageviews
where pageview_url='/products';

select 
year(prodcut_pages.created_at) as yr,
quarter(prodcut_pages.created_at) as qtr,
count(distinct prodcut_pages.website_session_id) AS sessions_to_product,
count(distinct website_pageviews.website_session_id) / count(distinct prodcut_pages.website_session_id) AS click_thro_rate,
count(distinct orders.order_id) / count(distinct prodcut_pages.website_session_id) AS conversion_rate
from prodcut_pages
left join website_pageviews
on website_pageviews.website_session_id=prodcut_pages.website_session_id
and website_pageviews.website_pageview_id>prodcut_pages.website_pageview_id -- viewed after product page
left join orders on orders.website_session_id=prodcut_pages.website_session_id
group by 1,2;

/*
7. The 4th product available as a primary product on December 05, 2014 (it was previously only a cross-sell item). 
Pull sales data since then, and show how well each product cross-sells from one another?
*/
create temporary table after_product
select order_id, primary_product_id
from orders
where created_at>'2014-12-05';

select primary_product_id,
count(distinct case when product_id=1 then after_product.order_id else null end) as cross_sell_product1,
count(distinct case when product_id=2 then after_product.order_id else null end) as cross_sell_product2,
count(distinct case when product_id=3 then after_product.order_id else null end) as cross_sell_product3,
count(distinct case when product_id=4 then after_product.order_id else null end) as cross_sell_product4,
count(distinct case when product_id=1 then after_product.order_id else null end) / count(distinct after_product.order_id) as cross_sell_product1_rt,
count(distinct case when product_id=2 then after_product.order_id else null end) / count(distinct after_product.order_id) as cross_sell_product2_rt,
count(distinct case when product_id=3 then after_product.order_id else null end) / count(distinct after_product.order_id) as cross_sell_product3_rt,
count(distinct case when product_id=4 then after_product.order_id else null end) / count(distinct after_product.order_id) as cross_sell_product4_rt
from after_product
left join order_items on order_items.order_id=after_product.order_id
and is_primary_item=0
group by 1


