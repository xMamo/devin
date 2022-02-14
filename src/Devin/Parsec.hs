{-# LANGUAGE ApplicativeDo #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE UndecidableInstances #-}
{-# OPTIONS_GHC -Wno-orphans #-}

module Devin.Parsec (
  module Text.Parsec,
  module Text.Parsec.Pos,
  getOffset,
  toOffset,
  toOffsetT
) where

import Data.Functor.Identity

import Text.Parsec
import Text.Parsec.Pos


instance (Num a, Stream s m t) => Stream (a, s) m t where
  uncons :: (a, s) -> m (Maybe (t, (a, s)))
  uncons (offset, stream) = uncons stream >>= \case
    Just (token, rest) -> pure (Just (token, (offset + 1, rest)))
    Nothing -> pure Nothing


getOffset :: Monad m => ParsecT (a, s) u m a
getOffset = do
  State {stateInput = (offset, _)} <- getParserState
  pure offset


toOffset :: (Num a, Stream s Identity Char) => SourcePos -> s -> a
toOffset sourcePos stream = runIdentity (toOffsetT sourcePos stream)


toOffsetT :: (Num a, Stream s m Char) => SourcePos -> s -> m a
toOffsetT sourcePos stream = go 0 (initialPos "") stream
  where
    go offset sourcePos' _ | sourcePos' >= sourcePos = pure offset

    go offset sourcePos' stream = uncons stream >>= \case
      Just (c, rest) -> go (offset + 1) (updatePosChar sourcePos' c) rest
      Nothing -> pure offset