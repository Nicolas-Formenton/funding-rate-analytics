
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select venue_short
from "postgres"."marts"."mart_venue_comparison"
where venue_short is null



  
  
      
    ) dbt_internal_test