





with validation_errors as (

    select
        venue, symbol, date
    from "funding_rates"."staging_marts"."mart_daily_funding"
    group by venue, symbol, date
    having count(*) > 1

)

select *
from validation_errors


