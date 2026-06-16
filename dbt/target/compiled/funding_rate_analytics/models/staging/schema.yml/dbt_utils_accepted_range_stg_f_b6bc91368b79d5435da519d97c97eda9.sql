

with meet_condition as(
  select *
  from "funding_rates"."staging_staging"."stg_funding_events"
),

validation_errors as (
  select *
  from meet_condition
  where
    -- never true, defaults to an empty result set. Exists to ensure any combo of the `or` clauses below succeeds
    1 = 2
    -- records with a value >= min_value are permitted. The `not` flips this to find records that don't meet the rule.
    or not funding_rate_annualized_pct >= -3000
    -- records with a value <= max_value are permitted. The `not` flips this to find records that don't meet the rule.
    or not funding_rate_annualized_pct <= 1000
)

select *
from validation_errors

