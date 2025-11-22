export function parseRFC2822(input) {
  return new Date(input);
}

// Matches: =?<charset>?<encoding>?<encoded-text>?=
const encodedWordRe = /=\?([^?]+)\?([bBqQ])\?([^?]+)\?=/g;

/**
 * Decode RFC-2047 "encoded-words" in email headers.
 *
 * Example:
 *   decodeMimeWords('=?ISO-8859-1?Q?G=E1bor_Lehel?=')
 *   // -> "Gábor Lehel"
 */
export function decodeRFC2047(input) {
  return input.replace(encodedWordRe, (_, charset, encoding, encodedText) => {
    const cs = String(charset).toLowerCase();
    const enc = String(encoding).toUpperCase();

    let bytes;

    if (enc === "Q") {
      bytes = decodeQEncodingToBytes(encodedText);
    } else if (enc === "B") {
      bytes = decodeBase64ToBytes(encodedText);
    } else {
      // Unknown encoding, just return original chunk
      return `=?${charset}?${encoding}?${encodedText}?=`;
    }

    return decodeBytes(bytes, cs);
  });
}

/**
 * Q-encoding for headers (similar to quoted-printable, but
 * "_" means space and "=" introduces hex byte).
 */
function decodeQEncodingToBytes(encoded) {
  // "_" -> space
  let s = encoded.replace(/_/g, " ");

  const bytes = [];
  for (let i = 0; i < s.length; i++) {
    const ch = s[i];

    if (
      ch === "=" &&
      i + 2 < s.length &&
      /[0-9A-Fa-f]{2}/.test(s.slice(i + 1, i + 3))
    ) {
      const hex = s.slice(i + 1, i + 3);
      bytes.push(parseInt(hex, 16));
      i += 2; // skip hex digits
    } else {
      // In Q-encoding, literal ASCII chars are just bytes 0..127
      bytes.push(ch.charCodeAt(0) & 0xff);
    }
  }

  return new Uint8Array(bytes);
}

/**
 * Base64 decoding -> bytes.
 */
function decodeBase64ToBytes(encoded) {
  // Remove whitespace that sometimes appears in headers
  const clean = encoded.replace(/\s+/g, "");
  // atob gives a binary string (each char code 0..255)
  const bin =
    typeof atob !== "undefined"
      ? atob(clean)
      : Buffer.from(clean, "base64").toString("binary"); // Node fallback

  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) {
    bytes[i] = bin.charCodeAt(i) & 0xff;
  }
  return bytes;
}

/**
 * Decode bytes using the given charset (utf-8, iso-8859-1, etc.).
 * Falls back to Latin-1-ish if the charset isn't supported.
 */
function decodeBytes(bytes, charset) {
  // Modern browsers & Node have TextDecoder.
  if (typeof TextDecoder !== "undefined") {
    try {
      const dec = new TextDecoder(charset);
      return dec.decode(bytes);
    } catch {
      // unsupported charset -> fall through
    }
  }

  // Fallback: interpret each byte as a single code point (Latin-1 style).
  let out = "";
  for (let i = 0; i < bytes.length; i++) {
    out += String.fromCharCode(bytes[i]);
  }
  return out;
}
