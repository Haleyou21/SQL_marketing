-- 1)Most viewed website page
SELECT pageview_url, COUNT(DISTINCT website_pageview_id) AS sessions from website_pageviews
WHERE created_at < '2012-06-09'
GROUP BY pageview_url
ORDER BY sessions DESC;

-- 2)Top entry pages
DROP TEMPORARY TABLE IF EXISTS page_view;
CREATE TEMPORARY TABLE page_view
SELECT website_session_id, min(website_pageview_id) AS min_id
FROM website_pageviews
WHERE created_at < '2012-06-12'
GROUP BY website_session_id;

SELECT COUNT(DISTINCT page_view.website_session_id) AS sessions_hitting_this_landing_page, pageview_url AS landing_page FROM page_view
LEFT JOIN website_pageviews
ON website_pageviews.website_pageview_id=page_view.min_id
GROUP BY pageview_url;

-- 3)Bounce rate

-- 1/ single landing page performance

-- STEP1: finding the first website_pageview_id for relevant sessions
DROP TEMPORARY TABLE IF EXISTS first_pgv;
CREATE TEMPORARY TABLE first_pgv
SELECT MIN(website_pageviews.website_pageview_id) AS min_pgv, website_pageviews.website_session_id 
FROM website_pageviews
WHERE website_pageviews.created_at<'2012-06-14'
GROUP BY website_session_id;

-- STEP2: identifying the landing page of each session
CREATE TEMPORARY TABLE landing_pg
SELECT website_pageviews.pageview_url, website_pageviews.website_session_id
FROM first_pgv
LEFT JOIN website_pageviews
ON website_pageviews.website_pageview_id=first_pgv.min_pgv;

-- STEP3: counting pageviews for each session, identify bounces
CREATE TEMPORARY TABLE bounce_rate
SELECT landing_pg.website_session_id, landing_pg.pageview_url AS land, COUNT(website_pageviews.website_pageview_id) AS pgv
FROM landing_pg
LEFT JOIN website_pageviews
ON website_pageviews.website_session_id=landing_pg.website_session_id
GROUP BY landing_pg.website_session_id, land
HAVING pgv=1;

-- STEP 4: summarizing by counting total sessions and bounced sessions
SELECT COUNT(landing_pg.website_session_id) AS sessions,
COUNT(bounce_rate.website_session_id) AS bounced_sessions,
COUNT(bounce_rate.website_session_id)/COUNT(landing_pg.website_session_id) AS bounce_rate
FROM landing_pg
LEFT JOIN bounce_rate
ON bounce_rate.website_session_id=landing_pg.website_session_id;

-- 2/ bi-landing page performance (compare two pages performance)

-- STEP 0: finding the first time when testing began
-- filter gsearch and nonbrand to get relavent session_id
DROP TEMPORARY TABLE IF EXISTS sessions_g_nb;
CREATE TEMPORARY TABLE sessions_g_nb
SELECT website_sessions.website_session_id
FROM website_sessions
WHERE utm_source='gsearch' AND utm_campaign='nonbrand' AND created_at<'2012-07-28';

-- get the relavent info at pageviews table
DROP TEMPORARY TABLE IF EXISTS joint_table;
CREATE TEMPORARY TABLE joint_table
SELECT website_pageview_id, created_at, website_pageviews.website_session_id, pageview_url FROM website_pageviews
INNER JOIN sessions_g_nb
ON website_pageviews.website_session_id=sessions_g_nb.website_session_id;


-- get the first time when launched this bi-landing page: min_pgv=23504
SELECT MIN(DATE(created_at)), MIN(website_pageview_id)
FROM joint_table
WHERE pageview_url='/lander-1';

-- STEP 1: finding the first website_pageview_id for relevant sessions
DROP TEMPORARY TABLE IF EXISTS min_pgv;
CREATE TEMPORARY TABLE min_pgv
SELECT MIN(joint_table.website_pageview_id) AS min_pgv, joint_table.website_session_id
FROM joint_table
WHERE joint_table.website_pageview_id>23504 AND joint_table.pageview_url IN ('/home', '/lander-1')
GROUP BY website_session_id;

-- STEP 2: identifying the landing page of each session
DROP TEMPORARY TABLE IF EXISTS landing_pg;
CREATE TEMPORARY TABLE landing_pg
SELECT website_pageviews.pageview_url AS land, website_pageviews.website_session_id
FROM min_pgv
LEFT JOIN website_pageviews
ON website_pageviews.website_pageview_id=min_pgv.min_pgv;

-- STEP3: counting pageviews for each session, identify bounces

DROP TEMPORARY TABLE IF EXISTS bounce_rate;
CREATE TEMPORARY TABLE bounce_rate
SELECT landing_pg.website_session_id, landing_pg.land AS land, COUNT(joint_table.website_pageview_id) AS pgv
FROM landing_pg
LEFT JOIN joint_table
ON joint_table.website_session_id=landing_pg.website_session_id
GROUP BY landing_pg.website_session_id, landing_pg.land
HAVING pgv=1;


-- STEP 4: summarizing by counting total sessions and bounced sessions

SELECT COUNT(landing_pg.website_session_id) AS sessions,
COUNT(bounce_rate.website_session_id) AS bounced_sessions,
COUNT(bounce_rate.website_session_id)/COUNT(landing_pg.website_session_id) AS bounce_rate
FROM landing_pg
LEFT JOIN bounce_rate
ON bounce_rate.website_session_id=landing_pg.website_session_id
GROUP BY landing_pg.land; -- note: group by landing_pg's url



-- 3/ bi-landing page trend analysis, based on the previous code, find the weekly trend

-- filter gsearch and nonbrand to get relavent session_id
DROP TEMPORARY TABLE IF EXISTS sessions_g_nb;
CREATE TEMPORARY TABLE sessions_g_nb
SELECT website_sessions.website_session_id
FROM website_sessions
WHERE utm_source='gsearch' AND utm_campaign='nonbrand' AND created_at<'2012-08-31' AND created_at>='2012-06-01';

-- get the relavent info at pageviews table
DROP TEMPORARY TABLE IF EXISTS joint_table;
CREATE TEMPORARY TABLE joint_table
SELECT website_pageview_id, created_at, website_pageviews.website_session_id, pageview_url FROM website_pageviews
INNER JOIN sessions_g_nb
ON website_pageviews.website_session_id=sessions_g_nb.website_session_id;

-- STEP 1: finding the first website_pageview_id for relevant sessions
DROP TEMPORARY TABLE IF EXISTS min_pgv;
CREATE TEMPORARY TABLE min_pgv
SELECT MIN(joint_table.website_pageview_id) AS min_pgv, joint_table.website_session_id, created_at
FROM joint_table
WHERE joint_table.pageview_url IN ('/home', '/lander-1')
GROUP BY website_session_id, created_at;

-- STEP 2: identifying the landing page of each session
DROP TEMPORARY TABLE IF EXISTS landing_pg;
CREATE TEMPORARY TABLE landing_pg
SELECT website_pageviews.pageview_url AS land, website_pageviews.website_session_id, min_pgv.created_at
FROM min_pgv
LEFT JOIN website_pageviews
ON website_pageviews.website_pageview_id=min_pgv.min_pgv;

-- STEP3: counting pageviews for each session, identify bounces

DROP TEMPORARY TABLE IF EXISTS bounce_rate;
CREATE TEMPORARY TABLE bounce_rate
SELECT landing_pg.website_session_id, landing_pg.land AS land, COUNT(joint_table.website_pageview_id) AS pgv
FROM landing_pg
LEFT JOIN joint_table
ON joint_table.website_session_id=landing_pg.website_session_id
GROUP BY landing_pg.website_session_id, landing_pg.land
HAVING pgv=1;

-- STEP 4: summarizing by counting bounce_rate, home_sessions, lander_sessions
SELECT 
MIN(DATE(created_at)) AS week_start_date,
COUNT(bounce_rate.website_session_id)/COUNT(landing_pg.website_session_id) AS bounce_rate,
COUNT(DISTINCT CASE WHEN landing_pg.land='/home' THEN bounce_rate.website_session_id ELSE NULL END) AS home_sessions,
COUNT(DISTINCT CASE WHEN landing_pg.land='/lander-1' THEN bounce_rate.website_session_id ELSE NULL END) AS lander_sessions
FROM landing_pg
LEFT JOIN bounce_rate
ON bounce_rate.website_session_id=landing_pg.website_session_id
GROUP BY YEARWEEK(created_at); -- note: YEARWEEK gives the first day of each week

-- 4) building conversion funnels
DROP TEMPORARY TABLE IF EXISTS session_level_made_it_flags;

CREATE TEMPORARY TABLE session_level_made_it_flags
SELECT website_session_id,
MAX(products_page) AS products_made_it, 
MAX(mrfuzzy_page) AS mrfuzzy_made_it, 
MAX(cart_page) AS cart_made_it, 
MAX(shipping_page) AS shipping_made_it, 
MAX(billing_page) AS billing_made_it, 
MAX(thankyou_page) AS thankyou_made_it
FROM(
SELECT website_pageviews.pageview_url, website_sessions.website_session_id,
CASE WHEN pageview_url='/products' THEN 1 ELSE 0 END AS products_page,
CASE WHEN pageview_url='/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mrfuzzy_page,
CASE WHEN pageview_url='/cart' THEN 1 ELSE 0 END AS cart_page,
CASE WHEN pageview_url='/shipping' THEN 1 ELSE 0 END AS shipping_page,
CASE WHEN pageview_url='/billing' THEN 1 ELSE 0 END AS billing_page,
CASE WHEN pageview_url='/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
FROM website_sessions
LEFT JOIN website_pageviews
ON website_pageviews.website_session_id=website_sessions.website_session_id
WHERE website_sessions.created_at<'2012-09-05' 
AND website_sessions.created_at>'2012-08-05' 
AND utm_source='gsearch' 
AND utm_campaign='nonbrand'
ORDER BY
website_sessions.website_session_id) AS pageview_level
GROUP BY website_session_id;


SELECT COUNT(DISTINCT website_session_id) AS sessions, 
COUNT(DISTINCT CASE WHEN products_made_it=1 THEN website_session_id ELSE NULL END) AS to_products,
COUNT(DISTINCT CASE WHEN mrfuzzy_made_it=1 THEN website_session_id ELSE NULL END) AS to_mrfuzzy,
COUNT(DISTINCT CASE WHEN cart_made_it=1 THEN website_session_id ELSE NULL END) AS to_cart,
COUNT(DISTINCT CASE WHEN shipping_made_it=1 THEN website_session_id ELSE NULL END) AS to_shipping,
COUNT(DISTINCT CASE WHEN billing_made_it=1 THEN website_session_id ELSE NULL END) AS to_billing,
COUNT(DISTINCT CASE WHEN thankyou_made_it=1 THEN website_session_id ELSE NULL END) AS to_thankyou
FROM session_level_made_it_flags;


-- 5) analyzing conversion funnel tests
-- STEP1: first time /billing-2 was seen
SELECT 
created_at AS first_created_at, 
website_pageview_id AS first_pv_id
FROM website_pageviews
WHERE pageview_url='/billing-2'
ORDER BY created_at
LIMIT 1;


-- STEP2: final test analysis output
SELECT pageview_url,
COUNT(DISTINCT website_session_id) AS sessions,
COUNT(DISTINCT order_id) AS orders,
COUNT(DISTINCT order_id)/ COUNT(DISTINCT website_session_id) AS billing_to_order_rt
FROM(
SELECT website_pageviews.pageview_url, website_pageviews.website_session_id,orders.order_id
FROM website_pageviews
	LEFT JOIN orders
		ON website_pageviews.website_session_id=orders.website_session_id
WHERE website_pageviews.created_at<'2012-11-10' 
AND website_pageview_id>=53550 
AND website_pageviews.pageview_url IN ('/billing','/billing-2')
) AS billing_session_w_orders
GROUP BY pageview_url


















