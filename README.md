# Plugin Compatibility Check

Plugin Compatibility Check helps you assess whether installed Redmine plugins
are likely to work after upgrading Redmine.

It performs **read-only static analysis**.
No plugin files, database, gems, or Redmine installation are modified.

---

## Features

- Detect installed plugins
- Compare `requires_redmine` with a target Redmine version
- Detect deprecated Redmine/Rails APIs
- Estimate migration risk (OK / Warning / Unknown / Risky)
- Export CSV
- Export AI-friendly Markdown report
- Optional AI analysis using an OpenAI-compatible API

---

## Supported Versions

Plugin Compatibility Check supports:

- Redmine 3.x
- Redmine 4.x
- Redmine 5.x
- Redmine 6.x
- Redmine 7.x

The plugin itself is implemented to remain compatible with older Ruby versions used by these Redmine releases.

---

## Installation

Copy the plugin into the `plugins` directory.

```bash
cp -r redmine_plugin_check plugins/
```

Restart Redmine.

No database migration is required.

---

## Usage

1. Open **Administration → Plugin Check**
2. Enter the target Redmine version.
3. Review the compatibility report.
4. Export CSV or AI Markdown if required.
5. Optionally perform AI analysis.

---

## Recommended Upgrade Workflow

We recommend the following workflow when upgrading Redmine:

1. Scan installed plugins.
2. Search for actively maintained forks.
3. Upgrade plugins before modifying code.
4. Run plugin migrations.
5. Start Redmine.
6. Verify actual plugin functionality.

Successful startup alone does **not** guarantee plugin compatibility.

---

## Contributing

Bug reports and pull requests are welcome.

---

## Documentation

- [Installation](docs/installation.md)
- [Usage](docs/usage.md)
- [AI Analysis](docs/ai-analysis.md)
- [Detection Rules](docs/detection-rules.md)
- [Migration Workflow](docs/migration-workflow.md)
- [Compatibility Notes](docs/compatibility.md)
- [Roadmap](docs/roadmap.md)

---

## License

This project is licensed under the GNU General Public License v2.0.
See the LICENSE file for details.
