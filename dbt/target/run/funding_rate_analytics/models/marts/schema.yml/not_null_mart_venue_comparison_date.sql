
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select date
from "postgres"."marts"."mart_venue_comparison"
where date is null



  
  
      
    ) dbt_internal_test