-- 1. VIEW DATA
SELECT * FROM user_events;

-- 2. CHECK DATE RANGE OF DATA
SELECT 
    MIN(STR_TO_DATE(event_date, '%Y-%m-%d %H:%i:%s.%f')) AS earliest_date,
    MAX(STR_TO_DATE(event_date, '%Y-%m-%d %H:%i:%s.%f')) AS latest_date
FROM
    user_events;
    
-- 3. OVERALL SALES FUNNEL
WITH funnel_stages AS (
    SELECT
        COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) AS stage_1_views,
        COUNT(DISTINCT CASE WHEN event_type = 'add_to_cart' THEN user_id END) AS stage_2_cart,
        COUNT(DISTINCT CASE WHEN event_type = 'checkout_start' THEN user_id END) AS stage_3_checkout,
        COUNT(DISTINCT CASE WHEN event_type = 'payment_info' THEN user_id END) AS stage_4_payment,
        COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS stage_5_purchase
    FROM user_events
    WHERE STR_TO_DATE(event_date,'%Y-%m-%d %H:%i:%s.%f') >= (SELECT DATE_SUB(MAX(STR_TO_DATE(event_date,'%Y-%m-%d %H:%i:%s.%f')),INTERVAL 30 DAY)
          FROM user_events
    )
)
SELECT
    stage_1_views,
    stage_2_cart,
    ROUND(stage_2_cart * 100.0 /NULLIF(stage_1_views, 0),2) AS view_to_cart_rate,

    stage_3_checkout,
    ROUND(stage_3_checkout * 100.0 /NULLIF(stage_2_cart, 0),2) AS cart_to_checkout_rate,

    stage_4_payment,
    ROUND(stage_4_payment * 100.0 /NULLIF(stage_3_checkout, 0),2) AS checkout_to_payment_rate,

    stage_5_purchase,
    ROUND(stage_5_purchase * 100.0 /NULLIF(stage_4_payment, 0),2) AS payment_to_purchase_rate,
    ROUND(stage_5_purchase * 100.0 /NULLIF(stage_1_views, 0),2) AS purchase_to_views_rate

FROM funnel_stages;

-- 4. FUNNEL BY TRAFFIC SOURCE
WITH source_funnel AS (
    SELECT
        traffic_source,
        COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) AS views,
        COUNT(DISTINCT CASE WHEN event_type = 'add_to_cart'THEN user_id END) AS cart,
        COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS purchase

    FROM user_events
    WHERE STR_TO_DATE(event_date,'%Y-%m-%d %H:%i:%s.%f') >= (SELECT DATE_SUB(MAX(STR_TO_DATE(event_date,'%Y-%m-%d %H:%i:%s.%f')),INTERVAL 30 DAY)
        FROM user_events
    )
    GROUP BY traffic_source
)
SELECT
    traffic_source,
    views,
    cart,
    purchase,
    ROUND(cart * 100.0 /NULLIF(views, 0),2) AS cart_conversion_rate,
    ROUND(purchase * 100.0 /NULLIF(views, 0),2) AS purchase_conversion_rate,
    ROUND(purchase * 100.0 /NULLIF(cart, 0),2) AS cart_to_purchase_conversion_rate
FROM source_funnel
ORDER BY purchase DESC;

-- 5. TIME TO CONVERSION ANALYSIS
WITH user_journey AS (
    SELECT
        user_id,
        MIN(CASE WHEN event_type = 'page_view' THEN STR_TO_DATE(event_date,'%Y-%m-%d %H:%i:%s.%f')END) AS view_time,
        MIN(CASE WHEN event_type = 'add_to_cart'THEN STR_TO_DATE(event_date,'%Y-%m-%d %H:%i:%s.%f')END) AS cart_time,
        MIN(CASE WHEN event_type = 'purchase'THEN STR_TO_DATE(event_date,'%Y-%m-%d %H:%i:%s.%f')END) AS purchase_time
    FROM user_events
    WHERE STR_TO_DATE(event_date,'%Y-%m-%d %H:%i:%s.%f') >= (SELECT DATE_SUB(MAX(STR_TO_DATE(event_date,'%Y-%m-%d %H:%i:%s.%f')),INTERVAL 30 DAY)
        FROM user_events
    )
    GROUP BY user_id
    HAVING purchase_time IS NOT NULL
)
SELECT
    COUNT(*) AS converted_users,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE,view_time,cart_time)),2) AS avg_view_to_cart_minutes,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE,cart_time,purchase_time)),2) AS avg_cart_to_purchase_minutes,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE,view_time,purchase_time)),2) AS avg_total_journey_minutes
FROM user_journey;

-- 6. REVENUE FUNNEL ANALYSIS
WITH funnel_revenue AS (
    SELECT
        COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) AS total_visitors,
        COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS total_buyers,
        SUM(CASE WHEN event_type = 'purchase'THEN CAST(amount AS DECIMAL(10,2)) END) AS total_revenue,
        COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) AS total_orders
    FROM user_events
    WHERE STR_TO_DATE(event_date,'%Y-%m-%d %H:%i:%s.%f') >= (SELECT DATE_SUB(MAX(STR_TO_DATE(event_date,'%Y-%m-%d %H:%i:%s.%f')),INTERVAL 30 DAY)
        FROM user_events
    )
)
SELECT
    total_visitors,
    total_buyers,
    total_orders,
    total_revenue,
    ROUND(total_revenue /NULLIF(total_orders, 0), 2) AS avg_order_value,
    ROUND(total_revenue /NULLIF(total_buyers, 0), 2) AS revenue_per_buyer,
    ROUND(total_revenue /NULLIF(total_visitors, 0),2) AS revenue_per_visitor

FROM funnel_revenue;