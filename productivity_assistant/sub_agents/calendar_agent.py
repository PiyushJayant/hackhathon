"""
Calendar Agent
--------------
Manages calendar events stored in AlloyDB via the MCP Toolbox for Databases.
"""
from google.adk.agents import LlmAgent
from productivity_assistant.tools import load_toolset


def _build_calendar_agent() -> LlmAgent | None:
    calendar_tools = load_toolset("calendar-tools")
    if calendar_tools is None:
        return None

    return LlmAgent(
        model="gemini-2.5-flash",
        name="calendar_agent",
        description=(
            "Handles calendar events and scheduling: create, list, and delete events. "
            "Events are stored in AlloyDB for PostgreSQL."
        ),
        instruction="""You are a calendar and scheduling assistant. Events are stored in AlloyDB.

You can:
- Create events with title, date (YYYY-MM-DD), time (HH:MM 24-hour), duration in minutes, and optional description
- List all events or filter by a specific date
- Delete events by their ID

Always confirm actions and display event details clearly.
When listing events, format them chronologically with date, time, and title.""",
        tools=calendar_tools,
    )

calendar_agent = _build_calendar_agent()
