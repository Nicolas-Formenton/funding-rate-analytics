
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  





with validation_errors as (

    select
        date, symbol
    from "funding_rates"."staging_marts"."mart_venue_comparison"
    group by date, symbol
    having count(*) > 1

)

select *
from validation_errors



  
  
      
    ) dbt_internal_test