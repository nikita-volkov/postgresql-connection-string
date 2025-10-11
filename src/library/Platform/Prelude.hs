module Platform.Prelude
  ( module Exports,
  )
where

import Control.Applicative as Exports hiding (WrappedArrow (..))
import Control.Arrow as Exports hiding (first, second)
import Control.Category as Exports
import Control.Exception as Exports hiding (Handler)
import Control.Monad as Exports hiding (fail, forM, forM_, mapM, mapM_, msum, sequence, sequence_)
import Control.Monad.Fail as Exports
import Control.Monad.Fix as Exports hiding (fix)
import Control.Monad.IO.Class as Exports
import Data.Bifunctor as Exports
import Data.Bits as Exports
import Data.Bool as Exports
import Data.ByteString as Exports (ByteString)
import Data.Char as Exports
import Data.Coerce as Exports
import Data.Data as Exports
import Data.Either as Exports
import Data.Foldable as Exports hiding (toList)
import Data.Function as Exports hiding (id, (.))
import Data.Functor as Exports hiding (unzip)
import Data.Functor.Compose as Exports
import Data.Functor.Identity as Exports
import Data.Hashable as Exports (Hashable (..))
import Data.Int as Exports
import Data.List as Exports hiding (all, and, any, concat, concatMap, elem, filter, find, foldl, foldl', foldl1, foldr, foldr1, isSubsequenceOf, mapAccumL, mapAccumR, maximum, maximumBy, minimum, minimumBy, notElem, or, product, sortOn, sum, uncons)
import Data.List.NonEmpty as Exports (NonEmpty (..))
import Data.Maybe as Exports hiding (mapMaybe)
import Data.Monoid as Exports hiding (Alt, (<>))
import Data.Ord as Exports
import Data.Semigroup as Exports hiding (First (..), Last (..))
import Data.String as Exports
import Data.Text as Exports (Text)
import Data.Traversable as Exports
import Data.Tuple as Exports
import Data.Void as Exports
import Data.Word as Exports
import GHC.Exts as Exports (IsList (..), groupWith, inline, lazy, sortWith)
import GHC.Generics as Exports (Generic)
import GHC.OverloadedLabels as Exports
import Numeric as Exports
import System.IO as Exports (Handle, hClose)
import System.IO.Unsafe as Exports (unsafeDupablePerformIO)
import TextBuilder as Exports (TextBuilder)
import Prelude as Exports hiding (Read, all, and, any, concat, concatMap, elem, fail, filter, foldl, foldl1, foldr, foldr1, id, mapM, mapM_, maximum, minimum, notElem, or, product, sequence, sequence_, sum, (.))
