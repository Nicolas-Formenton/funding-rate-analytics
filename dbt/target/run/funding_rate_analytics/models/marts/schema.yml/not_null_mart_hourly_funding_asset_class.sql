
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select asset_class
from "postgres"."marts"."mart_hourly_funding"
where asset_class is null



  
  
      
    ) dbt_internal_test