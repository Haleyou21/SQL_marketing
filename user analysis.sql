-- analyzing repeat visit & purchase behavior
CREATE TEMPORARY TABLE session_w_repeats
select new_sessions.user_id, new_sessions.website_session_id AS new_id, website_sessions.website_session_id AS repeated_id
from(
select user_id, website_session_id 
from website_sessions
where created_at < '2014-11-01' and created_at >= '2014-01-01' and is_repeat_session=0
-- new sessions
) as new_sessions
left join website_sessions
on website_sessions.user_id=new_sessions.user_id
and website_sessions.is_repeat_session=1
and website_sessions.created_at < '2014-11-01' and website_sessions.created_at >= '2014-01-01'
and website_sessions.website_session_id>new_sessions.website_session_id;

select repeated_sessions, count(new_id) as users from (
select new_id, count(repeated_id) as repeated_sessions
from session_w_repeats
group by new_id) as user_level
group by 1;

-- analyzing time to repeat: the min, max and avg time betwwen the first and the second session 
CREATE TEMPORARY TABLE first_second_session
select new_sessions.user_id, new_sessions.website_session_id AS first_id, 
min(website_sessions.website_session_id) AS second_id, 
min(website_sessions.created_at) as second_time, -- using min second date, otherwise the result is different
new_sessions.created_at as first_time
from(
select user_id, website_session_id, created_at 
from website_sessions
where created_at < '2014-11-03' and created_at >= '2014-01-01' and is_repeat_session=0
-- new sessions
) as new_sessions
left join website_sessions
on website_sessions.user_id=new_sessions.user_id
and website_sessions.is_repeat_session=1
and website_sessions.created_at < '2014-11-03' and website_sessions.created_at >= '2014-01-01'
and website_sessions.website_session_id>new_sessions.website_session_id
group by 1,2,5;

select min(datediff(second_time,first_time)) as min_days_first_to_second,
max(datediff(second_time,first_time)) as max_days_first_to_second,
avg(datediff(second_time,first_time)) as avg_days_first_to_second
from first_second_session
where second_id is not null;

-- analyzing repeat channel
select 
case 
	when utm_source is null and http_referer in ('https://www.gsearch.com','https://www.bsearch.com') then 'organic_search'
    when utm_source is null and http_referer is null then 'direct_type_in'
    when utm_campaign='brand' then 'paid_brand'
    when utm_campaign='nonbrand' then 'paid_nonbrand'
    when utm_source='socialbook' then 'paid_social'
end as channel_group,
count(case when is_repeat_session=0 then website_session_id else null end) as new_sessions,
count(case when is_repeat_session=1 then website_session_id else null end) as repeat_sessions
from website_sessions
where created_at < '2014-11-05' and created_at >= '2014-01-01'
group by 1;

-- analyzing new&repeat
select is_repeat_session, 
count(distinct website_sessions.website_session_id) as sessions, 
count(distinct orders.order_id)/count(distinct website_sessions.website_session_id) as conv_rate,
sum(price_usd)/count(distinct website_sessions.website_session_id)as rev_per_session
from website_sessions left join orders
on orders.website_session_id=website_sessions.website_session_id
where website_sessions.created_at < '2014-11-08' and website_sessions.created_at >= '2014-01-01' 
group by 1;
