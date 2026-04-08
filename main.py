import logging
import os

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

logger.info("Starting productivity assistant...")

try:
    from google.adk.cli.fast_api import get_fast_api_app

    app = get_fast_api_app(
        agents_dir=os.path.dirname(os.path.abspath(__file__)),
        web=True,
    )
    logger.info("ADK FastAPI app created successfully")
except Exception as e:
    logger.error("Failed to create ADK app: %s", e, exc_info=True)
    from fastapi import FastAPI
    app = FastAPI(title="Productivity Assistant (fallback)")

    @app.get("/")
    def health():
        return {"status": "error", "detail": str(e)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
