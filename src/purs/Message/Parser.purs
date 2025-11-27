module Message.Parser
  ( run
  ) where

import Prelude hiding (between)

import Control.Alt ((<|>))
import Data.Array as Array
import Data.DateTime (DateTime)
import Data.Either (Either)
import Data.Foldable (class Foldable)
import Data.JSDate (JSDate)
import Data.JSDate as JSDate
import Data.List (List, (:))
import Data.List.Types (NonEmptyList)
import Data.Maybe (Maybe(..))
import Data.Maybe as Maybe
import Data.NonEmpty ((:|))
import Data.Semigroup.Foldable (fold1)
import Data.String (CodePoint)
import Data.String as String
import Data.String.CodeUnits as String.CodeUnits
import Message (Header, Message)
import MessageID (MessageID)
import MessageID as MessageID
import Parsing (ParseError, Parser, fail)
import Parsing as Parsing
import Parsing.Combinators (between, lookAhead, many, many1, many1Till, manyTill, optionMaybe, optional, try)
import Parsing.String (anyChar, anyCodePoint, char, eof, satisfy, string)
import Parsing.String.Basic (skipSpaces)

run :: Boolean -> String -> Either ParseError (List Message)
run done input =
  Parsing.runParser input
    if done then
      many messageP <* eof
    else
      many messageP

foreign import parseRFC2822 :: String -> JSDate
foreign import decodeRFC2047 :: String -> String

preambleP :: Parser String Unit
preambleP = do
  _ <- string "From"
  _ <- manyTill anyCharButNewline (string "\n")
  pure unit

authorP :: Parser String String
authorP = do
  _ <- string "From: "
  _ <- many (satisfy (_ /= '('))
  name <- between (char '(') (char ')') (many (satisfy (_ /= ')')))
  _ <- string "\n"
  pure (decodeRFC2047 (stringFromChars name))

--| Parse remaining part of a line (handling continuation lines)
lineRemainderP :: Parser String String
lineRemainderP = do
  prefix <- singleLineRemainder
  rest <- many (hspace1 *> singleLineRemainder)
  let allParts = Array.fromFoldable (prefix : rest)
  -- TODO: Sometimes this is adding a space in the middle of a word
  pure (String.joinWith " " allParts)
  where
  singleLineRemainder = do
    chars <- many1Till anyChar (string "\n")
    pure (stringFromChars chars)

dateP :: Parser String DateTime
dateP = do
  _ <- string "Date: "
  lineRemainder <- lineRemainderP
  case JSDate.toDateTime (parseRFC2822 lineRemainder) of
    Just date -> pure date
    Nothing -> fail "Invalid date"

subjectP :: Parser String String
subjectP = do
  _ <- string "Subject: "
  _ <- optional (string "[Haskell-cafe]")
  skipSpaces
  decodeRFC2047 <$> lineRemainderP

inReplyToP :: Parser String (NonEmptyList MessageID)
inReplyToP = do
  _ <- string "In-Reply-To: "
  messageIDsP

messageIDsP :: Parser String (NonEmptyList MessageID)
messageIDsP = do
  prefix <- singleLineRemainder
  rest <- many (hspace1 *> singleLineRemainder)
  pure (fold1 (prefix :| rest))
  where
  singleLineRemainder = do
    many1Till (MessageID.parser <* optional (try skipParentheses) <* many hspace) (string "\n")

skipParentheses :: Parser String Unit
skipParentheses = do
  skipSpaces
  _ <- string "("
  _ <- many (satisfy (_ /= ')'))
  _ <- string ")"
  pure unit

referencesP :: Parser String (NonEmptyList MessageID)
referencesP = do
  _ <- string "References: "
  messageIDsP

messageIDP :: Parser String MessageID
messageIDP = do
  _ <- string "Message-ID: "
  MessageID.parser <* string "\n"

contentP :: Parser String String
contentP = do
  lines <- many1Till anyLineP
    (lookAhead (void (try headerP)) <|> eof)
  pure (String.joinWith "\n" (Array.fromFoldable lines))

anyLineP :: Parser String String
anyLineP = do
  chars <- manyTill anyCodePoint (string "\n")
  pure (stringFromCodePoints chars)

headerP :: Parser String Header
headerP = do
  preambleP
  author <- authorP
  date <- dateP
  subject <- subjectP
  inReplyTo <- optionMaybe inReplyToP
    <#> Maybe.maybe [] Array.fromFoldable
  references <- optionMaybe referencesP
    <#> Maybe.maybe [] Array.fromFoldable
  messageID <- messageIDP
  pure { author, subject, messageID, inReplyTo, references, date }

messageP :: Parser String Message
messageP = do
  { author, subject, messageID, inReplyTo, references, date } <- headerP
  content <- contentP
  pure { content, author, subject, messageID, inReplyTo, references, date }

anyCharButNewline :: Parser String Char
anyCharButNewline = satisfy (_ /= '\n')

hspace1 :: Parser String Unit
hspace1 = void (many1 hspace)

hspace :: Parser String Unit
hspace = void (satisfy \c -> c == ' ' || c == '\t')

stringFromChars :: forall f. Foldable f => f Char -> String
stringFromChars chars = String.CodeUnits.fromCharArray (Array.fromFoldable chars)

stringFromCodePoints :: forall f. Foldable f => f CodePoint -> String
stringFromCodePoints codePoints = String.fromCodePointArray (Array.fromFoldable codePoints)