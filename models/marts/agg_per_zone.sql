select 
pickup_zone.location_id as location_id,
pickup_zone.zone as pickup_zone,
pickup_zone.borough as pickup_borough,
{{trip_metrics()}}
from {{ref('fct_trips')}}
left join {{ref('dim_zones')}} as pickup_zone on fct_trips.pickup_location_id = pickup_zone.location_id
group by pickup_zone.location_id,pickup_zone.zone,
pickup_zone.borough