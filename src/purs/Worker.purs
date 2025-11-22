module Worker where

import Prelude

import Data.DateTime.Instant as Instant
import Data.Either (Either(..))
import Data.String.CodeUnits as String
import Effect (Effect)
import Effect.Aff (Milliseconds)
import Effect.Aff as Aff
import Effect.Class (liftEffect)
import Effect.Class.Console as Console
import Effect.Now as Now
import Message (Message)
import Message.Parser as Message.Parser
import Parsing (Position(..), parseErrorMessage, parseErrorPosition)
import Promise (Promise)
import Promise.Aff as Promise.Aff

main :: Effect Unit
main = do
  Console.log "Worker started in PureScript"
  Aff.launchAff_ do
    start <- liftEffect Now.now
    sample <- Promise.Aff.toAffE fetchSample
    let result = Message.Parser.run sample
    end <- liftEffect Now.now
    Console.logShow ((Instant.diff end start) :: Milliseconds)
    case result of
      Left err -> do
        let msg = parseErrorMessage err
        let Position { index } = parseErrorPosition err
        Console.log (msg <> " at position " <> show index)
        let context = String.slice (index - 20) (index + 20) sample
        Console.log ("Context: \n" <> context)
      Right { result, suffix } -> do
        Console.logShow result
        Console.logShow suffix
        liftEffect (sendMessage (show result))

foreign import sendMessage :: String -> Effect Unit

foreign import debugMessage :: Message -> Effect Unit

foreign import fetchSample :: Effect (Promise String)