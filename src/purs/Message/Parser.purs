module Message.Parser
  ( run
  ) where

import Prelude

import Control.Alt ((<|>))
import Data.Array as Array
import Data.DateTime (DateTime)
import Data.Either (Either)
import Data.Foldable (class Foldable)
import Data.JSDate (JSDate)
import Data.JSDate as JSDate
import Data.List (List, (:))
import Data.Maybe (Maybe(..))
import Data.String as String
import Data.String.CodeUnits as String.CodeUnits
import Debug as Debug
import Message (Header, Message)
import StringParser
  ( ParseError
  , Parser
  , PosString
  , anyChar
  , char
  , eof
  , fail
  , many
  , many1
  , many1Till
  , manyTill
  , optionMaybe
  , string
  , try
  , tryAhead
  )
import StringParser as StringParser
import StringParser.CodeUnits (satisfy)

run
  :: String
  -> Either ParseError { result :: List Message, suffix :: PosString }
run input = StringParser.unParser (many messageP) { position: 0, substring: input }

foreign import parseRFC2822 :: String -> JSDate
foreign import decodeRFC2047 :: String -> String

preambleP :: Parser Unit
preambleP = do
  _ <- string "From"
  _ <- manyTill anyCharButNewline (string "\n")
  pure unit

authorP :: Parser String
authorP = do
  _ <- string "From: "
  _ <- many (satisfy (_ /= '('))
  name <- StringParser.between (char '(') (char ')') (many (satisfy (_ /= ')')))
  _ <- string "\n"
  pure (decodeRFC2047 (stringFromChars name))

--| Parse remaining part of a line (handling continuation lines)
lineRemainderP :: Parser String
lineRemainderP = do
  prefix <- singleLineRemainder
  rest <- many (hspace1 *> singleLineRemainder)
  let allParts = Array.fromFoldable (prefix : rest)
  pure (String.joinWith " " allParts)
  where
  singleLineRemainder = do
    chars <- many1Till anyChar (string "\n")
    pure (stringFromChars chars)

dateP :: Parser DateTime
dateP = do
  _ <- string "Date: "
  lineRemainder <- lineRemainderP
  case JSDate.toDateTime (parseRFC2822 lineRemainder) of
    Just date -> pure date
    Nothing -> fail "Invalid date"

subjectP :: Parser String
subjectP = do
  _ <- string "Subject: "
  lineRemainderP

inReplyToP :: Parser String
inReplyToP = do
  _ <- string "In-Reply-To: "
  lineRemainder <- lineRemainderP
  pure
    ( lineRemainder
        # String.split (String.Pattern " ")
        # Array.take 1
        # Array.fold
    )

referencesP :: Parser String
referencesP = do
  _ <- string "References: "
  lineRemainderP

messageIDP :: Parser String
messageIDP = do
  _ <- string "Message-ID: "
  lineRemainderP

contentP :: Parser String
contentP = do
  lines <- many1Till anyLineP
    (tryAhead (void (try headerP)) <|> eof)
  pure (String.joinWith "\n" (Array.fromFoldable lines))

anyLineP :: Parser String
anyLineP = do
  chars <- manyTill anyChar (string "\n")
  pure (stringFromChars chars)

headerP :: Parser Header
headerP = do
  preambleP
  author <- authorP
  date <- dateP
  subject <- subjectP
  inReplyTo <- optionMaybe inReplyToP
  references <- optionMaybe referencesP
  messageID <- messageIDP
  Debug.traceM { author, date, subject }
  pure { author, subject, messageID, inReplyTo, references, date }

messageP :: Parser Message
messageP = do
  { author, subject, messageID, inReplyTo, references, date } <- headerP
  content <- contentP
  pure { content, author, subject, messageID, inReplyTo, references, date }

anyCharButNewline :: Parser Char
anyCharButNewline = satisfy (_ /= '\n')

hspace1 :: Parser Unit
hspace1 = void (many1 (satisfy \c -> c == ' ' || c == '\t'))

stringFromChars :: forall f. Foldable f => f Char -> String
stringFromChars chars = String.CodeUnits.fromCharArray (Array.fromFoldable chars)