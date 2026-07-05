select trips.pickup_location_id,
       trips.dropoff_location_id,
       trips.pickup_datetime,
       trips.dropoff_datetime,
       trips.trip_distance,
       trips.passenger_count,
       trips.fare_amount,
       trips.tip_amount, 
       trips.tolls_amount, 
       trips.total_amount,
       trips.rate_code_description,
       trips.payment_type_description,
       trips.pickup_month,
       vendors.vendor_name
from {{ ref('stg_trips') }} as trips
left join {{ ref('vendor') }} as vendors on trips.vendor_id = vendors.vendor_id
where dropoff_datetime >= pickup_datetime
and pickup_datetime >= '2026-01-01'