module Main
  ( main
  ) where

import Prelude

import Effect (Effect)
import Effect.Aff as Aff
import Effect.Class.Console as Console
import Message.Parser (Message)
import Message.Parser as Message.Parser
import Promise (Promise)
import Promise.Aff as Promise.Aff

main :: Effect Unit
main = do
  Console.log "Main started in PureScript"
  Aff.launchAff_ do
    sample <- Promise.Aff.toAffE fetchSample
    let result = Message.Parser.run sample
    Console.logShow result

foreign import fetchSample :: Effect (Promise String)