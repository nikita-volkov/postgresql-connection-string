{-# OPTIONS_GHC -Wno-orphans #-}

-- |
-- Structured model of PostgreSQL connection string, with a DSL for construction, access, parsing and rendering.
--
-- It supports both the URI format (@postgresql:\/\/@ and @postgres:\/\/@) and the keyword\/value format
-- as specified in the PostgreSQL documentation:
-- <https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING>
--
-- = Usage
--
-- == Parsing Connection Strings
--
-- Parse a connection string from 'Text', validate it and access its components:
--
-- >>> toDbname <$> parse "postgresql://user:password@localhost:5432/mydb"
-- Right (Just "mydb")
--
-- Or use its 'IsString' instance for convenience (ignoring parse errors):
--
-- >>> toDbname "postgresql://user:password@localhost:5432/mydb"
-- Just "mydb"
--
-- == Constructing Connection Strings
--
-- Build connection strings using the 'Semigroup' instance and constructor functions:
--
-- >>> let connStr = mconcat [user "myuser", password "secret", hostAndPort "localhost" 5432, dbname "mydb"]
-- >>> toUrl connStr :: Text
-- "postgresql://myuser:secret@localhost:5432/mydb"
--
-- == Converting Between Formats
--
-- Convert to URI format:
--
-- >>> toUrl "host=localhost port=5432 user=user password=password dbname=mydb"
-- "postgresql://user:password@localhost:5432/mydb"
--
-- Convert to keyword\/value format (for use with libpq's PQconnectdb):
--
-- >>> toKeyValueString "postgresql://user:password@localhost:5432/mydb"
-- "host=localhost port=5432 user=user password=password dbname=mydb"
--
-- Note that these examples use the 'IsString' instance for brevity.
module PostgresqlConnectionString
  ( -- * Data Types
    ConnectionString,

    -- * Parsing
    parse,
    megaparsecOf,

    -- * Rendering
    toUrl,
    toKeyValueString,

    -- * Accessors
    toHosts,
    toUser,
    toPassword,
    toDbname,
    toParams,

    -- * Transformations
    interceptParam,

    -- * Constructors
    host,
    hostAndPort,
    user,
    password,
    dbname,
    param,

    -- * Conversions
    IsConnectionString (..),
  )
where

import qualified Data.Map.Strict as Map
import qualified Data.Text as Text
import qualified PercentEncoding
import Platform.Prelude
import qualified PostgresqlConnectionString.Parsers as Parsers
import PostgresqlConnectionString.Types
import qualified Text.Megaparsec as Megaparsec
import qualified TextBuilder

instance IsString ConnectionString where
  fromString =
    either fromError id . parse . fromString
    where
      fromError = const mempty

instance Show ConnectionString where
  showsPrec d = showsPrec d . toUrl

-- * Accessors

-- | Extract the list of hosts and their optional ports from a connection string.
--
-- Each tuple contains a host (domain name or IP address) and an optional port number.
-- If no port is specified, 'Nothing' is returned for that host.
--
-- Examples:
--
-- >>> toHosts (hostAndPort "localhost" 5432)
-- [("localhost", Just 5432)]
--
-- >>> toHosts (mconcat [host "host1", hostAndPort "host2" 5433])
-- [("host1", Nothing), ("host2", Just 5433)]
toHosts :: ConnectionString -> [(Text, Maybe Word16)]
toHosts (ConnectionString _ _ hostspec _ _) =
  map (\(Host host port) -> (host, port)) hostspec

-- | Extract the username from a connection string, if present.
--
-- Examples:
--
-- >>> toUser (user "myuser")
-- Just "myuser"
--
-- >>> toUser mempty
-- Nothing
toUser :: ConnectionString -> Maybe Text
toUser (ConnectionString user _ _ _ _) = user

-- | Extract the password from a connection string, if present.
--
-- Examples:
--
-- >>> toPassword (password "secret")
-- Just "secret"
--
-- >>> toPassword mempty
-- Nothing
toPassword :: ConnectionString -> Maybe Text
toPassword (ConnectionString _ password _ _ _) = password

-- | Extract the database name from a connection string, if present.
--
-- Examples:
--
-- >>> toDbname (dbname "mydb")
-- Just "mydb"
--
-- >>> toDbname mempty
-- Nothing
toDbname :: ConnectionString -> Maybe Text
toDbname (ConnectionString _ _ _ dbname _) = dbname

-- | Extract the connection parameters as a 'Map' of key-value pairs.
--
-- These correspond to the query string parameters in the URI format,
-- or additional connection parameters in the keyword\/value format.
--
-- Examples:
--
-- >>> toParams (param "application_name" "myapp")
-- fromList [("application_name","myapp")]
--
-- >>> toParams (mconcat [param "connect_timeout" "10", param "application_name" "myapp"])
-- fromList [("application_name","myapp"),("connect_timeout","10")]
toParams :: ConnectionString -> Map.Map Text Text
toParams (ConnectionString _ _ _ _ paramspec) = paramspec

-- | Convert a connection string to the PostgreSQL URI format.
--
-- This produces a connection string in the form:
--
-- @
-- postgresql:\/\/[userspec\@][hostspec][\/dbname][?paramspec]
-- @
--
-- where:
--
-- * @userspec@ is @user[:password]@
-- * @hostspec@ is a comma-separated list of @host[:port]@ specifications
-- * @dbname@ is the database name
-- * @paramspec@ is a query string of connection parameters
--
-- All components are percent-encoded as necessary.
--
-- Examples:
--
-- >>> toUrl (mconcat [user "myuser", hostAndPort "localhost" 5432, dbname "mydb"])
-- "postgresql://myuser@localhost:5432/mydb"
--
-- >>> toUrl (mconcat [user "user", password "secret", host "localhost"])
-- "postgresql://user:secret@localhost"
--
-- >>> toUrl (mconcat [hostAndPort "host1" 5432, hostAndPort "host2" 5433, dbname "mydb"])
-- "postgresql://host1:5432,host2:5433/mydb"
toUrl :: ConnectionString -> Text
toUrl = TextBuilder.toText . renderConnectionString
  where
    renderConnectionString (ConnectionString user password hostspec dbname paramspec) =
      -- postgresql://[userspec@][hostspec][/dbname][?paramspec]
      mconcat
        [ "postgresql://",
          renderUserspec user password,
          TextBuilder.intercalateMap "," renderHost hostspec,
          foldMap (mappend "/" . PercentEncoding.encodeText) dbname,
          renderParamspec paramspec
        ]

    renderUserspec user password =
      case user of
        Nothing -> mempty
        Just user ->
          mconcat
            [ PercentEncoding.encodeText user,
              foldMap (mappend ":" . PercentEncoding.encodeText) password,
              "@"
            ]

    renderHost (Host host port) =
      mconcat
        [ PercentEncoding.encodeText host,
          foldMap renderPort port
        ]

    renderPort port =
      mconcat
        [ ":",
          TextBuilder.decimal port
        ]

    renderParamspec paramspec =
      case Map.toList paramspec of
        [] -> mempty
        list ->
          mconcat
            [ "?",
              TextBuilder.intercalateMap "&" renderParam list
            ]

    renderParam (key, value) =
      mconcat
        [ PercentEncoding.encodeText key,
          "=",
          PercentEncoding.encodeText value
        ]

-- | Convert a connection string to the PostgreSQL keyword/value format.
--
-- The keyword/value format is a space-separated list of key=value pairs.
-- Values containing spaces, quotes, backslashes, or equals signs are automatically
-- quoted with single quotes, and backslashes and single quotes within values are
-- escaped with backslashes.
--
-- Note: Only the first host from the hostspec is included, as the keyword/value
-- format does not support multiple hosts in the same way as the URI format.
--
-- Examples:
--
-- >>> toKeyValueString (mconcat [hostAndPort "localhost" 5432, user "postgres"])
-- "host=localhost port=5432 user=postgres"
--
-- >>> toKeyValueString (password "secret pass")
-- "password='secret pass'"
--
-- >>> toKeyValueString (password "it's a secret")
-- "password='it\\'s a secret'"
toKeyValueString :: ConnectionString -> Text
toKeyValueString (ConnectionString user password hostspec dbname paramspec) =
  (TextBuilder.toText . TextBuilder.intercalateMap " " id)
    ( catMaybes
        [ fmap (\h -> renderKeyValue "host" (renderHostForKeyValue h)) (listToMaybe hostspec),
          fmap (\p -> renderKeyValue "port" (TextBuilder.decimal p)) (listToMaybe hostspec >>= \(Host _ p) -> p),
          fmap (renderKeyValue "user" . TextBuilder.text) user,
          fmap (renderKeyValue "password" . TextBuilder.text) password,
          fmap (renderKeyValue "dbname" . TextBuilder.text) dbname
        ]
        <> map (\(k, v) -> renderKeyValue k (TextBuilder.text v)) (Map.toList paramspec)
    )
  where
    renderHostForKeyValue (Host host _) = TextBuilder.text host

    renderKeyValue key value =
      mconcat
        [ TextBuilder.text key,
          "=",
          escapeValue value
        ]

    -- Escape values according to the keyword/value format rules
    escapeValue :: TextBuilder -> TextBuilder
    escapeValue valueBuilder =
      let value = TextBuilder.toText valueBuilder
       in if needsQuoting value
            then mconcat ["'", TextBuilder.text (escapeForQuoted value), "'"]
            else TextBuilder.text value

    -- Check if a value needs quoting
    needsQuoting :: Text -> Bool
    needsQuoting value =
      Text.null value
        || Text.any (\c -> c == ' ' || c == '\'' || c == '\\' || c == '=') value

    -- Escape backslashes and single quotes for quoted values
    escapeForQuoted :: Text -> Text
    escapeForQuoted = Text.concatMap escapeChar
      where
        escapeChar '\\' = "\\\\"
        escapeChar '\'' = "\\'"
        escapeChar c = Text.singleton c

-- * Transformations

-- | Extract a parameter by key and remove it from the connection string.
--
-- If the parameter is found, returns 'Just' with a tuple of the parameter's value
-- and the updated connection string (with the parameter removed).
-- If the parameter is not found, returns 'Nothing'.
--
-- This is useful for extracting connection parameters that need special handling
-- before passing the connection string to PostgreSQL.
--
-- Examples:
--
-- >>> let connStr = mconcat [param "application_name" "myapp", param "connect_timeout" "10"]
-- >>> interceptParam "application_name" connStr
-- Just ("myapp", "postgresql://?connect_timeout=10")
--
-- >>> interceptParam "nonexistent" connStr
-- Nothing
interceptParam ::
  -- | The key of the parameter to intercept.
  Text ->
  ConnectionString ->
  Maybe (Text, ConnectionString)
interceptParam key (ConnectionString user password hostspec dbname paramspec) =
  let (foundValue, updatedParamspec) =
        Map.alterF
          ( \case
              Just value -> (Just value, Nothing)
              Nothing -> (Nothing, Nothing)
          )
          key
          paramspec
   in do
        value <- foundValue
        pure (value, ConnectionString user password hostspec dbname updatedParamspec)

-- * Parsing

-- | Parse a connection string from 'Text'.
--
-- Supports both URI format and keyword\/value format connection strings:
--
-- URI format examples:
--
-- >>> parse "postgresql://localhost"
-- Right ...
--
-- >>> parse "postgresql://user:password@localhost:5432/mydb"
-- Right ...
--
-- >>> parse "postgres://host1:5432,host2:5433/mydb?connect_timeout=10"
-- Right ...
--
-- Keyword\/value format examples:
--
-- >>> parse "host=localhost port=5432 user=postgres"
-- Right ...
--
-- >>> parse "host=localhost dbname=mydb"
-- Right ...
--
-- Returns 'Left' with an error message if parsing fails:
--
-- >>> parse "invalid://connection"
-- Left ...
--
-- The error message is quite detailed (it is produced by Megaparsec):
--
-- >>> parse "invalid://connection=" & either id (const "") & Data.Text.IO.putStrLn
-- 1:8:
--   |
-- 1 | invalid://connection=
--   |        ^
-- unexpected ':'
-- expecting '=' or Key
parse :: Text -> Either Text ConnectionString
parse input =
  Megaparsec.parse megaparsecOf "" input
    & first (fromString . Megaparsec.errorBundlePretty)

-- | Get the Megaparsec parser of connection strings.
--
-- This allows you to use the connection string parser as part of a larger
-- Megaparsec parser combinator setup.
--
-- The parser accepts both URI format (@postgresql:\/\/@ or @postgres:\/\/@)
-- and keyword\/value format connection strings.
megaparsecOf :: Megaparsec.Parsec Void Text ConnectionString
megaparsecOf = Parsers.getConnectionString

-- * Constructors

-- | Create a connection string with a single host and without specifying a port.
--
-- Multiple hosts can be specified by combining multiple 'host' or 'hostAndPort' values
-- using the 'Semigroup' instance.
--
-- When you need to specify a port, use 'hostAndPort' instead.
--
-- Examples:
--
-- >>> host "localhost"
-- "postgresql://localhost"
host :: Text -> ConnectionString
host hostname =
  ConnectionString
    Nothing
    Nothing
    [Host hostname Nothing]
    Nothing
    Map.empty

-- | Create a connection string with a single host and port.
--
-- Multiple hosts can be specified by combining multiple 'hostAndPort' or 'host' values
-- using the 'Semigroup' instance.
--
-- Examples:
--
-- >>> hostAndPort "localhost" 5432
-- "postgresql://localhost:5432"
--
-- >>> mconcat [hostAndPort "host1" 5432, hostAndPort "host2" 5433]
-- "postgresql://host1:5432,host2:5433"
hostAndPort :: Text -> Word16 -> ConnectionString
hostAndPort host port =
  ConnectionString
    Nothing
    Nothing
    [Host host (Just port)]
    Nothing
    Map.empty

-- | Create a connection string with a username.
--
-- Examples:
--
-- >>> user "myuser"
-- "postgresql://myuser@"
--
-- >>> mconcat [user "myuser", host "localhost"]
-- "postgresql://myuser@localhost"
user :: Text -> ConnectionString
user username =
  ConnectionString
    (Just username)
    Nothing
    []
    Nothing
    Map.empty

-- | Create a connection string with a password.
--
-- Note: Passwords are typically used together with usernames.
--
-- Examples:
--
-- >>> mconcat [user "myuser", password "secret"]
-- "postgresql://myuser:secret@"
--
-- >>> mconcat [user "myuser", password "secret", host "localhost"]
-- "postgresql://myuser:secret@localhost"
password :: Text -> ConnectionString
password pwd =
  ConnectionString
    Nothing
    (Just pwd)
    []
    Nothing
    Map.empty

-- | Create a connection string with a database name.
--
-- Examples:
--
-- >>> dbname "mydb"
-- "postgresql:///mydb"
--
-- >>> mconcat [host "localhost", dbname "mydb"]
-- "postgresql://localhost/mydb"
dbname :: Text -> ConnectionString
dbname db =
  ConnectionString
    Nothing
    Nothing
    []
    (Just db)
    Map.empty

-- | Create a connection string with a single connection parameter.
--
-- Connection parameters are arbitrary key-value pairs that configure
-- the PostgreSQL connection. Common parameters include:
--
-- * @application_name@ - Sets the application name
-- * @connect_timeout@ - Connection timeout in seconds
-- * @options@ - Command-line options for the server
-- * @sslmode@ - SSL mode (@disable@, @require@, @verify-ca@, @verify-full@)
--
-- See the PostgreSQL documentation for a complete list:
-- <https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-PARAMKEYWORDS>
--
-- Examples:
--
-- >>> param "application_name" "myapp"
-- "postgresql://?application_name=myapp"
--
-- >>> mconcat [host "localhost", param "connect_timeout" "10"]
-- "postgresql://localhost?connect_timeout=10"
--
-- >>> mconcat [param "application_name" "myapp", param "connect_timeout" "10"]
-- "postgresql://?application_name=myapp&connect_timeout=10"
param :: Text -> Text -> ConnectionString
param key value =
  ConnectionString
    Nothing
    Nothing
    []
    Nothing
    (Map.singleton key value)

-- * Conversions

-- | Type class for types that are isomorphic to 'ConnectionString'.
--
-- Isomorphism laws apply:
--
-- * @to . from = id@
-- * @from . to = id@
--
-- This means that converting a value to 'ConnectionString' and back
-- should yield the original value, and vice versa.
class IsConnectionString a where
  -- | Construct 'ConnectionString' **from** type @a@.
  --
  -- When imported qualified it reads naturally: @ConnectionString.from@.
  from :: a -> ConnectionString

  -- | Convert 'ConnectionString' **to** type @a@.
  --
  -- When imported qualified it reads naturally: @ConnectionString.to@.
  to :: ConnectionString -> a
