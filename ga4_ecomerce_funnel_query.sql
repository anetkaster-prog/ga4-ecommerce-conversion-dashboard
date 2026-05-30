/**
 * GA4 E-commerce Conversion Funnel & Marketing Analytics Query
 * 
 * Description: 
 * This query extracts session-level marketing dimensions and combines them 
 * with granular user behavioral events from the public GA4 e-commerce dataset.
 * The resulting flat table is optimized for building interactive funnel charts 
 * and marketing performance dashboards in Tableau.
 *
 * Technologies: Google BigQuery SQL, Regular Expressions (Regex), Struct/Array Unnesting.
 */

WITH session_events AS (
  SELECT
    -- User and Session Identification
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id,
    
    -- Composite Key: Guarantees unique session tracking across different users
    CONCAT(
      user_pseudo_id, 
      '-', 
      (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id')
    ) AS user_session_id,
    
    -- URL Parsing: Extracts the first subdirectory path (e.g., 'home' or 'apparel') as the landing location
    REGEXP_EXTRACT(
      (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'),
      r'^https?:\/\/[^\/]+\/([^\/]+)'
    ) AS landing_page_location,
   
    -- User Device & Operating System Dimensions
    device.category AS device_category,
    device.language AS device_language,
    device.operating_system AS device_os,
    
    -- Marketing Acquisition Traffic Channels (Source, Medium, Campaign)
    traffic_source.source AS traffic_source,
    traffic_source.medium AS traffic_medium,
    traffic_source.name AS traffic_campaign
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` e
  WHERE 
    -- Isomorphic Filtering: Isolates data strictly at the inception of the user session
    event_name = 'session_start'
),
    
events AS (
  SELECT 
    -- Event timestamp converted from microseconds to standard Timestamp format
    TIMESTAMP_MICROS(event_timestamp) AS session_start_time, 
    event_name,
    
    -- Composite Key for accurate mapping during the upcoming JOIN
    CONCAT(
      user_pseudo_id, 
      '-', 
      (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id')
    ) AS user_session_id
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` e
  WHERE 
    -- Optimization Whitelist: Keeping only the specific 7 milestones needed for the marketing funnel
    event_name IN (
                    'session_start', 
                    'view_item', 
                    'add_to_cart', 
                    'begin_checkout', 
                    'add_shipping_info', 
                    'add_payment_info', 
                    'purchase'
                  )
)

-- FINAL LAYER: Combining acquisition metadata with sequential user actions
SELECT
  -- Identifiers
  se.user_session_id,
  se.user_pseudo_id,
  se.ga_session_id,
  
  -- Technical & Regional Segments
  se.device_category,
  se.device_language,
  se.device_os,
  
  -- Marketing Tag Dimensions
  se.traffic_source,
  se.traffic_medium,
  se.traffic_campaign, 
  se.landing_page_location,
  
  -- Behavioral Metrics for Funnel Mapping
  ev.session_start_time,
  ev.event_name
FROM 
  session_events se
LEFT JOIN 
  events ev ON se.user_session_id = ev.user_session_id;

