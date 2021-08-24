-- Задание 1. Landing Page Testing. 
-- Сравнить показатели отказов при 2 различных лэндингах за исследуемый период.

with begin_of_period as (
	select min(wp.created_at) from website_pageviews wp
	where pageview_url = '/lander-1'
),

bounced_sessions_ids as (
	select
		wp.website_session_id as bounced_session_id
	from website_pageviews wp
    where wp.created_at between (select * from begin_of_period) and '2012-07-28'
	group by 1
    having count(distinct wp.website_pageview_id) = 1
),

first_pageviews as (
	select 
		min(wp.website_pageview_id) as first_website_pageview_id
	from website_pageviews wp
    where wp.created_at between (select * from begin_of_period) and '2012-07-28'
	group by wp.website_session_id
)

select 
	wp.pageview_url, 
	count(distinct wp.website_session_id) as total_sessions,
    count(distinct bsi.bounced_session_id) as bounced_sessions,
    count(distinct bsi.bounced_session_id) / count(distinct wp.website_session_id) as bounce_rate
from website_pageviews wp
	left join bounced_sessions_ids bsi on bsi.bounced_session_id = wp.website_session_id
	left join website_sessions ws on ws.website_session_id = wp.website_session_id
where wp.website_pageview_id in (select * from first_pageviews) and ws.utm_source = 'gsearch' and ws.utm_campaign = 'nonbrand'
group by wp.pageview_url;

-- Задание 2. Analyzing Conversion Funnel Tests. 
-- Сравнить процентное соотношение удачно проведенных покупок при 2 разных страницах оплаты.
select min(wp.created_at), min(wp.website_pageview_id) from website_pageviews wp 
    left join website_sessions ws on ws.website_session_id = wp.website_session_id
where wp.pageview_url = '/billing-2'; 

with session_clicks as (
	select 
		wp.website_session_id,
		max(case when wp.pageview_url = '/billing' then 1 else 0 end) as bill_click,
		max(case when wp.pageview_url = '/billing-2' then 1 else 0 end) as bill2_click,
		max(case when wp.pageview_url = '/thank-you-for-your-order' then 1 else 0 end) as order_click,
        case when max(case when wp.pageview_url = '/billing' then 1 else 0 end) = 1 then '/billing'
			 when max(case when wp.pageview_url = '/billing-2' then 1 else 0 end) = 1 then '/billing-2' end 
			 as billing_version_seen
	from website_pageviews wp 
		left join website_sessions ws on ws.website_session_id = wp.website_session_id
	where wp.website_pageview_id >= 53550 and wp.created_at < '2012-11-10'
	group by 1
    having billing_version_seen is not null
)

select 
	sc.billing_version_seen,
    count(1) as sessions,
    sum(sc.order_click) as orders,
    sum(sc.order_click) / count(1) as billing_to_order_rt
from session_clicks sc
group by 1;

-- Задание 3. Customer discounts. Создать таблицу с данными о персональных скидках.
-- Назначить топ-50 покупателей по общей сумме покупок скидку 10%, топ-300 - 5%.
-- Учесть, что не нужно учитывать покупки, которые были возвращены.

create table if not exists buyers_discounts as (
	with buyers_ranks as (
		select
			ord.user_id,
			sum(ord.price_usd) as total_sum,
			rank() over (order by sum(ord.price_usd) desc) as rnk
		from orders ord
		where ord.order_id not in 
			(select ref.order_id from order_item_refunds ref) 
		group by ord.user_id
	)

	select 
		ranks.user_id,
		case 
			when ranks.rnk <= 50 then 10
			when ranks.rnk <= 300 then 5
			else 0 
		end as discount
	from buyers_ranks ranks
);

-- Задание 4. Trending w/ Granular Segment. 
-- Проанализировать динамику трафика по виду устройства по неделям после проведения оптимизации рекламных ставок.

select 
	min(date(ws.created_at)) as week_start_date,
    count(case when ws.device_type = 'desktop' then 1 else null end) as dtop_sessions,
    count(case when ws.device_type = 'mobile' then 1 else null end) as mob_sessions
from website_sessions ws
where ws.created_at between '2012-04-15' and '2012-06-09'
	and (ws.utm_source = 'gsearch' and utm_campaign = 'nonbrand')
group by year(ws.created_at), week(ws.created_at);
