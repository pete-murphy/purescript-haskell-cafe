module Message.Parser where

import Prelude

import Control.Alt ((<|>))
import Data.Array as Array
import Data.Bifunctor as Bifunctor
import Data.DateTime (DateTime(..))
import Data.Either (Either(..))
import Data.Either as Either
import Data.Foldable (foldMap)
import Data.JSDate (JSDate)
import Data.JSDate as JSDate
import Data.List (List(..), (:))
import Data.List as List
import Data.Maybe (Maybe(..))
import Data.String as String
import Data.String.CodeUnits as String.CodeUnits
import Foreign (Foreign)
import StringParser (Parser, anyChar, between, char, eof, fail, lookAhead, many, many1Till, manyTill, optionMaybe, string, try)
import StringParser.CodeUnits (satisfy, skipSpaces)
import Unsafe.Coerce as Coerce

foreign import parseRFC2822
  :: (forall e a. e -> Either e a)
  -> (forall e a. a -> Either e a)
  -> String
  -> Either Foreign JSDate

-- Type alias for clarity
type MessageParser a = Parser a

-- Header type
type Header =
  { author :: String
  , subject :: String
  , messageID :: String
  , inReplyTo :: Maybe String
  , references :: Maybe String
  , date :: DateTime
  }

-- Message type
type Message =
  { content :: String
  , author :: String
  , subject :: String
  , messageID :: String
  , inReplyTo :: Maybe String
  , references :: Maybe String
  , date :: DateTime
  }

-- Helper: parse until newline (but not including newline)
anyCharButNewline :: Parser Char
anyCharButNewline = satisfy (_ /= '\n')

-- Parse "From" line preamble
preambleP :: Parser Unit
preambleP = do
  _ <- string "From"
  _ <- manyTill anyCharButNewline (string "\n")
  pure unit

-- Parse author from "From: " field
authorP :: Parser String
authorP = do
  _ <- string "From: "
  _ <- many (satisfy (_ /= '('))
  name <- between (char '(') (char ')') (many (satisfy (_ /= ')')))
  _ <- string "\n"
  pure (foldMap String.CodeUnits.singleton name)

-- Parse remaining part of a line (handling continuation lines)
lineRemainderP :: Parser String
lineRemainderP = do
  prefix <- singleLineRemainder
  rest <- many (skipSpaces *> singleLineRemainder)
  let allParts = Array.fromFoldable (prefix : rest)
  pure (String.joinWith " " allParts)
  where
  singleLineRemainder = do
    chars <- many1Till anyChar (string "\n")
    pure (foldMap String.CodeUnits.singleton chars)

-- Parse date field
dateP :: Parser DateTime
dateP = do
  _ <- string "Date: "
  remainder <- lineRemainderP
  case
    parseRFC2822 Left Right remainder
      # Bifunctor.lmap (\error -> "Failed to parse RFC2822: " <> Coerce.unsafeCoerce error)
      >>= (JSDate.toDateTime >>> Either.note "Failed to conver JSDate")
    of
    Right date -> pure date
    Left error -> fail ("Could not parse date\n" <> remainder <> "\n" <> error)

-- Parse subject field
subjectP :: Parser String
subjectP = do
  _ <- string "Subject: "
  lineRemainderP

-- Parse In-Reply-To field
inReplyToP :: Parser String
inReplyToP = do
  _ <- string "In-Reply-To: "
  lineRemainder <- lineRemainderP
  -- Sometimes this looks like
  --
  --   In-Reply-To: <ID> (So-and-so's message of "Some date")
  --
  -- and we want to extract only the ID.
  pure (takeWhile (_ /= ' ') lineRemainder)

-- Parse References field
referencesP :: Parser String
referencesP = do
  _ <- string "References: "
  lineRemainderP

-- Parse Message-ID field
messageIDP :: Parser String
messageIDP = do
  _ <- string "Message-ID: "
  lineRemainderP

-- Parse content body
contentP :: Parser String
contentP = do
  result <- do
    chars <- many1Till anyChar
      (lookAhead (void nextPartP <|> void (try headerP)) <|> eof)
    pure (foldMap String.CodeUnits.singleton chars)
  _ <- optionMaybe nextPartP
  pure result

-- Parse "next part" separator
nextPartP :: Parser String
nextPartP = do
  _ <- string "-------------- next part --------------"
  chars <- manyTill anyChar
    (lookAhead (void (try headerP)) <|> eof)
  pure (foldMap String.CodeUnits.singleton chars)

-- Parse full header
headerP :: Parser Header
headerP = do
  preambleP
  author <- authorP
  date <- dateP
  subject <- subjectP
  inReplyTo <- optionMaybe inReplyToP
  references <- optionMaybe referencesP
  messageID <- messageIDP
  pure { author, subject, messageID, inReplyTo, references, date }

-- Helper function to implement span for lists
span :: forall a. (a -> Boolean) -> List a -> { init :: List a, rest :: List a }
span _ Nil = { init: Nil, rest: Nil }
span p xs =
  let
    taken = List.takeWhile p xs
    dropped = List.dropWhile p xs
  in
    { init: taken, rest: dropped }

-- Helper function to check if a string starts with a prefix
-- startsWith :: Pattern -> String -> Boolean
-- startsWith prefix str = Maybe.isJust (String.stripPrefix prefix str)

-- Helper function to check if a string ends with a suffix
-- endsWith :: Pattern -> String -> Boolean
-- endsWith suffix str = Maybe.isJust (String.stripSuffix suffix str)

-- Helper function to take characters from a string while a condition is true
takeWhile :: (Char -> Boolean) -> String -> String
takeWhile p str =
  let
    charArray = String.CodeUnits.toCharArray str
    chars = List.fromFoldable charArray
    taken = List.takeWhile p chars
    takenArray = Array.fromFoldable taken
  in
    String.CodeUnits.fromCharArray takenArray

-- Parse full message
messageP :: Parser Message
messageP = do
  { author, subject, messageID, inReplyTo, references, date } <- headerP
  content <- contentP
  -- let
  --   lines = List.fromFoldable (split (Pattern "\n") (trim content'))
  --   linesReversed = List.reverse lines
  --   { init, rest } = span (\ln -> startsWith (Pattern "> ") ln || ln == "") linesReversed
  --   result = case init of
  --     Nil -> rest
  --     _ -> List.dropWhile (\ln -> (startsWith (Pattern "On ") ln && endsWith (Pattern "> wrote:") ln)) rest
  --   content = joinWith "\n" (Array.fromFoldable (List.reverse result))
  pure { content, author, subject, messageID, inReplyTo, references, date }
