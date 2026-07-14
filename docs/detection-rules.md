# Detection Rules

The plugin performs conservative static analysis.

## Status

### OK

No obvious compatibility issues detected.

### Warning

Potential migration work may be required.

Examples:

- Gemfile
- db/migrate
- version conditions
- deprecated APIs

### Unknown

Insufficient information.

### Risky

High probability of migration issues.

Examples:

- alias_method_chain
- Dispatcher.to_prepare
- before_filter
- unloadable
- attr_accessible
- ActiveRecord::Observer

Static analysis cannot guarantee compatibility.
