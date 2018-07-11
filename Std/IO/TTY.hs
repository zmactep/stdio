{-# LANGUAGE MagicHash #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ExistentialQuantification #-}

{-|
Module      : Std.IO.TTY
Description : TTY devices
Copyright   : (c) Winterland, 2018
License     : BSD
Maintainer  : drkoster@qq.com
Stability   : experimental
Portability : non-portable

This module provides an API for opening tty as 'UVStream'. In most case, it will not be necessary to use this module directly

-}

module Std.IO.TTY(
    UVStream
  , stdin
  , stdout
  , stderr
  ) where

import           Std.IO.Exception
import           Std.IO.Resource
import           Std.IO.UV.FFI
import           Std.IO.UV.Manager
import           System.IO.Unsafe

initTTYStream :: HasCallStack => UVFD -> UVManager -> Resource UVStream
initTTYStream fd = initUVStream (\ loop handle ->
    throwUVIfMinus_ (uv_tty_init loop handle (fromIntegral fd)))

stdin :: UVStream
{-# NOINLINE stdin #-}
stdin = unsafePerformIO $ do
    uvm <- getUVManager
    (stdin, _ ) <- acquire (initTTYStream 0 uvm)    -- well, stdin live across whole program
    return stdin                                    -- so we give up resource management

stdout :: UVStream
{-# NOINLINE stdout #-}
stdout = unsafePerformIO $ do
    uvm <- getUVManager
    (stdin, _ ) <- acquire (initTTYStream 1 uvm)
    return stdin

stderr :: UVStream
{-# NOINLINE stderr #-}
stderr = unsafePerformIO $ do
    uvm <- getUVManager
    (stdin, _ ) <- acquire (initTTYStream 2 uvm)
    return stdin