"""
Root Agent — Multi-Agent Productivity Assistant
------------------------------------------------
Coordinator that routes user requests to the appropriate sub-agent using
ADK's built-in LLM-driven transfer based on each sub-agent's description.
"""
from google.adk.agents import LlmAgent

from productivity_assistant.sub_agents.task_agent import task_agent
from productivity_assistant.sub_agents.notes_agent import notes_agent
from productivity_assistant.sub_agents.calendar_agent import calendar_agent
from productivity_assistant.sub_agents.analytics_agent import analytics_agent

sub_agents = [
    agent
    for agent in [task_agent, notes_agent, calendar_agent, analytics_agent]
    if agent is not None
]

root_agent = LlmAgent(
    model="gemini-2.5-flash",
    name="productivity_assistant",
    description=(
        "A multi-agent productivity assistant backed by AlloyDB AI and BigQuery on Google Cloud. "
        "Manages tasks, notes, calendar events, and provides productivity analytics."
    ),
    instruction="""You are a smart productivity assistant powered by Google Cloud.
You coordinate four specialized sub-agents — each backed by a different GCP data service.

Sub-agents and when to use them:
1. task_agent       → Tasks, to-dos, assignments, work items (AlloyDB)
2. notes_agent      → Notes, memos, ideas, write-downs (AlloyDB AI semantic search)
3. calendar_agent   → Meetings, events, appointments, scheduling (AlloyDB)
4. analytics_agent  → Productivity trends, insights, reports, statistics (BigQuery)

Routing rules:
- "create/list/update/delete task" → task_agent
- "create/search/list/delete note" → notes_agent
- "schedule/create/list event or meeting" → calendar_agent
- "how many tasks / trends / completion rate / insights" → analytics_agent

For multi-step requests (e.g. "add a task AND schedule a meeting"), handle each
step sequentially by delegating to the appropriate sub-agent one at a time.

Always be concise, confirm completed actions, and guide the user on what you can do.""",
    sub_agents=sub_agents,
)
