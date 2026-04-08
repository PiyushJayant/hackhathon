"""
Analytics Agent
---------------
Provides productivity insights by querying the BigQuery `productivity_analytics`
dataset using the Google-hosted BigQuery MCP server.

Authentication uses Application Default Credentials (ADC) with BigQuery scope,
following the same pattern as the Location Intelligence (bakery) codelab.
"""
import logging
import os

from google.adk.agents import LlmAgent
from productivity_assistant.tools import get_bigquery_mcp_toolset

LOGGER = logging.getLogger(__name__)
GOOGLE_CLOUD_PROJECT = os.environ.get("GOOGLE_CLOUD_PROJECT", "")


def _build_analytics_agent() -> LlmAgent | None:
    try:
        bq_toolset = get_bigquery_mcp_toolset()
    except Exception as exc:
        LOGGER.warning("Analytics agent disabled — BigQuery MCP init failed: %s", exc)
        return None

    return LlmAgent(
        model="gemini-2.5-flash",
        name="analytics_agent",
        description=(
            "Provides productivity analytics and insights by querying the BigQuery "
            "`productivity_analytics` dataset using the Google-hosted BigQuery MCP server."
        ),
        instruction=f"""You are a productivity analytics assistant. You query BigQuery to surface insights.

BigQuery dataset: `{GOOGLE_CLOUD_PROJECT}.productivity_analytics`

Available tables:
- `task_summary`   — daily task counts and completion rates grouped by priority
  Columns: date, priority, total_tasks, completed_tasks, pending_tasks, in_progress_tasks, completion_rate
- `daily_activity` — daily counts of all productivity actions
  Columns: date, tasks_created, tasks_completed, notes_created, events_scheduled

You can answer questions like:
- "How many tasks did I complete this week?"
- "What is my task completion rate by priority?"
- "Show my productivity trends for the past 7 days"
- "Which day was I most productive?"
- "How many notes did I create this month?"

Always write concise SQL queries against the dataset above and present results clearly with actionable insights.""",
        tools=[bq_toolset],
    )


analytics_agent = _build_analytics_agent()
