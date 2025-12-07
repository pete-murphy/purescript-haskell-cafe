module Main
  ( main
  , Worker
  ) where

import Prelude

import Effect (Effect)
import Effect.Aff as Aff
import Effect.Class (liftEffect)
import Effect.Uncurried (EffectFn1, runEffectFn1)
import Promise (Promise)
import Promise.Aff as Promise.Aff

foreign import data Worker :: Type
foreign import worker :: Effect Worker

main :: Effect Unit
main = Aff.launchAff_ do
  pglite <- Promise.Aff.toAffE newPGlite
  _ <- Promise.Aff.toAffE (runEffectFn1 liveQuery pglite)
  pure unit

foreign import newPGlite :: Effect (Promise PGlite)
foreign import data PGlite :: Type
foreign import liveQuery :: EffectFn1 PGlite (Promise Unit)
