
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  





with validation_errors as (

    select
        venue, symbol, hour_start
    from "funding_rates"."staging_marts"."mart_hourly_funding"
    group by venue, symbol, hour_start
    having count(*) > 1

)

select *
from validation_errors



  
  
      
    ) dbt_internal_test