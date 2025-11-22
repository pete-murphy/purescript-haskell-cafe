module Message where

import Prelude

import Data.Maybe (Maybe)

-- Header type
type Header =
  ( author :: String
  , subject :: String
  , messageID :: String
  , inReplyTo :: Maybe String
  , references :: Maybe String
  , date :: String
  )

-- Message type
type Message =
  { content :: String
  | Header
  }

