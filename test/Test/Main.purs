module Test.Main where

import Prelude

import Effect (Effect)
import Effect.Aff (launchAff_)
import Test.Message.ParserSpec as ParserSpec
import Test.Message.StreamingSpec as StreamingSpec
import Test.Spec.Reporter.Console (consoleReporter)
import Test.Spec.Runner (runSpec)

main :: Effect Unit
main = launchAff_ do
  -- runSpec [ consoleReporter ] ParserSpec.spec
  runSpec [ consoleReporter ] StreamingSpec.spec

