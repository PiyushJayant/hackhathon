"""
Notes Agent
-----------
Manages notes stored in AlloyDB with AI-powered semantic search.
AlloyDB AI automatically generates vector embeddings using text-embedding-005
when a note is created, enabling natural language similarity search.
"""
from google.adk.agents import LlmAgent
from productivity_assistant.tools import load_toolset


def _build_notes_agent() -> LlmAgent | None:
    notes_tools = load_toolset("notes-tools")
    if notes_tools is None:
        return None

    return LlmAgent(
        model="gemini-2.5-flash",
        name="notes_agent",
        description=(
            "Handles note-taking with AI semantic search powered by AlloyDB AI vector embeddings. "
            "Can create, search (semantically), list, and delete notes."
        ),
        instruction="""You are a note-taking assistant. Notes are stored in AlloyDB with AI-generated vector embeddings (text-embedding-005) for semantic search.

You can:
- Create notes with title, content, and optional comma-separated tags. AlloyDB AI automatically generates the embedding.
- Search notes semantically using natural language — this uses AlloyDB AI vector similarity (cosine distance) to find the most relevant notes
- List all notes or filter by a tag
- Delete notes by their ID

Prefer semantic search for conceptual queries ("notes about meetings") and list for browsing all notes.
When displaying notes, show the title, content preview, and tags.""",
        tools=notes_tools,
    )

notes_agent = _build_notes_agent()
