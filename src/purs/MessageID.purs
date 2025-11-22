module MessageID
  ( MessageID
  , parser
  ) where

import Prelude

import Data.Array as Array
import Data.String.CodeUnits as String
import Parsing (Parser)
import Parsing.Combinators (manyTill)
import Parsing.String (anyChar, string)

newtype MessageID = MessageID String

derive newtype instance Eq MessageID
derive newtype instance Ord MessageID
derive newtype instance Show MessageID

parser :: Parser String MessageID
parser = do
  _ <- string "<"
  messageID <- manyTill anyChar (string ">")
  pure (MessageID (String.fromCharArray (Array.fromFoldable messageID)))

