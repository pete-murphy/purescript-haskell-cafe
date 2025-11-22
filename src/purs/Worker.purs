module Worker where

import Prelude
import Effect (Effect)
import Effect.Class.Console as Console

main :: Effect Unit
main = do
  Console.log "Worker started in PureScript"
