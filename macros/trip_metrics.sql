{% macro trip_metrics() %}

count(*) as trip_count,
avg(trip_duration_min) as avg_trip_duration_min,
sum(total_amount) as total_revenue,
avg(trip_distance) as avg_distance,
avg(fare_amount) as avg_fare_amount,
{{safe_divide('sum(tip_amount)', 'sum(fare_amount)')}} as weighted_tip_pct

{% endmacro %}