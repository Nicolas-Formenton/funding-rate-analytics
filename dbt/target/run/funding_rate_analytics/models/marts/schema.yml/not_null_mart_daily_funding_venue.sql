
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select venue
from "funding_rates"."staging_marts"."mart_daily_funding"
where venue is null



  
  
      
    ) dbt_internal_test