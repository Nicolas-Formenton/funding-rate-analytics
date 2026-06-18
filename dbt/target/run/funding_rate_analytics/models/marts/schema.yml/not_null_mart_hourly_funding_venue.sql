
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select venue
from "postgres"."marts"."mart_hourly_funding"
where venue is null



  
  
      
    ) dbt_internal_test