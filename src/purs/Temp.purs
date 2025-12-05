module Temp where

import Prelude

import Control.Lazy as Lazy
import Data.Array as Array
import Data.Foldable as Foldable
import Data.List (List(..), (:))
import Data.List as List
import Data.Maybe (Maybe(..))
import Data.Traversable (for, for_)
import Effect (Effect)
import Effect.Aff (Aff, Milliseconds(..))
import Effect.Aff as Aff
import Effect.Aff.AVar as AVar
import Effect.Class (class MonadEffect, liftEffect)
import Effect.Now as Now
import Effect.Ref as Ref
import JS.Intl.DateTimeFormat as Intl.DateTimeFormat
import TryPureScript (code, p, render, text)

smallDelay :: Aff Unit
smallDelay = Aff.delay (200.0 # Milliseconds)

main :: Effect Unit
main = Aff.launchAff_ do
  Aff.supervise do
    log "[MAIN] Starting"
    smallDelay

    let numberOfFiles = 11
    downloadQueue <- AVar.empty
    for_ (Array.range 1 numberOfFiles) \i -> Aff.forkAff do
      smallDelay
      log ("[DOWNLOAD FILE FIBER " <> show i <> "] Putting " <> ("file-" <> show i) <> " into downloadQueue")
      AVar.put (Just ("file-" <> show i)) downloadQueue

    let concurrency = 3
    for_ (Array.range 1 concurrency) \i -> Aff.forkAff do
      smallDelay
      log ("[DOWNLOAD DONE FIBER " <> show i <> "] Putting Nothing into downloadQueue to signal done")
      AVar.put Nothing downloadQueue

    messageQueue <- AVar.empty

    downloadWorkerFibers <- for (Array.range 1 concurrency) \i -> Aff.forkAff do
      Lazy.fix \loop -> do
        maybeFilename <- AVar.take downloadQueue
        case maybeFilename of
          Just filename -> do
            log ("[WORKER FIBER " <> show i <> "] Receiving " <> filename)
            let numberOfMessagesPerFile = 6
            for_ (Array.range 1 numberOfMessagesPerFile) \j -> do
              smallDelay -- Download streaming response of messages
              log ("[WORKER FIBER " <> show i <> "] Putting " <> ("message-" <> filename <> "-" <> show j) <> " into messageQueue")
              AVar.put (Just ("message-" <> filename <> "-" <> show j)) messageQueue
            loop

          Nothing -> do
            -- Done
            pure unit

    let batchSize = 10

    batchMessagesFiber <- Aff.forkAff do
      messagesRef <- liftEffect (Ref.new Nil)
      Lazy.fix \loop -> do
        smallDelay
        maybeMessage <- AVar.take messageQueue
        case maybeMessage of
          Just message -> do
            messages <- liftEffect (Ref.modify (message : _) messagesRef)
            when (Foldable.length messages >= batchSize) do
              batch <- List.take batchSize <$> liftEffect (Ref.read messagesRef)
              liftEffect (Ref.write (List.drop batchSize messages) messagesRef)
              log ("[BATCH] Inserting batch of messages: " <> show batch)
            loop

          Nothing -> do
            log ("[BATCH] Inserting final batch of messages")
            Lazy.fix \innerLoop -> do
              smallDelay
              batch <- List.take batchSize <$> liftEffect (Ref.read messagesRef)
              remaining <- liftEffect (Ref.modify (List.drop batchSize) messagesRef)
              log ("[BATCH] Inserting batch of messages: " <> show batch)

              when (Foldable.length remaining > 0) do
                -- TODO: Shouldn't happen?
                log ("[BATCH] Looping again, with remaining messages: " <> show remaining)
                innerLoop

    log "[MAIN] Waiting for download workers to finish"
    for_ downloadWorkerFibers Aff.joinFiber

    log "[MAIN] Putting Nothing into messageQueue to signal done"
    AVar.put Nothing messageQueue

    Aff.joinFiber batchMessagesFiber

log :: forall m. MonadEffect m => String -> m Unit
log message = do
  now <- liftEffect do
    Intl.DateTimeFormat.format <$> Intl.DateTimeFormat.new [] { timeStyle: "long" } <*> Now.nowDateTime
  let html = p (code (text now) <> text " - " <> text message)
  liftEffect (render html)

