module Message where

import Data.DateTime (DateTime)
import Data.Maybe (Maybe)

type HeaderRows =
  ( author :: String
  , subject :: String
  , messageID :: String
  , inReplyTo :: Maybe String
  , references :: Maybe String
  , date :: DateTime
  )

type Header =
  { | HeaderRows }

type Message =
  { content :: String
  | HeaderRows
  }

