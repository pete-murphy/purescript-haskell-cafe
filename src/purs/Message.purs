module Message where

import Data.DateTime (DateTime)
import Data.Maybe (Maybe)
import MessageID (MessageID)

type HeaderRows =
  ( author :: String
  , subject :: String
  , messageID :: MessageID
  , inReplyTo :: Array MessageID
  , references :: Array MessageID
  , date :: DateTime
  )

type Header =
  { | HeaderRows }

type Message =
  { content :: String
  | HeaderRows
  }

