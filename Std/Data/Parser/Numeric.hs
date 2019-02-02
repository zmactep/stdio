{-# LANGUAGE BangPatterns #-}

module Std.Data.Parser.Numeric where

import           Control.Applicative
import           Control.Monad
import           Data.Bits
import           Data.Int
import qualified Data.Primitive.PrimArray as A
import qualified Data.Scientific          as Sci
import           Data.Word
import           Data.Word8               (isDigit, isHexDigit)
import qualified Std.Data.Parser.Base     as P
import qualified Std.Data.Vector.Base     as V
import qualified Std.Data.Vector.Extra    as V

minus, plus, littleE, bigE, dot :: Word8
minus    = 45
plus     = 43
littleE = 101
bigE    = 69
dot      = 46

-- | Parse and decode an unsigned hex number.  The hex digits
-- @\'a\'@ through @\'f\'@ may be upper or lower case.
--
-- This parser does not accept a leading @\"0x\"@ string, and consider
-- sign bit part of the binary hex nibbles, i.e.
-- 'parse hex "0xFF" == Right (-1 :: Int8)'
--
hex :: (Integral a, Bits a) => P.Parser a
{-# INLINE hex #-}
hex = do
    (V.Vec arr s l) <- P.takeWhile1 isHexDigit
    return $! hexLoop arr s (l-1) 0
  where
    hexLoop arr !i !j !acc
        | j == 0 = acc .|. w2iHex (A.indexPrimArray arr i)
        | otherwise =
            let acc' = acc .|. w2iHex (A.indexPrimArray arr i) `unsafeShiftL` (j*4)
            in hexLoop arr (i+1) (j-1) acc'

w2iHex :: (Integral a) => Word8 -> a
{-# INLINE w2iHex #-}
w2iHex w
    | w <= 57              = fromIntegral w - 48
    | 65 <= w && w <= 70   = fromIntegral w - 55
    | 97 <= w && w <= 102  = fromIntegral w - 87


-- | Parse and decode an unsigned decimal number.
uint :: Integral a => P.Parser a
{-# INLINE uint #-}
uint = do
    (V.Vec arr s l) <- P.takeWhile1 isDigit
    return $! decLoop arr s (l-1) 0
  where
    decLoop arr !i !j !acc
        | j == 0 = acc*10 + w2iDec (A.indexPrimArray arr i)
        | otherwise =
            let acc' = acc*10 + w2iDec (A.indexPrimArray arr i)
            in decLoop arr (i+1) (j-1) acc'

w2iDec :: (Integral a) => Word8 -> a
{-# INLINE w2iDec #-}
w2iDec w = fromIntegral w - 48

-- | Parse a decimal number with an optional leading @\'+\'@ or @\'-\'@ sign
-- character.
int :: Integral a => P.Parser a
{-# INLINE int #-}
int = do
    w <- P.peek
    if w == minus
        then P.skip 1 >> negate <$> uint
        else if w == plus then P.skip 1 >> uint else uint

-- | Parse a rational number.
--
-- The syntax accepted by this parser is the same as for 'double'.
--
-- /Note/: this parser is not safe for use with inputs from untrusted
-- sources.  An input with a suitably large exponent such as
-- @"1e1000000000"@ will cause a huge 'Integer' to be allocated,
-- resulting in what is effectively a denial-of-service attack.
--
-- In most cases, it is better to use 'double' or 'scientific'
-- instead.
--
rational :: Fractional a => P.Parser a
{-# INLINE rational #-}
rational = scientifically realToFrac

-- | Parse a rational number and round to 'Double'.
--
-- This parser accepts an optional leading sign character, followed by
-- at least one decimal digit.  The syntax similar to that accepted by
-- the 'read' function, with the exception that a trailing @\'.\'@ or
-- @\'e\'@ /not/ followed by a number is not consumed.
--
-- Examples with behaviour identical to 'read':
--
-- >parseOnly double "3"     == Right ("",1,3.0)
-- >parseOnly double "3.1"   == Right ("",3,3.1)
-- >parseOnly double "3e4"   == Right ("",3,30000.0)
-- >parseOnly double "3.1e4" == Right ("",5,31000.0)
--
-- >parseOnly double ".3"    == Left (".3",0,"takeWhile1")
-- >parseOnly double "e3"    == Left ("e3",0,"takeWhile1")
--
-- Examples of differences from 'read':
--
-- >parseOnly double "3.foo" == Right (".foo",1,3.0)
-- >parseOnly double "3e"    == Right ("e",1,3.0)
--
-- This function does not accept string representations of \"NaN\" or
-- \"Infinity\".
--
double :: P.Parser Double
{-# INLINE double #-}
double = scientifically Sci.toRealFloat

-- | Parse a rational number and round to 'Float'.
--
-- Single precision version of 'double'.
float :: P.Parser Float
{-# INLINE float #-}
float = scientifically Sci.toRealFloat

-- | Parse a scientific number.
--
-- The syntax accepted by this parser is the same as for 'double'.
--
scientific :: P.Parser Sci.Scientific
{-# INLINE scientific #-}
scientific = scientifically id

-- | Parse a scientific number and convert to result using a user supply function.
--
-- The syntax accepted by this parser is the same as for 'double'.
--
scientifically :: (Sci.Scientific -> a) -> P.Parser a
{-# INLINE scientifically #-}
scientifically h = do
    sign <- P.peek
    when (sign == plus || sign == minus) (P.skip 1)
    intPart <- uint
    sci <- (do (V.Vec arr s l) <- P.word8 dot >> P.takeWhile1 isDigit
               let intPart' = intPart * (10 ^ l)
                   fracPart = decLoop arr s (l-1) 0
               parseE (intPart' + fracPart) l
           ) <|> (parseE intPart 0)

    if sign /= minus then return $! h sci else return $! h (negate sci)
  where
    {-# INLINE parseE #-}
    parseE c e =
        (do _ <- P.satisfy (\w -> w ==  littleE || w == bigE)
            (Sci.scientific c . (subtract e) <$> int)) <|> return (Sci.scientific c (negate e))

    decLoop arr !i !j !acc
        | j == 0 = acc*10 + w2iDec (A.indexPrimArray arr i)
        | otherwise =
            let acc' = acc*10 + w2iDec (A.indexPrimArray arr i)
            in decLoop arr (i+1) (j-1) acc'