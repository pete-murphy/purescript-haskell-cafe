export const sendMessage = (message) => () => {
  self.postMessage(message);
};

export const debugMessage = (message) => () => {
  self.postMessage(message);
};

export const fetchSample = () => {
  // return Promise.resolve(sample);
  return fetch(`/haskell-cafe/2019-August.txt`).then((response) =>
    response.text()
  );
  // let sample = "";
  // return fetch(`/haskell-cafe/2005-August.txt.gz`)
  //   .then((response) =>
  //     response.body
  //       .pipeThrough(new DecompressionStream("gzip"))
  //       .pipeThrough(new TextDecoderStream())
  //       .pipeTo(
  //         new WritableStream({
  //           write(chunk) {
  //             sample += chunk;
  //           },
  //         })
  //       )
  //   )
  //   .then(() => sample);
};

const sample = `From michael at snoyman.com  Fri Aug  1 05:00:33 2014
From: michael at snoyman.com (Michael Snoyman)
Date: Fri, 1 Aug 2014 08:00:33 +0300
Subject: [Haskell-cafe] Bad interaction of inlinePerformIO and mutable
	vectors
In-Reply-To: <CAKA2JgKbBErAn=F4uc1-Z2bwHxx=0+zM9Ft9v7cN3C17mhBkHA@mail.gmail.com>
References: <CAKA2JgLJbCWW--3DduooqBsv=jngu89Utb8dndysc9ydBdgkcA@mail.gmail.com>
 <53DA2A1C.3080103@gmail.com> <53DA5258.60509@gmail.com>
 <CAKA2JgKbBErAn=F4uc1-Z2bwHxx=0+zM9Ft9v7cN3C17mhBkHA@mail.gmail.com>
Message-ID: <CAKA2JgLfhYz+f8s4oDVnO42pDGfbaW2hN4M=TBnSQkg0NSsRng@mail.gmail.com>

tl;dr: Thanks to Felipe's comments, I think I've found the issue, which is
in the primitive package, together with a possible GHC bug. Following is my
blow-by-blow walk through on this issue.

OK, a little more information, and a simpler repro. This is reproducible
entirely with the primitive package:

    import Control.Monad.Primitive
    import Data.Primitive.Array

    main :: IO ()
    main = do
        arr <- newArray 1 'A'
        let unit = unsafeInlineIO $ writeArray arr 0 'B'
        readArray arr 0 >>= print
        return $! unit
        readArray arr 0 >>= print

However, it's not reproducible with the underlying primops:

 
`;
