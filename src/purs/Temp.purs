-- | Async Pipeline Demo: File Download → Message Streaming → Batch Insertion
-- |
-- | This module demonstrates an async pipeline using AVars for coordination:
-- | 1. Download files with N concurrent downloads
-- | 2. Stream each file into chunks ("messages")
-- | 3. Batch messages from various files and insert into DB
module Temp where

import Prelude

import Control.Lazy as Lazy
import Data.Array as Array
import Data.DateTime.Instant as Instant
import Data.Int as Int
import Data.List (List(..), (:))
import Data.List as List
import Data.Maybe (Maybe(..))
import Data.Traversable (for, for_)
import Effect (Effect)
import Effect.Aff (Milliseconds(..))
import Effect.Aff as Aff
import Effect.Aff.AVar as AVar
import Effect.Class (class MonadEffect, liftEffect)
import Effect.Now as Now
import Effect.Ref as Ref
import Effect.Unsafe as Effect.Unsafe
import TryPureScript (code, p, render, text)

-- | Main pipeline orchestrator
-- |
-- | Coordinates three stages:
-- | 1. File producers: Enqueue files to download
-- | 2. Download workers: Download files and stream messages
-- | 3. Batch processor: Collect messages and insert in batches
main :: Effect Unit
main = (Aff.launchAff_ <<< Aff.supervise) do
  log "MAIN: Pipeline starting"

  -- ============================================================================
  -- Stage 1: File Download Queue Setup
  -- ============================================================================
  -- Create a queue for files to be downloaded
  let numberOfFiles = 4
  downloadQueue <- AVar.empty

  -- Fork fibers that enqueue files to download
  -- Each fiber represents a file that needs to be downloaded
  for_ (Array.range 1 numberOfFiles) \i -> do
    let filename = "file-" <> show i
    log ("FILE_PRODUCER[" <> show i <> "]: Enqueuing file → " <> filename)
    Aff.forkAff (AVar.put (Just filename) downloadQueue)

  -- Fork fibers that signal completion (one per concurrent worker)
  -- These send Nothing to indicate no more files will be added
  let concurrency = 3
  for_ (Array.range 1 concurrency) \i -> do
    log ("FILE_PRODUCER[DONE-" <> show i <> "]: Sending completion signal")
    Aff.forkAff (AVar.put Nothing downloadQueue)

  -- ============================================================================
  -- Stage 2: Message Queue Setup
  -- ============================================================================
  -- Create a queue for messages (chunks) streamed from downloaded files
  messageQueue <- AVar.empty

  -- ============================================================================
  -- Stage 3: Download Workers (Concurrent File Processing)
  -- ============================================================================
  -- Fork N concurrent workers that:
  -- - Take files from downloadQueue
  -- - Download and stream each file into messages
  -- - Enqueue messages into messageQueue
  downloadWorkerFibers <- for (Array.range 1 concurrency) \workerId -> Aff.forkAff do
    Lazy.fix \loop -> do
      maybeFilename <- AVar.take downloadQueue
      case maybeFilename of
        Just filename -> do
          log ("DOWNLOAD_WORKER[" <> show workerId <> "]: Processing file → " <> filename)

          -- Stream messages from this file
          let numberOfMessagesPerFile = 6
          for_ (Array.range 1 numberOfMessagesPerFile) \msgNum -> do
            let messageId = "message-" <> filename <> "-" <> show msgNum
            log ("DOWNLOAD_WORKER[" <> show workerId <> "]: Streaming message[" <> show msgNum <> "/" <> show numberOfMessagesPerFile <> "] → " <> messageId)
            Aff.delay (100.0 # Milliseconds)
            Aff.forkAff (AVar.put (Just messageId) messageQueue)
          loop

        Nothing -> do
          log ("DOWNLOAD_WORKER[" <> show workerId <> "]: Received completion signal, shutting down")
          pure unit

  -- ============================================================================
  -- Stage 4: Batch Message Processor
  -- ============================================================================
  -- Collects messages and inserts them in batches when batchSize is reached
  let batchSize = 10

  batchMessagesFiber <- Aff.forkAff do
    messagesRef <- liftEffect (Ref.new Nil)
    batchNumRef <- liftEffect (Ref.new 0)

    Lazy.fix \loop -> do
      maybeMessage <- AVar.take messageQueue
      case maybeMessage of
        Just message -> do
          -- Add message to accumulator
          messages <- liftEffect (Ref.modify (message : _) messagesRef)
          let currentCount = List.length messages
          log ("BATCH_PROCESSOR: Received message " <> show message <> ", accumulator size = " <> show currentCount)

          -- When we have enough messages, process a batch
          when (currentCount >= batchSize) do
            batchNum <- liftEffect (Ref.modify (_ + 1) batchNumRef)
            batch <- (List.reverse <<< List.take batchSize) <$> liftEffect (Ref.read messagesRef)
            remaining <- liftEffect (Ref.modify (List.drop batchSize) messagesRef)
            log ("BATCH_PROCESSOR: Batch[" <> show batchNum <> "] INSERTING " <> show (List.length batch) <> " messages → " <> show batch)
            log ("BATCH_PROCESSOR: Remaining in accumulator: " <> show (List.length remaining))
            Aff.delay (1200.0 # Milliseconds)
          loop

        Nothing -> do
          log ("BATCH_PROCESSOR: Received completion signal, processing final batches")
          -- Process any remaining messages in batches
          Lazy.fix \innerLoop -> do
            allMessages <- liftEffect (Ref.read messagesRef)
            let remainingCount = List.length allMessages

            when (remainingCount > 0) do
              batchNum <- liftEffect (Ref.modify (_ + 1) batchNumRef)
              let batch = List.reverse (List.take batchSize allMessages)
              let remaining = List.drop batchSize allMessages
              liftEffect (Ref.write remaining messagesRef)
              log ("BATCH_PROCESSOR: Final Batch[" <> show batchNum <> "] INSERTING " <> show (List.length batch) <> " messages → " <> show batch)
              log ("BATCH_PROCESSOR: Remaining after batch: " <> show (List.length remaining))
              Aff.delay (1200.0 # Milliseconds)

              when (List.length remaining > 0) do
                innerLoop
            pure unit

  -- ============================================================================
  -- Cleanup: Wait for workers and signal completion
  -- ============================================================================
  log "MAIN: Waiting for all download workers to complete"
  for_ downloadWorkerFibers Aff.joinFiber

  log "MAIN: All download workers finished, signaling message queue completion"
  AVar.put Nothing messageQueue

  log "MAIN: Waiting for batch processor to finish"
  Aff.joinFiber batchMessagesFiber
  log "MAIN: Pipeline complete"

-- | Log a message with timestamp for debugging and tracing pipeline execution
-- |
-- | Messages are prefixed with component labels (e.g., "MAIN:", "DOWNLOAD_WORKER[1]:")
-- | to make it easy to correlate logs back to their source code locations.
log :: forall m. MonadEffect m => String -> m Unit
log message = do
  Milliseconds millis <- liftEffect do
    Instant.unInstant <$> Now.now
  let
    diff = Int.floor (millis - start)
    html = p (code (text (show diff <> "ms - " <> message)))
  liftEffect (render html)

start :: Number
start = Effect.Unsafe.unsafePerformEffect do
  Milliseconds now <- Instant.unInstant <$> Now.now
  pure (now)
