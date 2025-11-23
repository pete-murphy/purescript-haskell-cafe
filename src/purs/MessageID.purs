module MessageID
  ( MessageID
  , parser
  , toString
  ) where

import Prelude

import Data.Array as Array
import Data.Either as Either
import Data.String.CodeUnits as String
import Data.String.Regex as Regex
import Data.String.Regex.Flags as Regex.Flags
import Parsing (Parser)
import Parsing.Combinators (manyTill)
import Parsing.String (anyChar, string)
import Partial.Unsafe as Unsafe

newtype MessageID = MessageID String

derive newtype instance Eq MessageID
derive newtype instance Ord MessageID
derive newtype instance Show MessageID

unallowedCharactersRegex :: Regex.Regex
unallowedCharactersRegex =
  Regex.regex "[^A-Za-z0-9_-]" Regex.Flags.global
    # Either.fromRight'
        \_ -> Unsafe.unsafeCrashWith "Invalid regex"

normalize :: String -> String
normalize =
  Regex.replace unallowedCharactersRegex "_"

parser :: Parser String MessageID
parser = do
  _ <- string "<"
  messageID' <- manyTill anyChar (string ">")
  let messageID = normalize (String.fromCharArray (Array.fromFoldable messageID'))
  pure (MessageID messageID)

toString :: MessageID -> String
toString (MessageID messageID) = messageID
