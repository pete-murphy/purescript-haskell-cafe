module Worker where

import Prelude

import Control.Lazy as Lazy
import Data.Array as Array
import Data.DateTime.Instant as Instant
import Data.Either (Either(..))
import Data.JSDate as JSDate
import Data.List (List(..), (:))
import Data.List as List
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable)
import Data.Nullable as Nullable
import Data.String as String
import Data.String.CodeUnits as String.CodeUnits
import Data.Traversable (for, for_)
import Effect (Effect)
import Effect.Aff (Aff, Milliseconds(..))
import Effect.Aff as Aff
import Effect.Aff.AVar (AVar)
import Effect.Aff.AVar as AVar
import Effect.Aff.Compat (EffectFn1, EffectFnAff, runEffectFn1)
import Effect.Aff.Compat as Aff.Compat
import Effect.Class (class MonadEffect, liftEffect)
import Effect.Class.Console as Console
import Effect.Now as Now
import Effect.Ref (Ref)
import Effect.Ref as Ref
import Effect.Unsafe as Effect.Unsafe
import Message (Message)
import Message.Parser as Message.Parser
import MessageID as MessageID
import Parsing (ParseError, Position(..), parseErrorMessage, parseErrorPosition)
import Promise (Promise)
import Promise.Aff as Promise.Aff

foreign import fetchText
  :: { filename :: String
     , onChunk :: Nullable String -> Effect Unit
     }
  -> EffectFnAff Unit

foreign import data PGlite :: Type

foreign import newPGlite :: Effect (Promise PGlite)
foreign import createSchema :: PGlite -> Effect (Promise Unit)
foreign import insertMessages
  :: { pglite :: PGlite, rows :: Array MessageForPGlite }
  -> EffectFnAff Unit

foreign import postMessage :: EffectFn1 String Unit
foreign import setupListener :: EffectFn1 (Effect Unit) Unit
foreign import consoleCount :: EffectFn1 String Unit

log :: forall m. MonadEffect m => String -> m Unit
log message = do
  Milliseconds now <- liftEffect (Instant.unInstant <$> Now.now)
  Console.log (show (now - start) <> "ms - " <> message)

start :: Number
start = Effect.Unsafe.unsafePerformEffect do
  Milliseconds now <- Instant.unInstant <$> Now.now
  pure now

main :: Effect Unit
main = Aff.launchAff_ do
  log "Worker started in PureScript"
  -- Initialize the database
  pglite <- Promise.Aff.toAffE newPGlite
  Promise.Aff.toAffE (createSchema pglite)
  log "Created schema"
  liftEffect (runEffectFn1 setupListener (handleMessage pglite))
  liftEffect (runEffectFn1 postMessage "DB_READY")

handleMessage :: PGlite -> Effect Unit
handleMessage pglite = do
  (Aff.launchAff_ <<< Aff.supervise) do

    -- Start timer
    startTime <- liftEffect Now.now

    -- Initialize the download queue
    downloadQueue <- AVar.empty

    -- Put the filenames into the download queue
    -- Try different file ranges to isolate problematic files
    -- Options:
    --   Array.take 1 (Array.drop 0 filenames)  -- First file
    --   Array.take 1 (Array.drop 80 filenames) -- File at index 80
    --   Array.take 2 (Array.drop 80 filenames) -- Two files starting at 80
    --   Array.take 5 (Array.drop 80 filenames) -- Five files starting at 80 (original)
    -- let testFiles = Array.take 80 (Array.drop 8 filenames)
    let testFiles = Array.take 20 (Array.drop 100 filenames)
    log ("Testing with " <> show (Array.length testFiles) <> " file(s): " <> String.joinWith ", " testFiles)
    for_ testFiles \filename -> do
      Aff.forkAff (AVar.put (Just filename) downloadQueue)

    log "MAIN: Waiting for all download workers to complete"

    let downloadConcurrency = 8
    for_ (Array.range 1 downloadConcurrency) \_ -> do
      Aff.forkAff (AVar.put Nothing downloadQueue)

    log "MAIN: All download workers started"

    -- Initialize the message queue
    messageQueue <- AVar.empty

    -- Start the download threads
    downloadFibers <- for (Array.range 1 downloadConcurrency) \_ -> Aff.forkAff do
      bufferRef <- liftEffect (Ref.new "")
      Lazy.fix \loop -> do
        maybeFilename <- AVar.take downloadQueue
        case maybeFilename of
          Just filename -> do
            handleDownload messageQueue bufferRef filename
            -- Clear the buffer to re-use it for the next file
            liftEffect (Ref.write "" bufferRef)
            loop
          Nothing -> do
            pure unit

    let batchSize = 100

    batchMessagesFiber <- Aff.forkAff do
      log "BATCH_PROCESSOR: Starting"
      messageRef <- liftEffect (Ref.new Nil)
      Lazy.fix \loop -> do
        maybeMessage <- AVar.take messageQueue
        liftEffect (runEffectFn1 consoleCount "BATCH_PROCESSOR: TAKE from messageQueue")
        case maybeMessage of
          Just message -> do
            messages <- liftEffect (Ref.modify (message : _) messageRef)
            let currentCount = List.length messages

            when (currentCount >= batchSize) do
              batch <- List.take batchSize <$> liftEffect (Ref.read messageRef)
              liftEffect (Ref.write (List.drop batchSize messages) messageRef)
              void do
                Aff.Compat.fromEffectFnAff (insertMessages { pglite, rows: Array.fromFoldable batch })
                log ("BATCH_PROCESSOR: Batch insert completed")

            loop

          Nothing -> do
            remainingMessages <- liftEffect (Ref.read messageRef)
            let remainingCount = List.length remainingMessages
            when (remainingCount > 0) do
              log ("BATCH_PROCESSOR: Processing final batch of " <> show remainingCount <> " messages")
            Aff.Compat.fromEffectFnAff (insertMessages { pglite, rows: Array.fromFoldable remainingMessages })
            log ("BATCH_PROCESSOR: Final batch insert completed, exiting")

    log "MAIN: Waiting for all download workers to complete"
    for_ downloadFibers Aff.joinFiber
    log "MAIN: All download workers finished"

    log "MAIN: Sending completion signal (Nothing) to messageQueue"
    AVar.put Nothing messageQueue
    log "MAIN: Completion signal sent"

    log "MAIN: Waiting for batch processor to finish"
    Aff.joinFiber batchMessagesFiber
    log "MAIN: Batch processor finished"

    end <- liftEffect Now.now
    log ("[DONE] Everything" <> show (Instant.diff end startTime :: Milliseconds))

handleDownload :: AVar (Maybe MessageForPGlite) -> Ref String -> String -> Aff Unit
handleDownload messageQueue bufferRef filename = do
  let
    handleChunk maybeChunk = Aff.launchAff_ do
      buffer <- liftEffect (Ref.read bufferRef)
      let
        { input, streamIsDone } = case maybeChunk of
          Just chunk -> { input: buffer <> chunk, streamIsDone: false }
          Nothing -> { input: buffer, streamIsDone: true }
        result = Message.Parser.run { input, streamIsDone }

      case result of
        Left err -> do
          handleParseError input err
        Right { messages, remainder } -> void do
          -- log ("[HANDLE_DOWNLOAD] Handling " <> show (Foldable.length messages :: Int) <> " messages")
          for_ messages \message -> do
            messageForPGlite <- liftEffect (makeMessageForPGlite filename message)
            Aff.forkAff (AVar.put (Just messageForPGlite) messageQueue)
          -- when (String.length remainder > 0) do log ("[HANDLE_DOWNLOAD] Writing remainder " <> String.take 60 (show remainder) <> "...")
          liftEffect (Ref.write remainder bufferRef)

  log "handleDownload: Starting fetchText"
  Aff.Compat.fromEffectFnAff (fetchText { filename, onChunk: Nullable.toMaybe >>> handleChunk })

handleParseError
  :: forall m
   . MonadEffect m
  => String
  -> ParseError
  -> m Unit
handleParseError input err = do
  let
    msg = parseErrorMessage err
    Position { index } = parseErrorPosition err
    context = String.CodeUnits.slice (index - 20) (index + 20) input
  log (msg <> " at position " <> show index)
  log ("Context: \n" <> context)

type MessageForPGlite =
  { id :: String
  , subject :: String
  , author :: String
  , date :: String
  , in_reply_to :: Array String
  , refs :: Array String
  , content :: String
  , month_file :: String
  }

makeMessageForPGlite :: String -> Message -> Effect MessageForPGlite
makeMessageForPGlite monthFile message = do
  dateString <- JSDate.fromDateTime message.date # JSDate.toISOString
  pure
    ( { id: MessageID.toString message.messageID
      , subject: message.subject
      , author: message.author
      , date: dateString
      , in_reply_to: map MessageID.toString message.inReplyTo
      , refs: map MessageID.toString message.references
      , content: message.content
      , month_file: monthFile
      }
    )

filenames :: Array String
filenames =
  [ "2025-August.txt"
  , "2025-July.txt"
  , "2025-June.txt"
  , "2025-May.txt"
  , "2025-April.txt"
  , "2025-March.txt"
  , "2025-February.txt"
  , "2025-January.txt"
  , "2024-December.txt"
  , "2024-November.txt"
  , "2024-October.txt"
  , "2024-September.txt"
  , "2024-August.txt"
  , "2024-July.txt"
  , "2024-June.txt"
  , "2024-May.txt"
  , "2024-April.txt"
  , "2024-March.txt"
  , "2024-February.txt"
  , "2024-January.txt"
  , "2023-December.txt"
  , "2023-November.txt"
  , "2023-October.txt"
  , "2023-September.txt"
  , "2023-August.txt"
  , "2023-July.txt"
  , "2023-June.txt"
  , "2023-May.txt"
  , "2023-April.txt"
  , "2023-March.txt"
  , "2023-February.txt"
  , "2023-January.txt"
  , "2022-December.txt"
  , "2022-November.txt"
  , "2022-October.txt"
  , "2022-September.txt"
  , "2022-August.txt"
  , "2022-July.txt"
  , "2022-June.txt"
  , "2022-May.txt"
  , "2022-April.txt"
  , "2022-March.txt"
  , "2022-February.txt"
  , "2022-January.txt"
  , "2021-December.txt"
  , "2021-November.txt"
  , "2021-October.txt"
  , "2021-September.txt"
  , "2021-August.txt"
  , "2021-July.txt"
  , "2021-June.txt"
  , "2021-May.txt"
  , "2021-April.txt"
  , "2021-March.txt"
  , "2021-February.txt"
  , "2021-January.txt"
  , "2020-December.txt"
  , "2020-November.txt"
  , "2020-October.txt"
  , "2020-September.txt"
  , "2020-August.txt"
  , "2020-July.txt"
  , "2020-June.txt"
  , "2020-May.txt"
  , "2020-April.txt"
  , "2020-March.txt"
  , "2020-February.txt"
  , "2020-January.txt"
  , "2019-December.txt"
  , "2019-November.txt"
  , "2019-October.txt"
  , "2019-September.txt"
  , "2019-August.txt"
  , "2019-July.txt"
  , "2019-June.txt"
  , "2019-May.txt"
  , "2019-April.txt"
  , "2019-March.txt"
  , "2019-February.txt"
  , "2019-January.txt"
  , "2018-December.txt"
  , "2018-November.txt"
  , "2018-October.txt"
  , "2018-September.txt"
  , "2018-August.txt"
  , "2018-July.txt"
  , "2018-June.txt"
  , "2018-May.txt"
  , "2018-April.txt"
  , "2018-March.txt"
  , "2018-February.txt"
  , "2018-January.txt"
  , "2017-December.txt"
  , "2017-November.txt"
  , "2017-October.txt"
  , "2017-September.txt"
  , "2017-August.txt"
  , "2017-July.txt"
  , "2017-June.txt"
  , "2017-May.txt"
  , "2017-April.txt"
  , "2017-March.txt"
  , "2017-February.txt"
  , "2017-January.txt"
  , "2016-December.txt"
  , "2016-November.txt"
  , "2016-October.txt"
  , "2016-September.txt"
  , "2016-August.txt"
  , "2016-July.txt"
  , "2016-June.txt"
  , "2016-May.txt"
  , "2016-April.txt"
  , "2016-March.txt"
  , "2016-February.txt"
  , "2016-January.txt"
  , "2015-December.txt"
  , "2015-November.txt"
  , "2015-October.txt"
  , "2015-September.txt"
  , "2015-August.txt"
  , "2015-July.txt"
  , "2015-June.txt"
  , "2015-May.txt"
  , "2015-April.txt"
  , "2015-March.txt"
  , "2015-February.txt"
  , "2015-January.txt"
  , "2014-December.txt"
  , "2014-November.txt"
  , "2014-October.txt"
  , "2014-September.txt"
  , "2014-August.txt"
  , "2014-July.txt"
  , "2014-June.txt"
  , "2014-May.txt"
  , "2014-April.txt"
  , "2014-March.txt"
  , "2014-February.txt"
  , "2014-January.txt"
  , "2013-December.txt"
  , "2013-November.txt"
  , "2013-October.txt.gz"
  , "2013-September.txt.gz"
  , "2013-August.txt.gz"
  , "2013-July.txt.gz"
  , "2013-June.txt.gz"
  , "2013-May.txt.gz"
  , "2013-April.txt.gz"
  , "2013-March.txt.gz"
  , "2013-February.txt.gz"
  , "2013-January.txt.gz"
  , "2012-December.txt.gz"
  , "2012-November.txt.gz"
  , "2012-October.txt.gz"
  , "2012-September.txt.gz"
  , "2012-August.txt.gz"
  , "2012-July.txt.gz"
  , "2012-June.txt.gz"
  , "2012-May.txt.gz"
  , "2012-April.txt.gz"
  , "2012-March.txt.gz"
  , "2012-February.txt.gz"
  , "2012-January.txt.gz"
  , "2011-December.txt.gz"
  , "2011-November.txt.gz"
  , "2011-October.txt.gz"
  , "2011-September.txt.gz"
  , "2011-August.txt.gz"
  , "2011-July.txt.gz"
  , "2011-June.txt.gz"
  , "2011-May.txt.gz"
  , "2011-April.txt.gz"
  , "2011-March.txt.gz"
  , "2011-February.txt.gz"
  , "2011-January.txt.gz"
  , "2010-December.txt.gz"
  , "2010-November.txt.gz"
  , "2010-October.txt.gz"
  , "2010-September.txt.gz"
  , "2010-August.txt.gz"
  , "2010-July.txt.gz"
  , "2010-June.txt.gz"
  , "2010-May.txt.gz"
  , "2010-April.txt.gz"
  , "2010-March.txt.gz"
  , "2010-February.txt.gz"
  , "2010-January.txt.gz"
  , "2009-December.txt.gz"
  , "2009-November.txt.gz"
  , "2009-October.txt.gz"
  , "2009-September.txt.gz"
  , "2009-August.txt.gz"
  , "2009-July.txt.gz"
  , "2009-June.txt.gz"
  , "2009-May.txt.gz"
  , "2009-April.txt.gz"
  , "2009-March.txt.gz"
  , "2009-February.txt.gz"
  , "2009-January.txt.gz"
  , "2008-December.txt.gz"
  , "2008-November.txt.gz"
  , "2008-October.txt.gz"
  , "2008-September.txt.gz"
  , "2008-August.txt.gz"
  , "2008-July.txt.gz"
  , "2008-June.txt.gz"
  , "2008-May.txt.gz"
  , "2008-April.txt.gz"
  , "2008-March.txt.gz"
  , "2008-February.txt.gz"
  , "2008-January.txt.gz"
  , "2007-December.txt.gz"
  , "2007-November.txt.gz"
  , "2007-October.txt.gz"
  , "2007-September.txt.gz"
  , "2007-August.txt.gz"
  , "2007-July.txt.gz"
  , "2007-June.txt.gz"
  , "2007-May.txt.gz"
  , "2007-April.txt.gz"
  , "2007-March.txt.gz"
  , "2007-February.txt.gz"
  , "2007-January.txt.gz"
  , "2006-December.txt.gz"
  , "2006-November.txt.gz"
  , "2006-October.txt.gz"
  , "2006-September.txt.gz"
  , "2006-August.txt.gz"
  , "2006-July.txt.gz"
  , "2006-June.txt.gz"
  , "2006-May.txt.gz"
  , "2006-April.txt.gz"
  , "2006-March.txt.gz"
  , "2006-February.txt.gz"
  , "2006-January.txt.gz"
  , "2005-December.txt.gz"
  , "2005-November.txt.gz"
  , "2005-October.txt.gz"
  , "2005-September.txt.gz"
  , "2005-August.txt.gz"
  , "2005-July.txt.gz"
  , "2005-June.txt.gz"
  , "2005-May.txt.gz"
  , "2005-April.txt.gz"
  , "2005-March.txt.gz"
  , "2005-February.txt.gz"
  , "2005-January.txt.gz"
  , "2004-December.txt.gz"
  , "2004-November.txt.gz"
  , "2004-October.txt.gz"
  , "2004-September.txt.gz"
  , "2004-August.txt.gz"
  , "2004-July.txt.gz"
  , "2004-June.txt.gz"
  , "2004-May.txt.gz"
  , "2004-April.txt.gz"
  , "2004-March.txt.gz"
  , "2004-February.txt.gz"
  , "2004-January.txt.gz"
  , "2003-December.txt.gz"
  , "2003-November.txt.gz"
  , "2003-October.txt.gz"
  , "2003-September.txt.gz"
  , "2003-August.txt.gz"
  , "2003-July.txt.gz"
  , "2003-June.txt.gz"
  , "2003-May.txt.gz"
  , "2003-April.txt.gz"
  , "2003-March.txt.gz"
  , "2003-February.txt.gz"
  , "2003-January.txt.gz"
  , "2002-December.txt.gz"
  , "2002-November.txt.gz"
  , "2002-October.txt.gz"
  , "2002-September.txt.gz"
  , "2002-August.txt.gz"
  , "2002-July.txt.gz"
  , "2002-June.txt.gz"
  , "2002-May.txt.gz"
  , "2002-April.txt.gz"
  , "2002-March.txt.gz"
  , "2002-February.txt.gz"
  , "2002-January.txt.gz"
  , "2001-December.txt.gz"
  , "2001-November.txt.gz"
  , "2001-October.txt.gz"
  , "2001-September.txt.gz"
  , "2001-August.txt.gz"
  , "2001-July.txt.gz"
  , "2001-June.txt.gz"
  , "2001-May.txt.gz"
  , "2001-April.txt.gz"
  , "2001-March.txt.gz"
  , "2001-February.txt.gz"
  , "2001-January.txt.gz"
  , "2000-December.txt.gz"
  , "2000-November.txt.gz"
  , "2000-October.txt.gz"
  ]