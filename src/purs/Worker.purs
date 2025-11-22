module Worker where

import Prelude

import Effect (Effect)
import Effect.Class.Console as Console
import Effect.Uncurried (EffectFn1)

main :: Effect Unit
main = do
  Console.log "Worker started in PureScript"
  sendMessage "Hello from PureScript"

foreign import sendMessage :: String -> Effect Unit
