module Message.Parser
  ( run
  ) where

import Prelude hiding (between)

import Control.Alt ((<|>))
import Data.Array as Array
import Data.DateTime (DateTime)
import Data.Either (Either(..))
import Data.Foldable (class Foldable)
import Data.Identity (Identity(..))
import Data.JSDate (JSDate)
import Data.JSDate as JSDate
import Data.List (List, (:))
import Data.Maybe (Maybe(..))
import Data.String as String
import Data.String.CodeUnits as String.CodeUnits
import Data.Tuple (Tuple(..))
import Message (Header, Message)
import Parsing (ParseError, ParseState(..), Parser, fail, initialPos, runParserT')
import Parsing.Combinators
  ( between
  , lookAhead
  , many
  , many1
  , many1Till
  , manyTill
  , optionMaybe
  , try
  )
import Parsing.String
  ( anyChar
  , char
  , eof
  , satisfy
  , string
  )

run
  :: String
  -> Either ParseError { result :: List Message, suffix :: String }
run input = case runParserT' initialState (many messageP) of
  Identity (Tuple (Left err) _) -> Left err
  Identity (Tuple (Right result) (ParseState suffix _ _)) -> Right { result, suffix }
  where
  initialState = ParseState input initialPos false

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
  lineRemainderP

inReplyToP :: Parser String String
inReplyToP = do
  _ <- string "In-Reply-To: "
  lineRemainder <- lineRemainderP
  pure
    ( lineRemainder
        # String.split (String.Pattern " ")
        # Array.take 1
        # Array.fold
    )

referencesP :: Parser String String
referencesP = do
  _ <- string "References: "
  lineRemainderP

messageIDP :: Parser String String
messageIDP = do
  _ <- string "Message-ID: "
  lineRemainderP

contentP :: Parser String String
contentP = do
  lines <- many1Till anyLineP
    (lookAhead (void (try headerP)) <|> eof)
  pure (String.joinWith "\n" (Array.fromFoldable lines))

anyLineP :: Parser String String
anyLineP = do
  chars <- manyTill anyChar (string "\n")
  pure (stringFromChars chars)

headerP :: Parser String Header
headerP = do
  preambleP
  author <- authorP
  date <- dateP
  subject <- subjectP
  inReplyTo <- optionMaybe inReplyToP
  references <- optionMaybe referencesP
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
hspace1 = void (many1 (satisfy \c -> c == ' ' || c == '\t'))

stringFromChars :: forall f. Foldable f => f Char -> String
stringFromChars chars = String.CodeUnits.fromCharArray (Array.fromFoldable chars)