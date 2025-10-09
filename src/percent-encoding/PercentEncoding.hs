module PercentEncoding where

import qualified PercentEncoding.Parsers as Parsers
import qualified PercentEncoding.TextBuilders as TextBuilders
import Platform.Prelude
import qualified Text.Megaparsec as Megaparsec

encodeText :: Text -> TextBuilder
encodeText = TextBuilders.urlEncodedText

parser ::
  -- | Test on stop-char. @%@ is already accounted for.
  (Char -> Bool) ->
  -- | Megaparsec parser for a percent-encoded text component.
  Megaparsec.Parsec Void Text Text
parser isStopChar =
  Parsers.urlEncodedComponentText isStopChar
