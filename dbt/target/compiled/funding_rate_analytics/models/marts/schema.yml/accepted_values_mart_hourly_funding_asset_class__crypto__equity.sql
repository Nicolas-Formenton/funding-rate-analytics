
    
    

with all_values as (

    select
        asset_class as value_field,
        count(*) as n_records

    from "postgres"."marts"."mart_hourly_funding"
    group by asset_class

)

select *
from all_values
where value_field not in (
    'crypto','equity'
)


