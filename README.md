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
import ConnectionString

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
import ConnectionString

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

sumAndDivModSession :: Int64 -> Int64 -> Int64 -> Session (Int64, Int64)
sumAndDivModSession a b c = do
  -- Get the sum of a and b
  sumOfAAndB <- Session.statement (a, b) sumStatement
  -- Divide the sum by c and get the modulo as well
  Session.statement (sumOfAAndB, c) divModStatement

-- * Statements

-- Statement is a definition of an individual SQL-statement,
-- accompanied by a specification of how to encode its parameters and
-- decode its result.
-------------------------

-- | A statement with two integer parameters and an integer result.
sumStatement :: Statement (Int64, Int64) Int64
sumStatement = Statement sql encoder decoder preparable
  where
    -- The SQL of the statement, with $1, $2, ... placeholders for parameters.
    sql =
      "select $1 + $2"
    -- Specification of how to encode the parameters of the statement
    -- where the association with placeholders is achieved by order.
    encoder =
      mconcat
        [ -- Encoder of the first parameter as a non-nullable int8.
          -- It extracts the first element of the tuple using the contravariant functor
          -- instance.
          fst >$< Encoders.param (Encoders.nonNullable Encoders.int8),
          -- Encoder of the second parameter,
          -- which extracts the second element of the tuple.
          snd >$< Encoders.param (Encoders.nonNullable Encoders.int8)
        ]
    -- Specification of how to decode the result of the statement.
    -- States that we expect a single row with a single non-nullable int8 column.
    decoder =
      Decoders.singleRow
        (Decoders.column (Decoders.nonNullable Decoders.int8))
    -- States that this statement is allowed to be prepared on the server side.
    -- Unless your application generates the statements dynamically,
    -- you should always set this to True.
    -- If in the connection settings the usePreparedStatements option is set to False,
    -- the statement will not be prepared regardless of this flag.
    preparable = True

divModStatement :: Statement (Int64, Int64) (Int64, Int64)
divModStatement = Statement sql encoder decoder preparable
  where
    sql =
      "select $1 / $2, $1 % $2"
    encoder =
      mconcat
        [ fst >$< Encoders.param (Encoders.nonNullable Encoders.int8),
          snd >$< Encoders.param (Encoders.nonNullable Encoders.int8)
        ]
    -- Decoder that expects a single row with two non-nullable int8 columns,
    -- returning the result as a tuple.
    -- Uses the applicative functor instance to combine two column decoders.
    decoder =
      Decoders.singleRow
        ( (,)
            <$> Decoders.column (Decoders.nonNullable Decoders.int8)
            <*> Decoders.column (Decoders.nonNullable Decoders.int8)
        )
    preparable = True
```

For the general use-case it is advised to prefer declaring statements using the "hasql-th" library, which validates the statements at compile-time and generates codecs automatically. So the above two statements could be implemented the following way:

```haskell
import qualified Hasql.TH as TH -- from "hasql-th"

sumStatement :: Statement (Int64, Int64) Int64
sumStatement =
  [TH.singletonStatement|
    select ($1 :: int8 + $2 :: int8) :: int8
  |]

divModStatement :: Statement (Int64, Int64) (Int64, Int64)
divModStatement =
  [TH.singletonStatement|
    select
      (($1 :: int8) / ($2 :: int8)) :: int8,
      (($1 :: int8) % ($2 :: int8)) :: int8
  |]
```
