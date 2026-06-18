





with validation_errors as (

    select
        date, symbol, venue_long, venue_short
    from "postgres"."marts"."mart_venue_comparison"
    group by date, symbol, venue_long, venue_short
    having count(*) > 1

)

select *
from validation_errors


