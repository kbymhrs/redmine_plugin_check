# AI Analysis

Plugin Compatibility Check can generate an AI-friendly Markdown report.

It can also submit the report to an OpenAI-compatible Chat Completions API.

## Recommended AI Workflow

Before modifying any plugin:

1. Search for maintained forks.
2. Search for the latest release.
3. Read migration notes.
4. Only patch the plugin if no maintained alternative exists.

After upgrading:

- Run migrations.
- Start Redmine.
- Verify actual plugin behavior.

Starting Redmine successfully does not guarantee compatibility.

## Configuration

Configure:

- Endpoint
- API key
- Model
- Timeout
- Prompt

API keys should preferably be supplied via environment variables.
