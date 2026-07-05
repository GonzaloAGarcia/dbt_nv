{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='pickup_datetime',
    begin='2026-01-01',
    batch_size='month',
    lookback=5,
    full_refresh=false
) }}

select 
       vendor_name,
       pickup_location_id,
        dropoff_location_id,
        pickup_datetime,
        dropoff_datetime,
        datediff('minute', pickup_datetime, dropoff_datetime) as trip_duration_min,
        trip_distance,
        passenger_count,
        fare_amount,
        tip_amount, 
        tolls_amount, 
        total_amount,
        rate_code_description,
        payment_type_description,
        pickup_month
from {{ ref('int_trips_joined_to_vendors') }}