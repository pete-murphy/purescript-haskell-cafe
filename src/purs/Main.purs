module Main
  ( main
  , Worker
  ) where

import Prelude

import Data.Array as Array
import Data.Foldable (traverse_)
import Data.String as String
import Effect (Effect)

foreign import data Worker :: Type
foreign import worker :: Effect Worker

main :: Effect Unit
main = do
  worker' <- worker
  onMessages worker' do
    ( map
        ( \message ->
            String.joinWith "\n"
              [ message.author
              , message.subject
              , message.date
              , message.content
              ]

        )
        >>> Array.intersperse "\n\n<<<<<<<<<< MESSAGE BOUNDARY >>>>>>>>\n\n"
        >>> traverse_ addToDOM
    )

type MessageFromWorker =
  { author :: String, subject :: String, date :: String, content :: String }

foreign import onMessages :: Worker -> (Array MessageFromWorker -> Effect Unit) -> Effect Unit

foreign import addToDOM :: String -> Effect Unit
