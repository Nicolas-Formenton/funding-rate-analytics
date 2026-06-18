#!/usr/bin/env python3
"""Create Superset Dashboard 1 — Funding Rate Overview.

Uses `docker exec` to run inside the Superset container because the REST API
has an AnonymousUserMixin bug on Superset 4.0.0 when creating charts/dashboards.

Usage:
    python3 scripts/setup_superset_dashboard.py
"""

import json
import subprocess
import sys

CONTAINER = "superset"
DATASET_ID = 3

CHARTS = [
    {
        "name": "Daily Funding Rate Trend",
        "viz_type": "echarts_timeseries_line",
        "description": "Average daily funding rate (bps) by venue over time",
        "params": {
            "datasource": f"{DATASET_ID}__table",
            "viz_type": "echarts_timeseries_line",
            "x_axis": "date",
            "time_grain_sqla": "P1D",
            "metrics": [{"expressionType": "SQL", "sqlExpression": "AVG(avg_rate_bps)", "label": "Avg Rate (bps)"}],
            "groupby": ["venue"],
            "adhoc_filters": [],
            "row_limit": 10000,
            "show_legend": True,
            "rich_tooltip": True,
            "x_axis_time_format": "%Y-%m-%d",
            "y_axis_format": ",.0f",
        },
    },
    {
        "name": "Top 10 Funding Rate Events",
        "viz_type": "table",
        "description": "Top 10 highest absolute funding rate events",
        "params": {
            "datasource": f"{DATASET_ID}__table",
            "viz_type": "table",
            "query_mode": "raw",
            "all_columns": ["date", "venue", "symbol", "avg_rate_bps", "asset_class"],
            "order_by_cols": ["[\"avg_rate_bps\",false]"],
            "row_limit": 10,
            "page_length": 10,
            "include_search": False,
            "table_timestamp_format": "%Y-%m-%d",
            "show_cell_bars": True,
            "color_pn": True,
        },
    },
    {
        "name": "Rate Distribution by Venue",
        "viz_type": "box_plot",
        "description": "Box plot showing funding rate distribution per venue",
        "params": {
            "datasource": f"{DATASET_ID}__table",
            "viz_type": "box_plot",
            "columns": ["venue"],
            "metrics": [{"expressionType": "SQL", "sqlExpression": "avg_rate_bps", "label": "Rate (bps)"}],
            "groupby": [],
            "whisker_options": "Tukey",
            "show_legend": True,
        },
    },
    {
        "name": "Volatility Over Time (7d Rolling Std)",
        "viz_type": "echarts_timeseries_line",
        "description": "Rate volatility over time by venue",
        "params": {
            "datasource": f"{DATASET_ID}__table",
            "viz_type": "echarts_timeseries_line",
            "x_axis": "date",
            "time_grain_sqla": "P1D",
            "metrics": [{"expressionType": "SQL", "sqlExpression": "rate_volatility", "label": "Rate Volatility"}],
            "groupby": ["venue"],
            "adhoc_filters": [],
            "row_limit": 10000,
            "show_legend": True,
            "rich_tooltip": True,
            "x_axis_time_format": "%Y-%m-%d",
            "y_axis_format": ",.1f",
        },
    },
]

PYTHON_SCRIPT = '''
import json, os
os.environ.setdefault("SUPERSET_CONFIG_PATH", "/app/pythonpath/superset_config.py")
from superset.app import create_app
app = create_app()
with app.app_context():
    from superset import db
    from superset.connectors.sqla.models import SqlaTable
    from superset.models.slice import Slice
    from superset.models.dashboard import Dashboard
    from flask_appbuilder.security.sqla.models import User

    admin = db.session.query(User).filter_by(username="admin").first()
    ds = db.session.query(SqlaTable).filter_by(id={dataset_id}).first()
    if not admin or not ds:
        print("ERROR: admin or dataset not found")
        exit(1)

    charts_json = {charts_json}
    names = {names}
    chart_ids = []
    for i, cj in enumerate(charts_json):
        c = Slice(
            slice_name=names[i],
            viz_type=cj["viz_type"],
            datasource_id={dataset_id},
            datasource_type="table",
            params=json.dumps(cj["params"]),
            description=cj["description"],
        )
        c.owners = [admin]
        db.session.add(c)
        db.session.flush()
        chart_ids.append(c.id)
        print(f"Chart {{i+1}}: id={{c.id}} name={{names[i]}}")

    positions = {{
        "DASHBOARD_VERSION_KEY": "v2",
        "ROOT_ID": {{"type": "ROOT", "id": "ROOT_ID", "children": ["GRID_ID"]}},
        "GRID_ID": {{"type": "GRID", "id": "GRID_ID", "children": ["ROW-1", "ROW-2"], "parents": ["ROOT_ID"]}},
        "HEADER_ID": {{"type": "HEADER", "id": "HEADER_ID", "meta": {{"text": "Funding Rate Overview"}}}},
        "ROW-1": {{"type": "ROW", "id": "ROW-1", "children": [f"CHART-{{chart_ids[0]}}", f"CHART-{{chart_ids[1]}}"], "parents": ["ROOT_ID", "GRID_ID"], "meta": {{"background": "BACKGROUND_TRANSPARENT"}}}},
        "ROW-2": {{"type": "ROW", "id": "ROW-2", "children": [f"CHART-{{chart_ids[2]}}", f"CHART-{{chart_ids[3]}}"], "parents": ["ROOT_ID", "GRID_ID"], "meta": {{"background": "BACKGROUND_TRANSPARENT"}}}},
    }}
    for i, cid in enumerate(chart_ids):
        positions[f"CHART-{{cid}}"] = {{
            "type": "CHART", "id": f"CHART-{{cid}}", "children": [],
            "meta": {{"width": 6, "height": 50, "chartId": cid, "sliceName": names[i]}}
        }}

    dash = Dashboard(
        dashboard_title="Funding Rate Overview",
        slug="funding-rate-overview",
        published=True,
        position_json=json.dumps(positions),
    )
    dash.owners = [admin]
    db.session.add(dash)
    db.session.flush()
    dash.slices = [db.session.query(Slice).get(cid) for cid in chart_ids]
    db.session.commit()
    print(f"Dashboard: id={{dash.id}}")
    print(f"URL: http://localhost:8088/superset/dashboard/{{dash.id}}/")
    print("DONE")
'''.format(
    dataset_id=DATASET_ID,
    charts_json=json.dumps([{"viz_type": c["viz_type"], "params": c["params"], "description": c["description"]} for c in CHARTS]),
    names=json.dumps([c["name"] for c in CHARTS]),
)


def main():
    print("Creating Dashboard 1 — Funding Rate Overview")
    print(f"Dataset: marts.mart_daily_funding (id={DATASET_ID})")
    print(f"Charts: {len(CHARTS)}\n")

    result = subprocess.run(
        ["docker", "exec", CONTAINER, "python3", "-c", PYTHON_SCRIPT],
        capture_output=True, text=True, timeout=30,
    )
    for line in result.stdout.strip().split("\n"):
        print(f"  {line}")
    if result.returncode != 0:
        print(f"\nFAILED:\n{result.stderr}", file=sys.stderr)
        sys.exit(1)

    export = {
        "dashboard": {"title": "Funding Rate Overview", "slug": "funding-rate-overview"},
        "charts": [{"name": c["name"], "viz_type": c["viz_type"]} for c in CHARTS],
        "dataset": {"id": DATASET_ID, "schema": "marts", "table": "mart_daily_funding"},
    }
    export_path = "superset/dashboard1_export.json"
    with open(export_path, "w") as f:
        json.dump(export, f, indent=2)
    print(f"\nExport saved to {export_path}")


if __name__ == "__main__":
    main()
