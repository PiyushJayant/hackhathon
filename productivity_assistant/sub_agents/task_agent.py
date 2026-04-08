"""
Task Agent
----------
Manages to-do tasks stored in AlloyDB via the MCP Toolbox for Databases.
The toolbox exposes task CRUD operations defined in mcp_toolbox/tools.yaml.
"""
from google.adk.agents import LlmAgent
from productivity_assistant.tools import load_toolset


def _build_task_agent() -> LlmAgent | None:
    task_tools = load_toolset("task-tools")
    if task_tools is None:
        return None

    return LlmAgent(
        model="gemini-2.5-flash",
        name="task_agent",
        description=(
            "Handles task management: create, list, update status, and delete tasks. "
            "Tasks are stored in AlloyDB for PostgreSQL."
        ),
        instruction="""You are a task management assistant. You manage tasks stored in AlloyDB.

You can:
- Create tasks with a title, description, priority (low/medium/high), and optional due date (YYYY-MM-DD)
- List tasks filtered by status (pending/in_progress/done) or list all tasks
- Update a task's status to pending, in_progress, or done
- Delete tasks by their ID

Always confirm actions and display task details clearly after each operation.
When listing tasks, format them as a readable list with ID, title, priority, and status.""",
        tools=task_tools,
    )

task_agent = _build_task_agent()
