
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select date
from "funding_rates"."staging_marts"."mart_daily_funding"
where date is null



  
  
      
    ) dbt_internal_test