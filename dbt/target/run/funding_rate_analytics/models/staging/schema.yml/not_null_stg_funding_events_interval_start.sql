
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select interval_start
from "funding_rates"."staging_staging"."stg_funding_events"
where interval_start is null



  
  
      
    ) dbt_internal_test