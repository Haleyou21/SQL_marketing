-- 1) analysis for channel portfolio management
-- 1/ comparing channel characteristics
SELECT utm_source, 
COUNT(DISTINCT website_session_id) AS sessions,
COUNT(DISTINCT CASE WHEN device_type='mobile' THEN website_session_id ELSE NULL END) AS mobile_sessions,
COUNT(DISTINCT CASE WHEN device_type='mobile' THEN website_session_id ELSE NULL END)/ COUNT(DISTINCT website_session_id) AS pct_mobile
FROM website_sessions
WHERE utm_campaign='nonbrand' AND created_at >'2012-08-22' AND created_at <'2012-11-30'
GROUP BY utm_source;

-- 2/ cross-channel bid optimization

SELECT device_type, utm_source, COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
COUNT(DISTINCT order_id) AS orders,
COUNT(DISTINCT order_id)/ COUNT(DISTINCT website_sessions.website_session_id) AS conv_rate
FROM website_sessions
	LEFT JOIN orders ON orders.website_session_id=website_sessions.website_session_id
WHERE utm_source IN ('gsearch','bsearch') AND 
website_sessions.created_at>'2012-08-22' AND website_sessions.created_at<'2012-09-18' AND utm_campaign='nonbrand'
GROUP BY 1,2;

-- 3/ analyzing channel portfolio trends
SELECT MIN(DATE(created_at)),
COUNT(DISTINCT CASE WHEN utm_source='gsearch' AND device_type='desktop' THEN website_session_id ELSE NULL END) AS g_dtop_session,
COUNT(DISTINCT CASE WHEN utm_source='bsearch' AND device_type='desktop' THEN website_session_id ELSE NULL END) AS b_dtop_session,
COUNT(DISTINCT CASE WHEN utm_source='bsearch' AND device_type='desktop' THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN utm_source='gsearch' AND device_type='desktop' THEN website_session_id ELSE NULL END) AS b_pct_of_g_dtop,
COUNT(DISTINCT CASE WHEN utm_source='gsearch' AND device_type='mobile' THEN website_session_id ELSE NULL END) AS g_mob_session,
COUNT(DISTINCT CASE WHEN utm_source='bsearch' AND device_type='mobile' THEN website_session_id ELSE NULL END) AS b_mob_session,
COUNT(DISTINCT CASE WHEN utm_source='bsearch' AND device_type='mobile' THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN utm_source='gsearch' AND device_type='mobile' THEN website_session_id ELSE NULL END) AS b_pct_of_g_mob
FROM website_sessions
WHERE created_at>'2012-11-04' AND created_at<'2012-12-22' AND utm_campaign='nonbrand'
GROUP BY YEARWEEK(created_at);

-- 4/ analyzing direct traffic
SELECT YEAR(created_at) AS yr, MONTH(created_at) AS mo,
COUNT(DISTINCT CASE WHEN utm_campaign='nonbrand' THEN website_session_id ELSE NULL END) AS nonbrand,
COUNT(DISTINCT CASE WHEN utm_campaign='brand' THEN website_session_id ELSE NULL END) AS brand,
COUNT(DISTINCT CASE WHEN utm_campaign='brand' THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN utm_campaign='nonbrand' THEN website_session_id ELSE NULL END) AS brand_pct_of_nonbrand,
COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NULL THEN website_session_id ELSE NULL END) AS direct,
COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NULL THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN utm_campaign='nonbrand' THEN website_session_id ELSE NULL END) AS direct_pct_of_nonbrand,
COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IN ('https://www.gsearch.com','https://www.bsearch.com') THEN website_session_id ELSE NULL END) AS organic,
COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IN ('https://www.gsearch.com','https://www.bsearch.com') THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN utm_campaign='nonbrand' THEN website_session_id ELSE NULL END) AS organic_pct_of_nonbrand
FROM website_sessions
WHERE created_at<'2012-12-23'
GROUP BY 1,2;




-- 2) analyzing business patterns and seasonality

-- 1/ analyzing seasonality
SELECT 
YEAR(website_sessions.created_at) AS yr, 
MONTH(website_sessions.created_at) AS mo,
COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
COUNT(DISTINCT orders.order_id) AS orders
FROM website_sessions
LEFT JOIN orders ON orders.website_session_id=website_sessions.website_session_id
WHERE website_sessions.created_at<'2013-01-01'
GROUP BY 1,2;

-- 2/ analyzing business pattern: average website session volume by hour of day and by day week
SELECT hr,
ROUND(AVG(CASE WHEN wk=0 THEN sessions ELSE NULL END),1) AS mon,
ROUND(AVG(CASE WHEN wk=1 THEN sessions ELSE NULL END),1) AS tue,
ROUND(AVG(CASE WHEN wk=2 THEN sessions ELSE NULL END),1) AS wed,
ROUND(AVG(CASE WHEN wk=3 THEN sessions ELSE NULL END),1) AS thu,
ROUND(AVG(CASE WHEN wk=4 THEN sessions ELSE NULL END),1) AS fri,
ROUND(AVG(CASE WHEN wk=5 THEN sessions ELSE NULL END),1) AS sat,
ROUND(AVG(CASE WHEN wk=6 THEN sessions ELSE NULL END),1) AS sun
FROM(
SELECT 
DATE(created_at) AS da,
HOUR(created_at) AS hr,
WEEKDAY(created_at) AS wk,
COUNT(DISTINCT website_session_id) AS sessions
FROM website_sessions
WHERE created_at BETWEEN '2012-09-15' AND '2012-11-15'
GROUP BY 1,2,3
) daily_hourly_sessions
GROUP BY hr;









