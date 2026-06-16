





with validation_errors as (

    select
        date, symbol
    from "funding_rates"."staging_marts"."mart_venue_comparison"
    group by date, symbol
    having count(*) > 1

)

select *
from validation_errors


