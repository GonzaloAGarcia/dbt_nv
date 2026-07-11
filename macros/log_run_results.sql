{% macro log_run_results(results) %}
{% if execute and results %}

create table if not exists main.dbt_run_results (
    invocation_id varchar,
    run_started_at timestamp,
    node_id varchar,
    status varchar,
    execution_time float,
    rows_affected int
);
insert into main.dbt_run_results values
{% for res in results -%}
    ('{{ invocation_id }}', '{{ run_started_at }}', '{{ res.node.unique_id }}', '{{ res.status }}', {{ res.execution_time | default(0, true)}}, {{ res.adapter_response.rows_affected or 0}}){{ ',' if not loop.last else ''}}
{%- endfor %};
{% endif %}
{% endmacro %}