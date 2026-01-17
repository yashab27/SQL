WITH exposure AS (
  SELECT
    customer_id,
    experiment_bucket,
    MIN(event_timestamp) AS first_exposure_ts,
    SUM(COALESCE(rec_impressions, 0)) AS impressions,
    SUM(COALESCE(rec_clicks, 0)) AS clicks
  FROM `headoutdata-assignment.user_persona_data.headout_events_data`
  WHERE city = 'Dubai'
    AND (smart_rec_enabled = 1 OR COALESCE(rec_impressions, 0) > 0)
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

conversion_7d AS (
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
  e.experiment_bucket,
  COUNT(DISTINCT e.customer_id) AS exposed_users,
  SAFE_DIVIDE(SUM(clicks), NULLIF(SUM(impressions),0)) AS rec_ctr,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN bookings_7d > 0 THEN e.customer_id END),
    COUNT(DISTINCT e.customer_id)
  ) AS conversion_rate,
  AVG(bookings_7d) AS bookings_per_user
FROM exposure e
LEFT JOIN conversion_7d c
  ON e.customer_id = c.customer_id
 AND e.experiment_bucket = c.experiment_bucket
GROUP BY experiment_bucket;
