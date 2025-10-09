# postgresql-connection-string

[![Hackage](https://img.shields.io/hackage/v/postgresql-connection-string.svg)](https://hackage.haskell.org/package/postgresql-connection-string)

A Haskell library for parsing and constructing PostgreSQL connection strings.

## Overview

This library provides a type-safe way to work with PostgreSQL connection strings, supporting both the URI format and the keyword/value format as specified in the [PostgreSQL documentation](https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING).

## Features

- **URI Format Parsing**: Parse `postgresql://` and `postgres://` URIs
- **Keyword/Value Format**: Convert to PostgreSQL's keyword/value connection string format
- **Type-Safe Construction**: Build connection strings using composable constructors
- **Percent-Encoding**: Automatic handling of special characters in connection string components
- **Multiple Hosts**: Support for multiple host specifications (for failover/load balancing)
- **Query Parameters**: Full support for connection parameters as query strings

## Usage

### Parsing Connection Strings

```haskell
import PostgresqlConnectionString

-- Parse a URI format connection string
case parseText "postgresql://user:password@localhost:5432/mydb?application_name=myapp" of
  Left err -> putStrLn $ "Parse error: " <> err
  Right connStr -> do
    print $ toUser connStr        -- Just "user"
    print $ toDbname connStr      -- Just "mydb"
    print $ toHosts connStr       -- [("localhost", Just 5432)]
```

### Constructing Connection Strings

```haskell
import PostgresqlConnectionString

-- Build a connection string using combinators
let connStr = mconcat
      [ user "myuser"
      , password "secret"
      , hostAndPort "localhost" (Just 5432)
      , dbname "mydb"
      , param "application_name" "myapp"
      , param "connect_timeout" "10"
      ]

-- Convert to URI format
print $ toUrl connStr
-- "postgresql://myuser:secret@localhost:5432/mydb?application_name=myapp&connect_timeout=10"

-- Convert to keyword/value format
print $ toKeyValueString connStr
-- "host=localhost port=5432 user=myuser password=secret dbname=mydb application_name=myapp connect_timeout=10"
```

### Multiple Hosts

```haskell
-- Support for multiple hosts (failover/load balancing)
let connStr = mconcat
      [ hostAndPort "host1" (Just 5432)
      , hostAndPort "host2" (Just 5433)
      , dbname "mydb"
      ]

print $ toUrl connStr
-- "postgresql://host1:5432,host2:5433/mydb"
```

### Accessing Components

```haskell
-- Extract individual components
toHosts :: ConnectionString -> [(Text, Maybe Word16)]
toUser :: ConnectionString -> Maybe Text
toPassword :: ConnectionString -> Maybe Text
toDbname :: ConnectionString -> Maybe Text
toParams :: ConnectionString -> Map Text Text
```

### Transforming Connection Strings

```haskell
-- Intercept and remove a parameter
case interceptParam "application_name" connStr of
  Just (value, updatedConnStr) -> 
    -- value is the parameter value, updatedConnStr has it removed
    processAppName value
  Nothing -> 
    -- Parameter not found
    useDefault
```

## API Documentation

The main module exports:

- **Parsing**: `parseText`, `parserOf`
- **Constructors**: `hostAndPort`, `user`, `password`, `dbname`, `param`
- **Accessors**: `toHosts`, `toUser`, `toPassword`, `toDbname`, `toParams`
- **Rendering**: `toUrl`, `toKeyValueString`
- **Transformations**: `interceptParam`

## Installation

Add to your `package.yaml` or `.cabal` file:

```yaml
dependencies:
  - postgresql-connection-string
```

Or with cabal:

```cabal
build-depends:
  postgresql-connection-string
```

## Requirements

- GHC 8.10 or later
- Standard Haskell dependencies (see cabal file)

## Related Projects

This library was extracted from the [hasql](https://github.com/nikita-volkov/hasql) project to provide a standalone connection string parser and builder that can be used independently of the full hasql ecosystem.

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues on GitHub.
-------------------------
