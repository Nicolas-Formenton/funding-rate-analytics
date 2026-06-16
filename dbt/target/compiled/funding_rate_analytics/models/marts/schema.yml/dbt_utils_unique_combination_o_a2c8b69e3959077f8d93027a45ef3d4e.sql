





with validation_errors as (

    select
        venue, symbol, hour_start
    from "funding_rates"."staging_marts"."mart_hourly_funding"
    group by venue, symbol, hour_start
    having count(*) > 1

)

select *
from validation_errors


