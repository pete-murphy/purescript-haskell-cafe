export const sendMessage = (message) => () => {
  self.postMessage(message);
};

export const debugMessage = (message) => {
  console.log(message);
};

export const fetchSample = () => {
  let sample = "";
  return fetch(`/haskell-cafe/2005-August.txt.gz`)
    .then((response) =>
      response.body
        .pipeThrough(new DecompressionStream("gzip"))
        .pipeThrough(new TextDecoderStream())
        .pipeTo(
          new WritableStream({
            write(chunk) {
              sample += chunk;
            },
          })
        )
    )
    .then(() => sample);
  // return Promise.resolve(sample);
};

const sample = `From simon at joyful.com  Mon Oct  1 06:46:45 2018
From: simon at joyful.com (Simon Michael)
Date: Sun, 30 Sep 2018 20:46:45 -1000
Subject: [Haskell-cafe] ANN: hledger-1.11 released
Message-ID: <4409353E-75B6-46F3-9E5D-C8BA634FD554@joyful.com>

Short announcement this quarter. Pleased to announce the release of hledger 1.11 on schedule! 

Thanks to release contributors Joseph Weston, Dmitry Astapov, Gaith Hallak, Jakub ZÃ¡rybnickÃ½, Luca Molteni, and SpicyCat.

stack users will need to get a copy of hledger source and do stack install from there, due to the recent GHC 8.6 release. cabal install hledger-1.11 should work normally. 
`;

const sample_2 = `From simon at joyful.com  Mon Oct  1 06:46:45 2018
From: simon at joyful.com (Simon Michael)
Date: Sun, 30 Sep 2018 20:46:45 -1000
Subject: [Haskell-cafe] ANN: hledger-1.11 released
Message-ID: <4409353E-75B6-46F3-9E5D-C8BA634FD554@joyful.com>

Short announcement this quarter. Pleased to announce the release of hledger 1.11 on schedule! 

Thanks to release contributors Joseph Weston, Dmitry Astapov, Gaith Hallak, Jakub ZÃ¡rybnickÃ½, Luca Molteni, and SpicyCat.

stack users will need to get a copy of hledger source and do stack install from there, due to the recent GHC 8.6 release. cabal install hledger-1.11 should work normally. 

From http://hledger.org/release-notes.html#hledger-1.11 <http://hledger.org/release-notes.html#hledger-1.11> :
hledger 1.11

The default display order of accounts is now influenced by the order of account directives. Accounts declared by account directives are displayed first (top-most), in declaration order, followed by undeclared accounts in alphabetical order. Numeric account codes are no longer used, and are ignored and considered deprecated.

So if your accounts are displaying in a weird order after upgrading, and you want them alphabetical like before, just sort your account directives alphabetically.
`;
