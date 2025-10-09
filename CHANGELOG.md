# 0.1.0.0

Initial release of postgresql-connection-string as a standalone library.

This library was extracted from the hasql project to provide a focused, reusable component for parsing and constructing PostgreSQL connection strings.

## Features

- Parse PostgreSQL connection URIs (`postgresql://` and `postgres://` schemes)
- Parse keyword/value format connection strings
- Construct connection strings programmatically using composable combinators
- Convert between URI and keyword/value formats
- Support for multiple host specifications (for failover/load balancing)
- Automatic percent-encoding/decoding of special characters
- Type-safe representation with `ConnectionString` data type

## API

### Constructors
- `hostAndPort` - Specify a host and optional port
- `user` - Set the username
- `password` - Set the password
- `dbname` - Set the database name
- `param` - Add a connection parameter

### Accessors
- `toHosts` - Get list of hosts and ports
- `toUser` - Get username
- `toPassword` - Get password
- `toDbname` - Get database name
- `toParams` - Get parameter map

### Rendering
- `toUrl` - Convert to URI format
- `toKeyValueString` - Convert to keyword/value format

### Parsing
- `parseText` - Parse from Text with error reporting
- `parserOf` - Get the underlying Megaparsec parser

### Transformations
- `interceptParam` - Extract and remove a parameter
