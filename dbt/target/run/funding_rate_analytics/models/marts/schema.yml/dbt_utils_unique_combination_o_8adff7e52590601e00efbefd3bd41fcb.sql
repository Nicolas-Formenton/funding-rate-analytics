
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  





with validation_errors as (

    select
        venue, symbol, date
    from "funding_rates"."staging_marts"."mart_daily_funding"
    group by venue, symbol, date
    having count(*) > 1

)

select *
from validation_errors



  
  
      
    ) dbt_internal_test