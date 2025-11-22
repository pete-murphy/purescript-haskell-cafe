module Worker where

import Prelude

import Data.Array as Array
import Data.DateTime.Instant as Instant
import Data.Either (Either(..))
import Data.String.CodeUnits as String
import Effect (Effect)
import Effect.Aff (Milliseconds)
import Effect.Aff as Aff
import Effect.Class (liftEffect)
import Effect.Class.Console as Console
import Effect.Now as Now
import JS.Intl.DateTimeFormat as Intl.DateTimeFormat
import JS.Intl.Locale as Intl.Locale
import Message (Message)
import Message.Parser as Message.Parser
import Parsing (Position(..), parseErrorMessage, parseErrorPosition)
import Promise (Promise)
import Promise.Aff as Promise.Aff

main :: Effect Unit
main = do
  Console.log "Worker started in PureScript"
  en_US <- Intl.Locale.new_ "en-US"
  dateFormatter <- Intl.DateTimeFormat.new [ en_US ] { dateStyle: "long", timeStyle: "short" }
  Aff.launchAff_ do
    start <- liftEffect Now.now
    sample <- Promise.Aff.toAffE fetchSample
    let result = Message.Parser.run sample
    end <- liftEffect Now.now
    Console.logShow (Instant.diff end start :: Milliseconds)

    case result of
      Left err -> do
        let msg = parseErrorMessage err
        let Position { index } = parseErrorPosition err
        Console.log (msg <> " at position " <> show index)
        let context = String.slice (index - 20) (index + 20) sample
        Console.log ("Context: \n" <> context)
      Right messages -> do
        let messages' = messages <#> \message -> { author: message.author, subject: message.subject, date: Intl.DateTimeFormat.format dateFormatter message.date, content: message.content }
        liftEffect (debugMessage (Array.fromFoldable messages'))

foreign import sendMessage :: String -> Effect Unit

foreign import debugMessage :: forall message. Array message -> Effect Unit

foreign import fetchSample :: Effect (Promise String)