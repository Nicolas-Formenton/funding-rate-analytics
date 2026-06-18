
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select asset_class
from "postgres"."staging"."stg_funding_events"
where asset_class is null



  
  
      
    ) dbt_internal_test