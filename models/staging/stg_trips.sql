select 
       VendorID as vendor_id,
        PULocationID as pickup_location_id,
        DOLocationID as dropoff_location_id,
        tpep_pickup_datetime as pickup_datetime,
        tpep_dropoff_datetime as dropoff_datetime,
        trip_distance,
        passenger_count,
        fare_amount,
        tip_amount, 
        tolls_amount, 
        total_amount,
        CASE when RatecodeID = 1 THEN 'Standard rate'
              when RatecodeID = 2 THEN 'JFK rate'
              when RatecodeID = 3 THEN 'Newark rate'
              when RatecodeID = 4 THEN 'Nassau/Westchester rate'
              when RatecodeID = 5 THEN 'Negotiated fare'
              when RatecodeID = 6 THEN 'Group ride'
              when RatecodeID = 99 THEN 'Unknown'
        END as rate_code_description,
        CASE when payment_type = 0 THEN 'Flex fare'
              when payment_type = 1 THEN 'Credit card'
              when payment_type = 2 THEN 'Cash'
              when payment_type = 3 THEN 'No charge'
              when payment_type = 4 THEN 'Dispute'
              when payment_type = 5 THEN 'Unknown'
              when payment_type = 6 THEN 'Voided trip'
        END as payment_type_description,
        date_trunc('month', tpep_pickup_datetime) as pickup_month
from {{ source('nyc_taxi', 'trips') }}