"""Shared MCP tool helpers for the productivity assistant.

Uses the same patterns taught in the codelabs:
- MCP Toolbox for Databases (ToolboxSyncClient) → AlloyDB
- Google-hosted BigQuery MCP server (MCPToolset + StreamableHTTPConnectionParams) → BigQuery
"""
import logging
import os

import google.auth
import google.auth.transport.requests

from google.adk.tools.mcp_tool.mcp_toolset import MCPToolset
from google.adk.tools.mcp_tool.mcp_session_manager import StreamableHTTPConnectionParams
from toolbox_core import ToolboxSyncClient

LOGGER = logging.getLogger(__name__)
BIGQUERY_MCP_URL = "https://bigquery.googleapis.com/mcp"
TOOLBOX_URL = os.environ.get("TOOLBOX_URL", "http://127.0.0.1:5000")


def load_toolset(toolset_name: str):
    """Load a toolset from the configured MCP Toolbox server.

    Returns None when the toolbox is not reachable so Cloud Shell-only
    deployments can still start with the hosted BigQuery agent.
    """
    toolbox = None
    try:
        toolbox = ToolboxSyncClient(TOOLBOX_URL)
        return toolbox.load_toolset(toolset_name)
    except Exception as exc:  # pragma: no cover - startup resilience
        LOGGER.warning(
            "Skipping toolset %s because MCP Toolbox is unavailable at %s: %s",
            toolset_name,
            TOOLBOX_URL,
            exc,
        )
        return None
    finally:
        if toolbox is not None:
            toolbox.close()


def get_bigquery_mcp_toolset() -> MCPToolset:
    """Build a toolset for the Google-hosted BigQuery MCP server.

    Uses Application Default Credentials (ADC) with BigQuery scope and
    passes an OAuth Bearer token — the same pattern as the bakery / location
    intelligence codelab.
    """
    credentials, project_id = google.auth.default(
        scopes=["https://www.googleapis.com/auth/bigquery"]
    )
    credentials.refresh(google.auth.transport.requests.Request())

    return MCPToolset(
        connection_params=StreamableHTTPConnectionParams(
            url=BIGQUERY_MCP_URL,
            headers={
                "Authorization": f"Bearer {credentials.token}",
                "x-goog-user-project": os.environ.get("GOOGLE_CLOUD_PROJECT", project_id),
            },
            timeout=30.0,
            sse_read_timeout=300.0,
        )
    )