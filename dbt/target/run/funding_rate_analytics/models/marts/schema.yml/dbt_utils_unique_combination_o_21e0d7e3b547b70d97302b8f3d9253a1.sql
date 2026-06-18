
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  





with validation_errors as (

    select
        date, symbol, venue_long, venue_short
    from "postgres"."marts"."mart_venue_comparison"
    group by date, symbol, venue_long, venue_short
    having count(*) > 1

)

select *
from validation_errors



  
  
      
    ) dbt_internal_test