# Demo Video Script

Target length: under 3 minutes

## 0:00 - 0:20
Introduce the project:

"This is Multi-Agent Productivity Assistant, a Google Cloud based GenAI productivity workspace. It combines task management, notes, calendar scheduling, and productivity analytics in one conversational assistant."

## 0:20 - 0:50
Explain the core architecture:

"A root agent built with Google ADK routes each request to specialized task, notes, calendar, or analytics agents. MCP is used as the tool boundary. AlloyDB stores operational data, AlloyDB AI powers semantic note search, and BigQuery powers analytics."

## 0:50 - 1:25
Walk through the live deployment:

- Open the direct app URL for `productivity_assistant`.
- Show the public ADK interface.
- Point out the available agents.
- Mention that the app is deployed on Cloud Run and uses Gemini through Vertex AI.

Suggested line:

"The app is deployed publicly on Cloud Run, so judges can access it directly. The coordinator routes user intent to the right specialist agent, which keeps the system modular and scalable."

## 1:25 - 2:10
Show the key capabilities:

- Task creation and status updates
- Semantic note search
- Calendar event scheduling
- BigQuery analytics and completion-rate insights

Suggested line:

"Instead of using separate tools, users can ask the assistant to create a task, save an idea, schedule an event, or ask for weekly productivity insights in one place."

## 2:10 - 2:40
Show the GitHub repository and README:

- Open the repo page
- Scroll through the architecture and GCP services section
- Mention Cloud Run, ADK, MCP Toolbox, AlloyDB AI, and BigQuery

Suggested line:

"The repository documents the complete architecture, deployment setup, database schema, and analytics workflow. The design is production-oriented and reproducible."

## 2:40 - 2:55
Close with impact:

"This solution reduces productivity fragmentation by combining action, memory, scheduling, and insight in one cloud-native assistant. It demonstrates how ADK, MCP, AlloyDB AI, and BigQuery can be combined into a practical real-world product."

## Recording Checklist

- Use the public Cloud Run URL: `https://productivity-assistant-yzgwwb6nzq-uc.a.run.app/dev-ui/?app=productivity_assistant`
- Use the browser repo URL: `https://github.com/PiyushJayant/hackhathon`
- Keep the final video under 3 minutes
- Upload the video somewhere public and add that link to the submission form and slide 11
