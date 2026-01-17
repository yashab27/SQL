--Lead Time Distribution (Advance vs Last-Minute)
SELECT
  AVG(DATE_DIFF(experience_date, DATE(created_at), DAY)) AS avg_lead_days,
  APPROX_QUANTILES(
    DATE_DIFF(experience_date, DATE(created_at), DAY),
    100
  )[OFFSET(50)] AS p50_lead_days,
  APPROX_QUANTILES(
    DATE_DIFF(experience_date, DATE(created_at), DAY),
    100
  )[OFFSET(90)] AS p90_lead_days
FROM `headoutdata-assignment.user_persona_data.headout_dubai_bookings`
WHERE city = 'Dubai'
  AND experience_date IS NOT NULL
  AND created_at IS NOT NULL;

--Number of Guests Distribution (Solo vs Group)
SELECT
  AVG(number_of_guests) AS avg_guests,
  APPROX_QUANTILES(number_of_guests, 100)[OFFSET(50)] AS p50_guests,
  APPROX_QUANTILES(number_of_guests, 100)[OFFSET(90)] AS p90_guests
FROM `headoutdata-assignment.user_persona_data.headout_dubai_bookings`
WHERE city = 'Dubai'
  AND number_of_guests IS NOT NULL;

--Sessions per User (Engagement Depth)
SELECT
  AVG(sessions_count) AS avg_sessions,
  APPROX_QUANTILES(sessions_count, 100)[OFFSET(50)] AS p50_sessions,
  APPROX_QUANTILES(sessions_count, 100)[OFFSET(90)] AS p90_sessions
FROM (
  SELECT
    customer_id,
    COUNT(DISTINCT session_id) AS sessions_count
  FROM `headoutdata-assignment.user_persona_data.headout_events_data`
  WHERE city = 'Dubai'
  GROUP BY customer_id
);

--Search Depth (Filters Used)
SELECT
  AVG(total_filters_used) AS avg_filters,
  APPROX_QUANTILES(total_filters_used, 100)[OFFSET(50)] AS p50_filters,
  APPROX_QUANTILES(total_filters_used, 100)[OFFSET(90)] AS p90_filters
FROM (
  SELECT
    customer_id,
    SUM(
      COALESCE(search_filters_used, 0)
      + COALESCE(num_filters_applied, 0)
    ) AS total_filters_used
  FROM `headoutdata-assignment.user_persona_data.headout_events_data`
  WHERE city = 'Dubai'
  GROUP BY customer_id
);
