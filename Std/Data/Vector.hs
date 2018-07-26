{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE MagicHash #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE CApiFFI #-}
{-# LANGUAGE ViewPatterns #-}
{-# LANGUAGE UnliftedFFITypes #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE QuasiQuotes #-}

{-|
Module      : Std.Data.Vector
Description : Fast boxed and unboxed vector
Copyright   : (c) Winterland, 2017-2018
License     : BSD
Maintainer  : drkoster@qq.com
Stability   : experimental
Portability : non-portable

This module provide fast boxed and unboxed vector with unified interface. Conceptually a vector is simply a slice of an array, for example this is the definition of boxed vector:

@
    data Vector a = Vector
        {-# UNPACK #-} !(SmallArray a) -- payload
        {-# UNPACK #-} !Int         -- offset
        {-# UNPACK #-} !Int         -- length
@

The 'Vec' class unified different type of vectors, and this module provide operation over 'Vec' instances. The API is similar to bytestring and vector. If you find missing functions, please report!

Performance consideration:

  * Use 'PrimVector' for 'Prim' types, it stores content in packed memory, and it's
    strict on its elements (following strictness consideration are mainly for lifted
    'Vector' type), many functions DO NOT NEED the result vectors's type to be same
    with the source one, e.g. @map :: (Vec v a, Vec u b) => (a -> b) -> v a -> u b@.

  * There're some specialized function which only works on 'Bytes', which is enabled
    with rewrite rules, if you want to use specialized versions directly, import
    'Std.Data.Vector.Base' and 'Std.Data.Vector.Extra' module. Doing so will also
    enable vector internals, which is useful for working on the underlying arrays.

  * The 'Functor' instance for 'Vector' are lazy in order to abid 'Functor' law.
    namely @fmap id vectorConatinBottom == vectorContainBottom@, if you need strict mapping
    for lifted 'Vector', use 'map' ('PrimVector' will never contain bottom thus it's not
    a problem). THIS MAY COME AS A SURPRISE SO MAKE SURE YOU USE THE CORRECT 'map' s.

  * The 'Foldable' instance for 'Vector' is fine, use 'Prelude' functions such as
    'null', 'length', etc. should not incur performance overhead.

  * The 'Traversable' instance have specialized implementations for 'ST' and 'IO',
    if you don't write thunks into result, use @return <$!>@ idiom.

  * When use stateful generating functions like 'mapAccumL', 'mapAccumR' ,etc. force
    both the accumulator and value with @acc `seq` v `seq` (acc, v)@ idiom to avoid
    thunks inside result vector.

  * The 'unpack', 'unpackR' and 'pack', 'packN', 'packR', 'packRN' are designed to
    work with @build/foldr@ streaming fusion in base, thus it's OK to expect idioms like

        > pack . List filter f . List.map . unpack

        to work in contant space. While

        > Vector.filter . Vector.map

        will create intermediate vectors on the fly, which have different time/space characteristic.

-}

module Std.Data.Vector (
  -- * The Vec typeclass
    Vec
  -- * Boxed and unboxed vector type
  , Vector
  , PrimVector
  -- ** Word8 vector
  , Bytes
  -- * Basic creating
  , empty, singleton, copy
  -- * Conversion between list
  , pack, packN, packR, packRN
  , unpack, unpackR
  -- * Basic interface
  , null
  , length
  , append
  , map, map', imap'
  , foldl', ifoldl', foldl1'
  , foldr', ifoldr', foldr1'
    -- ** Special folds
  , concat, concatMap
  , maximum, minimum
  , sum
  , count
  , product, product'
  , all, any
  -- * Building vector
  -- ** Accumulating maps
  , mapAccumL
  , mapAccumR
  -- ** Generating and unfolding vector
  , replicate
  , unfoldr
  , unfoldrN
  -- * Searching by equality
  , elem, notElem, elemIndex
  -- * Slice manipulation
  , cons, snoc
  , uncons, unsnoc
  , headM, tailE
  , lastM, initE
  , inits, tails
  , take, drop
  , slice , (|..|)
  , splitAt
  , takeWhile , dropWhile
  , break, span
  , breakEnd, spanEnd
  , group, groupBy
  , stripPrefix, stripSuffix
  , split, splitWith
  , isPrefixOf, isSuffixOf, isInfixOf
  -- * Transform
  , reverse
  , intersperse
  , intercalate
  , intercalateElem
  , transpose
  -- * Zipping
  , zipWith', unzipWith'
  -- * Scans
  , scanl', scanl1'
  , scanr', scanr1'
  -- * Search
  -- ** element-wise search
  , findIndices, elemIndices
  , find, findIndexOrEnd
  , findIndexReverseOrStart
  , filter, partition
  -- ** sub-vector search
  , indicesOverlapping
  , indices
  -- * QuasiQuoters
  , ascii
  , vecW8, vecW16, vecW32, vecW64, vecWord
  , vecI8, vecI16, vecI32, vecI64, vecInt
  -- * Misc
  , IPair(..)
  , VectorException(..)
 ) where

import           Prelude ()
import           Std.Data.Vector.Base
import           Std.Data.Vector.Extra
