WITH personas AS (
  SELECT
    customer_id,
    CASE
      WHEN avg_lead_time_days >= 7 AND total_filters_used >= 3 AND avg_guests >= 2
        THEN 'Advance Planner'
      WHEN avg_lead_time_days <= 2 AND mobile_events >= sessions_count * 0.6
        THEN 'Spontaneous / Last-Minute Booker'
      WHEN total_filters_used >= 5 AND used_discount = 1
        THEN 'Deal-Driven Explorer'
      WHEN lifetime_bookings >= 3
        THEN 'Repeat / Local Explorer'
      ELSE 'Other'
    END AS persona
  FROM (
    -- reuse your persona feature query here if needed
    SELECT
      b.customer_id,
      AVG(DATE_DIFF(experience_date, DATE(created_at), DAY)) AS avg_lead_time_days,
      AVG(number_of_guests) AS avg_guests,
      COUNT(*) AS total_bookings,
      COUNT(DISTINCT e.session_id) AS sessions_count,
      SUM(COALESCE(search_filters_used,0)+COALESCE(num_filters_applied,0)) AS total_filters_used,
      MAX(COALESCE(customer_lifetime_bookings,0)) AS lifetime_bookings,
      MAX(COALESCE(active_discount_flag,0)) AS used_discount,
      SUM(CASE WHEN LOWER(e.device) LIKE '%mobile%' THEN 1 ELSE 0 END) AS mobile_events
    FROM `headoutdata-assignment.user_persona_data.headout_dubai_bookings` b
    LEFT JOIN `headoutdata-assignment.user_persona_data.headout_events_data` e
      ON b.customer_id = e.customer_id
    WHERE b.city = 'Dubai'
    GROUP BY b.customer_id
  )
),
exposure AS (
  SELECT
    customer_id,
    experiment_bucket,
    MIN(event_timestamp) AS first_exposure_ts,
    SUM(COALESCE(rec_impressions,0)) AS impressions,
    SUM(COALESCE(rec_clicks,0)) AS clicks
  FROM `headoutdata-assignment.user_persona_data.headout_events_data`
  WHERE city = 'Dubai'
    AND (smart_rec_enabled = 1 OR COALESCE(rec_impressions,0) > 0)
  GROUP BY customer_id, experiment_bucket
),
bookings AS (
  SELECT
    customer_id,
    booking_id,
    created_at
  FROM `headoutdata-assignment.user_persona_data.headout_dubai_bookings`
  WHERE city = 'Dubai'
),

conversion AS (
  SELECT
    e.customer_id,
    e.experiment_bucket,
    COUNT(DISTINCT b.booking_id) AS bookings_7d
  FROM exposure e
  LEFT JOIN bookings b
    ON e.customer_id = b.customer_id
   AND b.created_at BETWEEN e.first_exposure_ts
                        AND TIMESTAMP_ADD(e.first_exposure_ts, INTERVAL 7 DAY)
  GROUP BY e.customer_id, e.experiment_bucket
)
SELECT
  p.persona,
  e.experiment_bucket,
  COUNT(DISTINCT e.customer_id) AS exposed_users,
  SAFE_DIVIDE(SUM(e.clicks), NULLIF(SUM(e.impressions),0)) AS rec_ctr,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN c.bookings_7d > 0 THEN e.customer_id END),
    COUNT(DISTINCT e.customer_id)
  ) AS conversion_rate_7d,
  AVG(c.bookings_7d) AS bookings_per_user
FROM exposure e
JOIN personas p
  ON e.customer_id = p.customer_id
LEFT JOIN conversion c
  ON e.customer_id = c.customer_id
 AND e.experiment_bucket = c.experiment_bucket
GROUP BY p.persona, e.experiment_bucket
ORDER BY p.persona, e.experiment_bucket;


