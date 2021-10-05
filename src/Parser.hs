module Parser (
  Parser,
  ParserT (..),
  run,
  position,
  satisfy,
  char,
  text,
  either,
  separatedBy,
  separatedBy1,
  label,
  commit,
  eoi
) where

import Prelude hiding (either)
import Control.Applicative
import Control.Monad
import Data.Functor
import Data.Functor.Identity
import Data.List

import Data.Text (Text)
import qualified Data.Text as Text

import Control.Monad.Trans.Class

import Parser.Input (Input (Input))
import Parser.Result (Result)
import qualified Parser.Result as Result


type Parser = ParserT Identity


newtype ParserT m a = ParserT {runT :: Input -> m (Result a)}
  deriving Functor


instance (Monad m, Semigroup a) => Semigroup (ParserT m a) where
  parser1 <> parser2 = liftA2 (<>) parser1 parser2


instance (Monad m, Monoid a) => Monoid (ParserT m a) where
  mempty = pure mempty


instance Monad m => Applicative (ParserT m) where
  pure value = ParserT (pure . Result.Success value)

  parser1 <*> parser2 = ParserT $ runT parser1 >=> \case
    Result.Success f rest -> fmap f <$> runT parser2 rest
    Result.Failure isFatal position expectations -> pure (Result.Failure isFatal position expectations)


instance Monad m => Monad (ParserT m) where
  parser >>= f = ParserT $ runT parser >=> \case
    Result.Success value rest -> runT (f value) rest
    Result.Failure isFatal position expectations -> pure (Result.Failure isFatal position expectations)


instance MonadFail m => MonadFail (ParserT m) where
  fail string = ParserT (const (fail string))


instance Monad m => MonadPlus (ParserT m)


instance Monad m => Alternative (ParserT m) where
  empty = ParserT \(Input position _) -> pure (Result.Failure False position [])

  parser1 <|> parser2 = ParserT \input -> runT parser1 input >>= \case
    Result.Success value rest -> pure (Result.Success value rest)

    Result.Failure True position expectations -> pure (Result.Failure True position expectations)

    Result.Failure False position1 expectations1 -> runT parser2 input <&> \case
      Result.Success value rest -> Result.Success value rest

      Result.Failure isFatal2 position2 expectations2 -> case compare position1 position2 of
        LT | null expectations2 && not (null expectations1) -> Result.Failure isFatal2 position1 expectations1
        LT -> Result.Failure isFatal2 position2 expectations2
        EQ -> Result.Failure isFatal2 position1 (expectations1 `union` expectations2)
        GT | null expectations1 && not (null expectations2) -> Result.Failure isFatal2 position2 expectations2
        GT -> Result.Failure isFatal2 position1 expectations1


instance MonadTrans ParserT where
  lift ma = ParserT \input -> ma <&> \a -> Result.Success a input


run :: Parser a -> Input -> Result a
run parser = runIdentity . runT parser


position :: Applicative m => Integral a => ParserT m a
position = ParserT \input@(Input position _) -> pure (Result.Success (fromIntegral position) input)


satisfy :: Applicative m => (Char -> Bool) -> ParserT m Char
satisfy f = ParserT \(Input position rest) -> case Text.uncons rest of
  Just (head, tail) | f head -> pure (Result.Success head (Input (position + 1) tail))
  _ -> pure (Result.Failure False position [])


char :: Applicative m => Char -> ParserT m Char
char c = ParserT \(Input position rest) -> case Text.stripPrefix (Text.singleton c) rest of
  Just suffix -> pure (Result.Success c (Input (position + 1) suffix))
  Nothing -> pure (Result.Failure False position [Text.pack (show c)])


text :: Applicative m => Text -> ParserT m Text
text t = ParserT \(Input position rest) -> pure case Text.stripPrefix t rest of
  Just suffix -> Result.Success t (Input (position + Text.length t) suffix)
  Nothing -> Result.Failure False position [Text.pack (show t)]


either :: Monad m => ParserT m a -> ParserT m b -> ParserT m (Either a b)
either parser1 parser2 = fmap Left parser1 <|> fmap Right parser2


separatedBy :: Monad m => ParserT m a -> ParserT m b -> ParserT m [a]
separatedBy parser separator = separatedBy1 parser separator <|> pure []


separatedBy1 :: Monad m => ParserT m a -> ParserT m b -> ParserT m [a]
separatedBy1 parser separator = liftA2 (:) parser (many (separator *> parser))


label :: Monad m => Text -> ParserT m a -> ParserT m a
label l parser = ParserT \input@(Input position _) -> runT parser input <&> \case
  Result.Success value rest -> Result.Success value rest
  Result.Failure isFatal _ _ -> Result.Failure isFatal position [l]


commit :: Monad m => ParserT m a -> ParserT m a
commit parser = ParserT \input -> runT parser input <&> \case
  Result.Success value rest -> Result.Success value rest
  Result.Failure _ position expectations -> Result.Failure True position expectations


eoi :: Applicative m => ParserT m ()
eoi = ParserT \input@(Input position text) ->
  pure if Text.null text then
    Result.Success () input
  else
    Result.Failure False position ["end of input"]
