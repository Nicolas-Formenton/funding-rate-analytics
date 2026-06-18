
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select symbol
from "postgres"."staging"."stg_funding_events"
where symbol is null



  
  
      
    ) dbt_internal_test