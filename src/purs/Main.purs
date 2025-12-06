module Main
  ( main
  , Worker
  ) where

import Prelude

import Data.Array as Array
import Data.Foldable (traverse_)
import Data.String as String
import Effect (Effect)
import Effect.Aff as Aff
import Effect.Aff.Compat (EffectFnAff)
import Effect.Aff.Compat as Compat
import Effect.Class (liftEffect)
import Effect.Class.Console as Console
import Effect.Uncurried (EffectFn1, runEffectFn1)
import Promise (Promise)
import Promise as Promise
import Promise.Aff as Promise.Aff

foreign import data Worker :: Type
foreign import worker :: Effect Worker

main :: Effect Unit
main = Aff.launchAff_ do
  _ <- Compat.fromEffectFnAff awaitWorkerReady

  pglite <- Promise.Aff.toAffE newPGlite
  _ <- liftEffect (runEffectFn1 liveQuery pglite)
  pure unit

-- onMessages worker' do
--   ( map
--       ( \message ->
--           String.joinWith "\n"
--             [ message.author
--             , message.subject
--             , message.date
--             , message.content
--             ]

--       )
--       >>> Array.intersperse "\n\n<<<<<<<<<< MESSAGE BOUNDARY >>>>>>>>\n\n"
--       >>> traverse_ addToDOM
--   )

type MessageFromWorker =
  { author :: String, subject :: String, date :: String, content :: String }

foreign import awaitWorkerReady :: EffectFnAff Unit
-- foreign import onMessages :: Worker -> (Array MessageFromWorker -> Effect Unit) -> Effect Unit

foreign import newPGlite :: Effect (Promise PGlite)
foreign import data PGlite :: Type
foreign import liveQuery :: EffectFn1 PGlite Unit
-- foreign import addToDOM :: String -> Effect Unit
