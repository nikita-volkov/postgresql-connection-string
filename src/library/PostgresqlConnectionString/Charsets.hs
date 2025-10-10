module PostgresqlConnectionString.Charsets where

import Data.CharSet
import Platform.Prelude hiding (fromList)

control :: CharSet
control = fromList ":@?/=&,"

paramControl :: CharSet
paramControl = fromList "&"

keyName :: CharSet
keyName =
  fromList
    ( mconcat
        [ ['a' .. 'z'],
          ['A' .. 'Z'],
          ['0' .. '9'],
          "_"
        ]
    )
