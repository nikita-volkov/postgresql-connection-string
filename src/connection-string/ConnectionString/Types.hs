-- |
-- Module: ConnectionString.Types
-- Description: Core data types for PostgreSQL connection strings
--
-- This module defines the internal representation of PostgreSQL connection strings.
-- Users typically don't need to import this module directly; use "ConnectionString" instead.
module ConnectionString.Types where

import ConnectionString.Types.Gens qualified as Gens
import Data.Map.Strict qualified as Map
import Platform.Prelude
import Test.QuickCheck qualified as QuickCheck

-- | A PostgreSQL connection string.
--
-- This type represents all the components of a PostgreSQL connection string as defined in:
-- <https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING-URIS>
--
-- 'ConnectionString' has 'Semigroup' and 'Monoid' instances that allow combining
-- connection strings. When combining, the right-hand side takes precedence for
-- scalar values (user, password, dbname), while lists (hosts) are concatenated
-- and maps (params) are unioned (with right-hand side taking precedence for
-- duplicate keys).
--
-- == Examples
--
-- In URL format:
--
-- > postgresql://
-- > postgresql://localhost
-- > postgresql://localhost:5433
-- > postgresql://localhost/mydb
-- > postgresql://user@localhost
-- > postgresql://user:secret@localhost
-- > postgresql://other@localhost/otherdb?connect_timeout=10&application_name=myapp
-- > postgresql://host1:123,host2:456/somedb?target_session_attrs=any&application_name=myapp
--
-- In keyword\/value format:
--
-- > host=localhost port=5432 dbname=mydb connect_timeout=10
-- > host=host1,host2 port=123,456 dbname=mydb user=user password=secret
data ConnectionString
  = ConnectionString
      -- | Username for authentication.
      (Maybe Text)
      -- | Password for authentication.
      (Maybe Text)
      -- | List of host specifications (for failover/load balancing).
      [Host]
      -- | Database name to connect to.
      (Maybe Text)
      -- | Additional connection parameters.
      (Map.Map Text Text)
  deriving stock (Eq, Ord, Generic)
  deriving anyclass (Hashable)

-- | A host specification consisting of a hostname\/IP and optional port.
data Host
  = Host
      -- | Host domain name or IP address.
      Text
      -- | Port number. If 'Nothing', PostgreSQL's default port (5432) is used.
      (Maybe Word16)
  deriving stock (Show, Eq, Ord, Generic)
  deriving anyclass (Hashable)

-- | Combine two connection strings.
--
-- When combining, the following rules apply:
--
-- * For hosts: concatenated in order.
-- * For scalar values and params: right-hand side takes precedence for duplicate keys, which gives you override behaviour.
instance Semigroup ConnectionString where
  ConnectionString user1 password1 hosts1 dbname1 params1 <> ConnectionString user2 password2 hosts2 dbname2 params2 =
    ConnectionString
      (user2 <|> user1)
      (password2 <|> password1)
      (hosts1 <> hosts2)
      (dbname2 <|> dbname1)
      (Map.union params2 params1)

instance Monoid ConnectionString where
  mempty = ConnectionString Nothing Nothing [] Nothing Map.empty

instance QuickCheck.Arbitrary ConnectionString where
  arbitrary = QuickCheck.sized \size -> do
    user <- Gens.genMaybeText size
    -- Password only makes sense if there's a user
    password <- case user of
      Nothing -> pure Nothing
      Just _ -> Gens.genMaybeText size
    hosts <- QuickCheck.scale (`div` 2) (QuickCheck.listOf QuickCheck.arbitrary)
    dbname <- Gens.genMaybeText size
    params <- Gens.genParams size
    pure (ConnectionString user password hosts dbname params)

instance QuickCheck.Arbitrary Host where
  arbitrary = do
    hostname <- Gens.genHostname
    port <- QuickCheck.oneof [pure Nothing, Just <$> QuickCheck.arbitrary]
    pure (Host hostname port)
