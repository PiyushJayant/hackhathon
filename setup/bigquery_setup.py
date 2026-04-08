"""
BigQuery Analytics Setup Script
================================
Creates the `productivity_analytics` dataset with tables for task and activity
insights. Run once before deploying the analytics agent.

Usage:
    python setup/bigquery_setup.py
"""
import os
from google.cloud import bigquery

PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT")
DATASET_ID = "productivity_analytics"

client = bigquery.Client(project=PROJECT_ID)


def create_dataset():
    dataset_ref = bigquery.Dataset(f"{PROJECT_ID}.{DATASET_ID}")
    dataset_ref.location = "US"
    dataset_ref.description = "Productivity analytics for the Multi-Agent Assistant"
    client.create_dataset(dataset_ref, exists_ok=True)
    print(f"[OK] Dataset '{DATASET_ID}' ready.")


def create_task_summary_table():
    schema = [
        bigquery.SchemaField("date", "DATE", description="Day of the record"),
        bigquery.SchemaField("priority", "STRING", description="Task priority: low/medium/high"),
        bigquery.SchemaField("total_tasks", "INTEGER"),
        bigquery.SchemaField("completed_tasks", "INTEGER"),
        bigquery.SchemaField("pending_tasks", "INTEGER"),
        bigquery.SchemaField("in_progress_tasks", "INTEGER"),
        bigquery.SchemaField("completion_rate", "FLOAT", description="Fraction of tasks completed (0-1)"),
    ]
    table_ref = bigquery.Table(f"{PROJECT_ID}.{DATASET_ID}.task_summary", schema=schema)
    client.create_table(table_ref, exists_ok=True)
    print("[OK] Table 'task_summary' ready.")


def create_daily_activity_table():
    schema = [
        bigquery.SchemaField("date", "DATE"),
        bigquery.SchemaField("tasks_created", "INTEGER"),
        bigquery.SchemaField("tasks_completed", "INTEGER"),
        bigquery.SchemaField("notes_created", "INTEGER"),
        bigquery.SchemaField("events_scheduled", "INTEGER"),
    ]
    table_ref = bigquery.Table(f"{PROJECT_ID}.{DATASET_ID}.daily_activity", schema=schema)
    client.create_table(table_ref, exists_ok=True)
    print("[OK] Table 'daily_activity' ready.")


def seed_sample_data():
    """Insert demo data so the analytics agent has something to query."""

    # Task summary rows (last 7 days)
    task_rows = [
        {"date": "2026-04-01", "priority": "high",   "total_tasks": 5,  "completed_tasks": 4, "pending_tasks": 0, "in_progress_tasks": 1, "completion_rate": 0.80},
        {"date": "2026-04-01", "priority": "medium", "total_tasks": 8,  "completed_tasks": 5, "pending_tasks": 2, "in_progress_tasks": 1, "completion_rate": 0.625},
        {"date": "2026-04-01", "priority": "low",    "total_tasks": 4,  "completed_tasks": 2, "pending_tasks": 2, "in_progress_tasks": 0, "completion_rate": 0.50},
        {"date": "2026-04-02", "priority": "high",   "total_tasks": 3,  "completed_tasks": 3, "pending_tasks": 0, "in_progress_tasks": 0, "completion_rate": 1.00},
        {"date": "2026-04-02", "priority": "medium", "total_tasks": 6,  "completed_tasks": 4, "pending_tasks": 1, "in_progress_tasks": 1, "completion_rate": 0.667},
        {"date": "2026-04-03", "priority": "high",   "total_tasks": 4,  "completed_tasks": 3, "pending_tasks": 1, "in_progress_tasks": 0, "completion_rate": 0.75},
        {"date": "2026-04-03", "priority": "low",    "total_tasks": 10, "completed_tasks": 6, "pending_tasks": 3, "in_progress_tasks": 1, "completion_rate": 0.60},
        {"date": "2026-04-04", "priority": "high",   "total_tasks": 6,  "completed_tasks": 5, "pending_tasks": 0, "in_progress_tasks": 1, "completion_rate": 0.833},
        {"date": "2026-04-05", "priority": "high",   "total_tasks": 4,  "completed_tasks": 4, "pending_tasks": 0, "in_progress_tasks": 0, "completion_rate": 1.00},
        {"date": "2026-04-05", "priority": "medium", "total_tasks": 7,  "completed_tasks": 5, "pending_tasks": 1, "in_progress_tasks": 1, "completion_rate": 0.714},
        {"date": "2026-04-06", "priority": "high",   "total_tasks": 5,  "completed_tasks": 5, "pending_tasks": 0, "in_progress_tasks": 0, "completion_rate": 1.00},
        {"date": "2026-04-06", "priority": "medium", "total_tasks": 8,  "completed_tasks": 6, "pending_tasks": 1, "in_progress_tasks": 1, "completion_rate": 0.75},
        {"date": "2026-04-07", "priority": "high",   "total_tasks": 3,  "completed_tasks": 2, "pending_tasks": 0, "in_progress_tasks": 1, "completion_rate": 0.667},
    ]
    errors = client.insert_rows_json(f"{PROJECT_ID}.{DATASET_ID}.task_summary", task_rows)
    print(f"[{'OK' if not errors else 'ERR'}] task_summary seeded{': ' + str(errors) if errors else ''}.")

    # Daily activity rows
    activity_rows = [
        {"date": "2026-04-01", "tasks_created": 8,  "tasks_completed": 5, "notes_created": 4, "events_scheduled": 2},
        {"date": "2026-04-02", "tasks_created": 5,  "tasks_completed": 7, "notes_created": 3, "events_scheduled": 1},
        {"date": "2026-04-03", "tasks_created": 9,  "tasks_completed": 4, "notes_created": 6, "events_scheduled": 3},
        {"date": "2026-04-04", "tasks_created": 6,  "tasks_completed": 8, "notes_created": 2, "events_scheduled": 2},
        {"date": "2026-04-05", "tasks_created": 4,  "tasks_completed": 9, "notes_created": 1, "events_scheduled": 1},
        {"date": "2026-04-06", "tasks_created": 10, "tasks_completed": 6, "notes_created": 7, "events_scheduled": 4},
        {"date": "2026-04-07", "tasks_created": 6,  "tasks_completed": 4, "notes_created": 3, "events_scheduled": 2},
    ]
    errors = client.insert_rows_json(f"{PROJECT_ID}.{DATASET_ID}.daily_activity", activity_rows)
    print(f"[{'OK' if not errors else 'ERR'}] daily_activity seeded{': ' + str(errors) if errors else ''}.")


if __name__ == "__main__":
    if not PROJECT_ID:
        raise ValueError("GOOGLE_CLOUD_PROJECT environment variable is not set.")
    print(f"Setting up BigQuery analytics in project: {PROJECT_ID}")
    create_dataset()
    create_task_summary_table()
    create_daily_activity_table()
    seed_sample_data()
    print("\nBigQuery setup complete!")
