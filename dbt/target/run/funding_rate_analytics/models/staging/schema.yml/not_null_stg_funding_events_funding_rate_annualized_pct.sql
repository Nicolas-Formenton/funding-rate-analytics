
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select funding_rate_annualized_pct
from "postgres"."staging"."stg_funding_events"
where funding_rate_annualized_pct is null



  
  
      
    ) dbt_internal_test