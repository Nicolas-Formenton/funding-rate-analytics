
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select symbol
from "funding_rates"."staging_marts"."mart_hourly_funding"
where symbol is null



  
  
      
    ) dbt_internal_test