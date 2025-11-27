module Test.Message.ParserSpec where

import Prelude

import Data.Array as Array
import Data.Either (Either(..))
import Data.List ((:))
import Data.List as List
import Data.Maybe (Maybe(..))
import Data.String.CodeUnits as String
import Message.Parser as Message.Parser
import MessageID (MessageID)
import MessageID as MessageID
import Parsing (ParseError, Position(..), parseErrorMessage, parseErrorPosition)
import Parsing as Parsing
import Partial.Unsafe (unsafeCrashWith, unsafePartial)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (fail, shouldEqual, shouldSatisfy)

-- Example message contents
example1 :: String
example1 =
  """From twilson at csufresno.edu  Thu Aug  1 02:45:05 2019
From: twilson at csufresno.edu (Todd Wilson)
Date: Wed, 31 Jul 2019 19:45:05 -0700
Subject: [Haskell-cafe] Performance best practices
Message-ID: <CA+-99oLpRrX7jgDru6=xf=U3qo9SGtPK33j2rPX8eON4mrLagg@mail.gmail.com>

Dear Cafe:

I'm getting to the point in my Haskell learning curve where I'm
getting more interested in the fine points of programming for
performance and would be grateful for some ideas of the tools and
options available for exploring this. To make this concrete, let me
give a simple example. Here are two different ways of coding the same
list-splitting function:

   import Data.List (inits,tails)
   splits1, splits2 :: [a] -> [([a],[a])]
   splits1 xs = zip (inits xs) (tails xs)
   splits2 [] = [([],[])]
   splits2 xs@(x:xs') = ([],xs) : [(x:as,bs) | (as,bs) <- splits2 xs']

For example, splits1 [1,2,3] is
[([],[1,2,3]),([1],[2,3]),([1,2],[3]),([1,2,3],[])].
"""

example2 :: String
example2 =
  """From berdario at gmail.com  Fri Aug  1 00:05:26 2014
From: berdario at gmail.com (Dario Bertini)
Date: Thu, 31 Jul 2014 17:05:26 -0700
Subject: [Haskell-cafe] Tor project
In-Reply-To: <53DAB0E9.70207@power.com.pl>
References: <CA+0XtC_ZMqEGzfQEVoJeQDknAzWhvKREqidgxJZF26A-29JRUw@mail.gmail.com>
 <lrci4n$ito$1@ger.gmane.org>
 <0A84F9F7-1349-489E-8B36-717FC0226D9F@proclivis.com>
 <CAOk36JgTezuRvRgypijPDMOTiB0ZSqvmTjOMojHt99dCtsgE=g@mail.gmail.com>
 <BE276BE3-CF40-4529-B994-06E8BB948416@galois.com>
 <53DAB0E9.70207@power.com.pl>
Message-ID: <CAFdyfB2_bcuLeE3EkidDkdRzYMr=Xfw_fBsLFgS1ygwQpM3a=g@mail.gmail.com>

On Thu, Jul 31, 2014 at 2:11 PM, Wojtek Narczy?ski <wojtek at power.com.pl> wrote:
> But, AFAIK, the (necessary and sufficient) protection against timing attacks
> is the addition of randomized waits. In the protocol layer, not in pure
> encryption/decryption/hashing routines.

I agree that we don't have a lot of evidence for/against timing
attacks in functional languages (that I know of).

But adding a randomized delay never seemed the correct solution to me
(granted, I had the luck to never had to write code sensitive to such
issues, and I never wrote a timing attack exploit either), I don't
think that doing it in the protocol layer makes it neither necessary
nor sufficient.

http://rdist.root.org/2010/01/07/timing-independent-array-comparison/

This explains the pitfalls in some possible timing attack misconceptions
"""

example3 :: String
example3 =
  """From reuleaux at web.de  Thu Aug  7 16:32:11 2014
From: reuleaux at web.de (Andreas Reuleaux)
Date: Thu, 07 Aug 2014 17:32:11 +0100
Subject: [Haskell-cafe] parsec: problem combining lookAhead with many1
	(bug?)
In-Reply-To: <CAMmzbfWA9S3YGjJ1iQaa72rKZyuV4psvEP3LsQuDGC3QED-YVw@mail.gmail.com>
 (silly's message of "Thu, 7 Aug 2014 15:25:23 +0100")
References: <CAMmzbfWA9S3YGjJ1iQaa72rKZyuV4psvEP3LsQuDGC3QED-YVw@mail.gmail.com>
Message-ID: <87y4v0z2es.fsf@web.de>

While I haven't tried out your example in parsec, I can at least confirm
that in trifecta it does work that way you expect it, ie. there is no
difference between the error messages in both of your cases:
(parsec's many1 = trifecta's some)
"""

example4 :: String
example4 =
  """From chriswarbo at googlemail.com  Tue Aug 12 09:30:43 2014
From: chriswarbo at googlemail.com (Chris Warburton)
Date: Tue, 12 Aug 2014 10:30:43 +0100
Subject: [Haskell-cafe] The Good, the Bad and the GUI
In-Reply-To: <53E9C868.9090406@power.com.pl> ("Wojtek =?utf-8?Q?Narczy?=
 =?utf-8?Q?=C5=84ski=22's?= message of
 "Tue, 12 Aug 2014 09:55:20 +0200")
References: <53E940BF.5040500@power.com.pl>
 <fdddebd36638a465c1eac482c0be80d4.squirrel@chasm.otago.ac.nz>
 <53E9C868.9090406@power.com.pl>
Message-ID: <864mxi6on0.fsf@gmail.com>

Wojtek Narczy?ski <wojtek at power.com.pl> writes:

> Take a VAT Invoice as an example. You will have:
>
> Invoice, InvoiceBuilder,
> InvoiceLineItem, InvoiceLineItemBuilder,
> InvoiceCustomer, InvoiceCustomerBuilder,
> InvoiceSummary, (no Builder, as this is calculated)
> (many, many more classes in a realistic system)
>
> Now, where the rather complex validation belongs? Optional / mandatory
> requirements, lengths, ranges, regexps, control sums, field
> interdependencies, autocompletes, server sent notifications? Where to
> put all of this? To regular classes, to builder classes, or to both?

The current trend in OOP Web frameworks Model-View-Controller.

In MVP, Invoice/InvoiceLineItem/InvoiceCustomer/InvoiceSummary/etc. are
the Model: they should form a standalone 'simulation' of an Invoice,
without concerning themselves with 'external' aspects.

Validation, bootstrapping (builders), etc. live in the Controller
layer.
"""

example5 :: String
example5 =
  """From chriswarbo at googlemail.com  Thu Aug 14 09:37:35 2014
From: chriswarbo at googlemail.com (Chris Warburton)
Date: Thu, 14 Aug 2014 10:37:35 +0100
Subject: [Haskell-cafe] Does the lambda calculus have provisions for
	I/O? State can be done with free variables.
In-Reply-To: <CAMLKXynJhDV-WA-5Yb1=vVHoy5mwL+TZODXMKN182Ch5+3VuQg@mail.gmail.com>
 (KC's message of "Wed, 13 Aug 2014 14:39:01 -0700")
References: <CAMLKXynJhDV-WA-5Yb1=vVHoy5mwL+TZODXMKN182Ch5+3VuQg@mail.gmail.com>
Message-ID: <86k36b5s4g.fsf@gmail.com>

KC <kc1956 at gmail.com> writes:

> Hi:
>
> Does the lambda calculus have provisions for I/O?
> State can be done with free variables.

Lambda Calculus can't do IO "internally"; we can't mutate variables,
whether or not they're free.
"""

example6 :: String
example6 =
  """From nickgrey at softhome.net  Mon Feb  2 16:26:23 2004
From: nickgrey at softhome.net (nickgrey@softhome.net)
Date: Mon Feb  2 18:26:29 2004
Subject: [Haskell-cafe] Re: Storing functional values
In-Reply-To: <20040201211232.GC18596@lotus.bostoncoop.net> 
References: <courier.401A84A6.00003DAE@softhome.net>
            <20040201211232.GC18596@lotus.bostoncoop.net>
Message-ID: <courier.401EDC9F.00007478@softhome.net>

Dylan Thurston writes: 

> It seems like there are two things you want to do with these
> functional closures: save them to disk, and run them as functions.
> Why not combine these two into a type class?

Dylan
"""

example7 :: String
example7 =
  """From maihem at maihem.org  Sat Jan  1 17:47:37 2005
From: maihem at maihem.org (Tristan Wibberley)
Date: Sat Jan  1 17:38:25 2005
Subject: [Haskell-cafe] Re: Haskell Pangolins
In-Reply-To: <20041230083129.GA2920@students.mimuw.edu.pl>
References: <MCEBKKALDLDAPJPPPKOHOELHCJAA.dominic.fox1@ntlworld.com>	<200412291954.15855.p.turner@computer.org>
	<20041230083129.GA2920@students.mimuw.edu.pl>
Message-ID: <cr79a9$pd4$1@sea.gmane.org>

Tomasz Zielonka wrote:
"""

example8 :: String
example8 =
  """From romildo@urano.iceb.ufop.br  Tue Oct 10 18:49:59 2000
Date: Tue, 10 Oct 2000 15:49:59 -0200
From: =?iso-8859-1?Q?Jos=E9_Romildo_Malaquias?= romildo@urano.iceb.ufop.br
Subject: Haskell Problem

<PRE>On Tue, Oct 10, 2000 at 07:11:14PM +0100, Graeme Turner wrote:
&gt;<i> The basic aim is to read in a file of data, sort it and then display it.
</I>&gt;<i> 
</I>&gt;<i> I have managed to get a sort to function properly but I am having trouble
</I>&gt;<i> with reading in the data from the file. I have managed to use the
</I>&gt;<i> hGetContents and hGetLine methods of the IO library to read the data in but
</I>&gt;<i> when it is read in, it is stored as an IO String type.
</I>&gt;<i> 
</I>&gt;<i> I would like to convert the input from the file into one large string so I
</I>&gt;<i> can process it before sorting it.
</I>&gt;<i> 
</I>&gt;<i> After reading the whole file into a variable, how do I then convert that IO
</I>&gt;<i> String to a String?
</I>
You do not have to convert from the abstract data type IO String into String.
You can access the string encapsulated in such abstract data type
using monad operations. The type IO String is the type of the computations
that perform input/output and produces a string as their result. You
can pass this result as an argument to a function of type String -&gt; IO a
which may do the desired manipulation on the string and may also perform
some more input/output and should produce a result of type a.
"""

-- Helper function to parse a MessageID from a string (with angle brackets)
parseMessageID :: String -> MessageID
parseMessageID str =
  unsafePartial case Parsing.runParser str MessageID.parser of
    Right msgID -> msgID
    Left _ -> unsafeCrashWith "Failed to parse MessageID in test"

-- Helper function to format parse errors for test failures
formatParseError :: String -> ParseError -> String
formatParseError input err =
  let
    msg = parseErrorMessage err
    Position { index } = parseErrorPosition err
    contextStart = max 0 (index - 40)
    contextEnd = min (String.length input) (index + 40)
    start = String.slice contextStart index input
    end = String.slice index contextEnd input
    context = start <> "|" <> end
  in
    "Parse error: " <> msg <> " at position " <> show index <> "\nContext: " <> context

spec :: Spec Unit
spec = do
  describe "Message.Parser" do
    describe "example 1" do
      it "parses successfully" do
        case Message.Parser.run example1 of
          Right _ -> pure unit
          Left err -> fail (formatParseError example1 err)

      it "has empty remainder" do
        case Message.Parser.run example1 of
          Right { remainder } -> remainder `shouldEqual` ""
          Left err -> fail (formatParseError example1 err)

      it "parses exactly one message" do
        case Message.Parser.run example1 of
          Right { messages } -> List.length messages `shouldEqual` 1
          Left err -> fail (formatParseError example1 err)

      it "extracts author correctly" do
        case Message.Parser.run example1 of
          Right { messages: (message : _) } -> message.author `shouldEqual` "Todd Wilson"
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example1 err)

      it "extracts subject correctly" do
        case Message.Parser.run example1 of
          Right { messages: (message : _) } -> message.subject `shouldEqual` "Performance best practices"
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example1 err)

      it "extracts messageID correctly" do
        case Message.Parser.run example1 of
          Right { messages: (message : _) } -> message.messageID `shouldEqual` parseMessageID "<CA+-99oLpRrX7jgDru6=xf=U3qo9SGtPK33j2rPX8eON4mrLagg@mail.gmail.com>"
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example1 err)

      it "extracts content correctly" do
        case Message.Parser.run example1 of
          Right { messages: (message : _) } -> message.content `shouldSatisfy` (_ /= "")
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example1 err)

    describe "example 2" do
      it "parses successfully" do
        case Message.Parser.run example2 of
          Right _ -> pure unit
          Left err -> fail (formatParseError example2 err)

      it "has empty remainder" do
        case Message.Parser.run example2 of
          Right { remainder } -> remainder `shouldEqual` ""
          Left err -> fail (formatParseError example2 err)

      it "parses exactly one message" do
        case Message.Parser.run example2 of
          Right { messages } -> List.length messages `shouldEqual` 1
          Left err -> fail (formatParseError example2 err)

      it "extracts author correctly" do
        case Message.Parser.run example2 of
          Right { messages: (message : _) } -> message.author `shouldEqual` "Dario Bertini"
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example2 err)

      it "extracts subject correctly" do
        case Message.Parser.run example2 of
          Right { messages: (message : _) } -> message.subject `shouldEqual` "Tor project"
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example2 err)

      it "extracts messageID correctly" do
        case Message.Parser.run example2 of
          Right { messages: (message : _) } -> message.messageID `shouldEqual` parseMessageID "<CAFdyfB2_bcuLeE3EkidDkdRzYMr=Xfw_fBsLFgS1ygwQpM3a=g@mail.gmail.com>"
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example2 err)

      it "extracts inReplyTo correctly" do
        case Message.Parser.run example2 of
          Right { messages: (message : _) } -> do
            Array.length message.inReplyTo `shouldEqual` 1
            Array.head message.inReplyTo `shouldEqual` Just (parseMessageID "<53DAB0E9.70207@power.com.pl>")
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example2 err)

      it "extracts references correctly" do
        case Message.Parser.run example2 of
          Right { messages: (message : _) } -> Array.length message.references `shouldEqual` 6
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example2 err)

      it "extracts content correctly" do
        case Message.Parser.run example2 of
          Right { messages: (message : _) } -> message.content `shouldSatisfy` (_ /= "")
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example2 err)

    describe "example 3" do
      it "parses successfully" do
        case Message.Parser.run example3 of
          Right _ -> pure unit
          Left err -> fail (formatParseError example3 err)

      it "has empty remainder" do
        case Message.Parser.run example3 of
          Right { remainder } -> remainder `shouldEqual` ""
          Left err -> fail (formatParseError example3 err)

      it "parses exactly one message" do
        case Message.Parser.run example3 of
          Right { messages } -> List.length messages `shouldEqual` 1
          Left err -> fail (formatParseError example3 err)

      it "extracts author correctly" do
        case Message.Parser.run example3 of
          Right { messages: (message : _) } -> message.author `shouldEqual` "Andreas Reuleaux"
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example3 err)

      it "extracts subject correctly" do
        case Message.Parser.run example3 of
          Right { messages: (message : _) } -> message.subject `shouldEqual` "parsec: problem combining lookAhead with many1 (bug?)"
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example3 err)

      it "extracts messageID correctly" do
        case Message.Parser.run example3 of
          Right { messages: (message : _) } -> message.messageID `shouldEqual` parseMessageID "<87y4v0z2es.fsf@web.de>"
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example3 err)

      it "extracts inReplyTo correctly" do
        case Message.Parser.run example3 of
          Right { messages: (message : _) } -> do
            Array.length message.inReplyTo `shouldEqual` 1
            Array.head message.inReplyTo `shouldEqual` Just (parseMessageID "<CAMmzbfWA9S3YGjJ1iQaa72rKZyuV4psvEP3LsQuDGC3QED-YVw@mail.gmail.com>")
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example3 err)

      it "extracts references correctly" do
        case Message.Parser.run example3 of
          Right { messages: (message : _) } -> Array.length message.references `shouldEqual` 1
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example3 err)

      it "extracts content correctly" do
        case Message.Parser.run example3 of
          Right { messages: (message : _) } -> message.content `shouldSatisfy` (_ /= "")
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example3 err)

    describe "example 4" do
      it "parses successfully" do
        case Message.Parser.run example4 of
          Right _ -> pure unit
          Left err -> fail (formatParseError example4 err)

      it "has empty remainder" do
        case Message.Parser.run example4 of
          Right { remainder } -> remainder `shouldEqual` ""
          Left err -> fail (formatParseError example4 err)

      it "parses exactly one message" do
        case Message.Parser.run example4 of
          Right { messages } -> List.length messages `shouldEqual` 1
          Left err -> fail (formatParseError example4 err)

      it "extracts author correctly" do
        case Message.Parser.run example4 of
          Right { messages: (message : _) } -> message.author `shouldEqual` "Chris Warburton"
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example4 err)

      it "extracts subject correctly" do
        case Message.Parser.run example4 of
          Right { messages: (message : _) } -> message.subject `shouldEqual` "The Good, the Bad and the GUI"
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example4 err)

      it "extracts messageID correctly" do
        case Message.Parser.run example4 of
          Right { messages: (message : _) } -> message.messageID `shouldEqual` parseMessageID "<864mxi6on0.fsf@gmail.com>"
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example4 err)

      it "extracts inReplyTo correctly" do
        case Message.Parser.run example4 of
          Right { messages: (message : _) } -> do
            Array.length message.inReplyTo `shouldEqual` 1
            Array.head message.inReplyTo `shouldEqual` Just (parseMessageID "<53E9C868.9090406@power.com.pl>")
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example4 err)

      it "extracts references correctly" do
        case Message.Parser.run example4 of
          Right { messages: (message : _) } -> Array.length message.references `shouldEqual` 3
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example4 err)

      it "extracts content correctly" do
        case Message.Parser.run example4 of
          Right { messages: (message : _) } -> message.content `shouldSatisfy` (_ /= "")
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example4 err)

    describe "example 5" do
      it "parses successfully" do
        case Message.Parser.run example5 of
          Right _ -> pure unit
          Left err -> fail (formatParseError example5 err)

      it "has empty remainder" do
        case Message.Parser.run example5 of
          Right { remainder } -> remainder `shouldEqual` ""
          Left err -> fail (formatParseError example5 err)

      it "parses exactly one message" do
        case Message.Parser.run example5 of
          Right { messages } -> List.length messages `shouldEqual` 1
          Left err -> fail (formatParseError example5 err)

      it "extracts author correctly" do
        case Message.Parser.run example5 of
          Right { messages: (message : _) } -> message.author `shouldEqual` "Chris Warburton"
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example5 err)

      it "extracts subject correctly" do
        case Message.Parser.run example5 of
          Right { messages: (message : _) } -> message.subject `shouldEqual` "Does the lambda calculus have provisions for I/O? State can be done with free variables."
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example5 err)

      it "extracts messageID correctly" do
        case Message.Parser.run example5 of
          Right { messages: (message : _) } -> message.messageID `shouldEqual` parseMessageID "<86k36b5s4g.fsf@gmail.com>"
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example5 err)

      it "extracts inReplyTo correctly" do
        case Message.Parser.run example5 of
          Right { messages: (message : _) } -> do
            Array.length message.inReplyTo `shouldEqual` 1
            Array.head message.inReplyTo `shouldEqual` Just (parseMessageID "<CAMLKXynJhDV-WA-5Yb1=vVHoy5mwL+TZODXMKN182Ch5+3VuQg@mail.gmail.com>")
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example5 err)

      it "extracts references correctly" do
        case Message.Parser.run example5 of
          Right { messages: (message : _) } -> Array.length message.references `shouldEqual` 1
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example5 err)

      it "extracts content correctly" do
        case Message.Parser.run example5 of
          Right { messages: (message : _) } -> message.content `shouldSatisfy` (_ /= "")
          Right _ -> fail "Expected at least one message"
          Left err -> fail (formatParseError example5 err)

    describe "example 6" do
      it "parses successfully" do
        case Message.Parser.run example6 of
          Right _ -> pure unit
          Left err -> fail (formatParseError example6 err)

      it "has empty remainder" do
        case Message.Parser.run example6 of
          Right { remainder } -> remainder `shouldEqual` ""
          Left err -> fail (formatParseError example6 err)

      it "parses exactly one message" do
        case Message.Parser.run example6 of
          Right { messages } -> List.length messages `shouldEqual` 1
          Left err -> fail (formatParseError example6 err)

    describe "example 7" do
      it "parses successfully" do
        case Message.Parser.run example7 of
          Right _ -> pure unit
          Left err -> fail (formatParseError example7 err)

      it "has empty remainder" do
        case Message.Parser.run example7 of
          Right { remainder } -> remainder `shouldEqual` ""
          Left err -> fail (formatParseError example7 err)

      it "parses exactly one message" do
        case Message.Parser.run example7 of
          Right { messages } -> List.length messages `shouldEqual` 1
          Left err -> fail (formatParseError example7 err)