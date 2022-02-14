{-# LANGUAGE ApplicativeDo #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE DisambiguateRecordFields #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE UndecidableInstances #-}

module Devin.Parsers (
  ParserT,
  Parser,
  devin,
  declaration,
  statement,
  expression,
  unaryOperator,
  binaryOperator,
  symbolId,
  typeId,
  comment
) where

import Control.Applicative hiding ((<|>), many)
import Control.Monad
import Data.Char
import Data.Functor

import Devin.Parsec hiding (token)

#if __GLASGOW_HASKELL__ >= 902
import Devin.Syntax
#else
import Devin.Syntax hiding (declaration)
#endif


type ParserT s m a = ParsecT (Int, s) [Token] m a
type Parser s a = Parsec (Int, s) [Token] a


devin :: Stream s m Char => ParserT s m Devin
devin = syntax $ do
  declarations <- s *> many (declaration <* s) <* eof
  pure (Devin declarations)


declaration :: Stream s m Char => ParserT s m Declaration
declaration = variableDeclaration <|> functionDeclaration


variableDeclaration :: Stream s m Char => ParserT s m Declaration
variableDeclaration = do
  varKeyword <- keyword "var"
  variableId <- s *> symbolId
  equalSign <- s *> token "="
  value <- s *> expression
  semicolon <- s *> token ";"
  pure (VariableDeclaration varKeyword variableId equalSign value semicolon)


functionDeclaration :: Stream s m Char => ParserT s m Declaration
functionDeclaration = do
  defKeyword <- keyword "def"
  functionId <- s *> symbolId
  open <- s *> token "("

  (parameters, commas) <- s *> optionMaybe parameter >>= \case
    Nothing -> pure ([], [])

    Just first -> do
      rest <- many (liftA2 (,) (try (s *> token ",")) (s *> parameter))
      pure (first : map snd rest, map fst rest)

  close <- s *> token ")"

  returnInfo <- s *> optionMaybe (token "->") >>= \case
    Nothing -> pure Nothing

    Just arrow -> do
      returnTypeId <- s *> typeId
      pure (Just (arrow, returnTypeId))

  body <- s *> statement
  pure (FunctionDeclaration defKeyword functionId open parameters commas close returnInfo body)

  where
    parameter = do
      (refKeyword, parameterId) <- choice
        [
          try $ do
            token <- keyword "ref"
            parameterId <- s *> symbolId
            pure (Just token, parameterId),

          do
            parameterId <- symbolId
            pure (Nothing, parameterId)
        ]

      parameterInfo <- optionMaybe (try (s *> token ":")) >>= \case
        Nothing -> pure Nothing

        Just colon -> do
          parameterTypeId <- s *> typeId
          pure (Just (colon, parameterTypeId))

      pure (refKeyword, parameterId, parameterInfo)


statement :: Stream s m Char => ParserT s m Statement
statement = choice
  [
    declarationStatement,
    ifStatement,
    whileStatement,
    doWhileStatement,
    assertStatement,
    returnStatement,
    blockStatement,
    expressionStatement
  ]


expressionStatement :: Stream s m Char => ParserT s m Statement
expressionStatement = do
  value <- expression
  semicolon <- s *> token ";"
  pure (ExpressionStatement value semicolon)


declarationStatement :: Stream s m Char => ParserT s m Statement
declarationStatement = DeclarationStatement <$> declaration


ifStatement :: Stream s m Char => ParserT s m Statement
ifStatement = do
  ifKeyword <- keyword "if"
  predicate <- s *> expression
  trueBranch <- s *> statement

  optionMaybe (try (s *> keyword "else")) >>= \case
    Nothing -> pure (IfStatement ifKeyword predicate trueBranch)

    Just elseKeyword -> do
      falseBranch <- s *> statement
      pure (IfElseStatement ifKeyword predicate trueBranch elseKeyword falseBranch)


whileStatement :: Stream s m Char => ParserT s m Statement
whileStatement = do
  whileKeyword <- keyword "while"
  predicate <- s *> expression
  body <- s *> statement
  pure (WhileStatement whileKeyword predicate body)


doWhileStatement :: Stream s m Char => ParserT s m Statement
doWhileStatement = do
  doKeyword <- keyword "do"
  body <- s *> statement
  whileKeyword <- s *> keyword "while"
  predicate <- s *> expression
  semicolon <- s *> token ";"
  pure (DoWhileStatement doKeyword body whileKeyword predicate semicolon)


returnStatement :: Stream s m Char => ParserT s m Statement
returnStatement = do
  returnKeyword <- keyword "return"
  result <- s *> optionMaybe expression
  semicolon <- s *> token ";"
  pure (ReturnStatement returnKeyword result semicolon)


assertStatement :: Stream s m Char => ParserT s m Statement
assertStatement = do
  assertKeyword <- keyword "assert"
  predicate <- s *> expression
  semicolon <- s *> token ";"
  pure (AssertStatement assertKeyword predicate semicolon)


blockStatement :: Stream s m Char => ParserT s m Statement
blockStatement = do
  open <- token "{"
  statements <- s *> many (statement <* s)
  close <- token "}"
  pure (BlockStatement open statements close)


expression :: Stream s m Char => ParserT s m Expression
expression = expression1


expression1 :: Stream s m Char => ParserT s m Expression
expression1 = chainl1 expression2 $ do
  binary <- try $ between s s $ syntax $ choice
    [
      keyword "and" $> AndOperator,
      keyword "or" $> OrOperator,
      keyword "xor" $> XorOperator
    ]

  pure (\left right -> BinaryExpression left binary right)


expression2 :: Stream s m Char => ParserT s m Expression
expression2 = chainl1 expression3 $ do
  binary <- try $ between s s $ syntax $ choice
    [
      text "==" $> EqualOperator,
      text "!=" $> NotEqualOperator
    ]

  pure (\left right -> BinaryExpression left binary right)


expression3 :: Stream s m Char => ParserT s m Expression
expression3 = chainl1 expression4 $ do
  binary <- try $ between s s $ syntax $ choice
    [
      text ">=" $> GreaterOrEqualOperator,
      text ">" $> GreaterOperator,
      text "<=" $> LessOrEqualOperator,
      text "<" $> LessOperator
    ]

  pure (\left right -> BinaryExpression left binary right)


expression4 :: Stream s m Char => ParserT s m Expression
expression4 = chainl1 expression5 $ do
  binary <- try $ between s s $ syntax $ choice
    [
      text "+" $> AddOperator,
      text "-" $> SubtractOperator
    ]

  pure (\left right -> BinaryExpression left binary right)


expression5 :: Stream s m Char => ParserT s m Expression
expression5 = chainl1 expression6 $ do
  binary <- try $ between s s $ syntax $ choice
    [
      text "*" $> MultiplyOperator,
      text "/" $> DivideOperator,
      text "%" $> ModuloOperator
    ]

  pure (\left right -> BinaryExpression left binary right)


expression6 :: Stream s m Char => ParserT s m Expression
expression6 = do
  term <- choice
    [
      rationalExpression,
      integerExpression,
      arrayExpression,
      unaryExpression,
      callOrVariableExpression,
      parenthesizedExpression
    ]

  left <- go term

  optionMaybe (try (s *> assignOperator)) >>= \case
    Nothing -> pure left

    Just binary -> do
      right <- s *> expression
      pure (BinaryExpression left binary right)

  where
    go term = optionMaybe (try (s *> token "[")) >>= \case
      Nothing -> pure term

      Just open -> do
        index <- s *> expression
        close <- s *> token "]"
        go (AccessExpression term open index close)

    assignOperator = syntax $ choice
      [
        (try (char '=' <* notFollowedBy (char '=')) <?> "“=”") $> PlainAssignOperator,
        text "+=" $> AddAssignOperator,
        text "-=" $> SubtractAssignOperator,
        text "*=" $> MultiplyAssignOperator,
        text "/=" $> DivideAssignOperator,
        text "%=" $> ModuloAssignOperator
      ]


integerExpression :: Stream s m Char => ParserT s m Expression
integerExpression = flip label "number" $ try $ syntax $ do
  sign <- (char '+' $> 1) <|> (char '-' $> -1) <|> pure 1
  digits <- many1 (satisfy isDigit)
  let magnitude = foldl (\a d -> 10 * a + toInteger (digitToInt d)) 0 digits
  parserReturn (IntegerExpression (sign * magnitude))


rationalExpression :: Stream s m Char => ParserT s m Expression
rationalExpression = flip label "number" $ try $ syntax $ do
  sign <- (char '+' $> 1) <|> (char '-' $> -1) <|> parserReturn 1
  digits1 <- many1 (satisfy isDigit)
  digits2 <- char '.' *> many1 (satisfy isDigit)
  let digits = digits1 ++ digits2
  let mantissa = foldl (\a d -> 10 * a + toRational (digitToInt d)) 0 digits
  pure (RationalExpression (sign * mantissa * 0.1 ^^ length digits2))


arrayExpression :: Stream s m Char => ParserT s m Expression
arrayExpression = do
  open <- token "["

  (elements, commas) <- s *> optionMaybe expression >>= \case
    Nothing -> pure ([], [])

    Just first -> do
      rest <- many (liftA2 (,) (try (s *> token ",")) (s *> expression))
      pure (first : map snd rest, map fst rest)

  close <- s *> token "]"
  pure (ArrayExpression open elements commas close)


callOrVariableExpression :: Stream s m Char => ParserT s m Expression
callOrVariableExpression = do
  SymbolId {name, interval} <- symbolId

  optionMaybe (try (s *> token "(")) >>= \case
    Nothing -> pure (VariableExpression name interval)

    Just open -> do
      (arguments, commas) <- s *> optionMaybe expression >>= \case
        Nothing -> pure ([], [])

        Just first -> do
          rest <- many (liftA2 (,) (try (s *> token ",")) (s *> expression))
          pure (first : map snd rest, map fst rest)

      close <- s *> token ")"
      pure (CallExpression (SymbolId name interval) open arguments commas close)


unaryExpression :: Stream s m Char => ParserT s m Expression
unaryExpression = do
  unary <- unaryOperator
  operand <- s *> expression6
  pure (UnaryExpression unary operand)


parenthesizedExpression :: Stream s m Char => ParserT s m Expression
parenthesizedExpression = do
  open <- token "("
  inner <- s *> expression
  close <- s *> token ")"
  pure (ParenthesizedExpression open inner close)


unaryOperator :: Stream s m Char => ParserT s m UnaryOperator
unaryOperator = syntax $ choice
  [
    text "+" $> PlusOperator,
    text "-" $> MinusOperator,
    keyword "not" $> NotOperator,
    keyword "len" $> LenOperator
  ]


binaryOperator :: Stream s m Char => ParserT s m BinaryOperator
binaryOperator = syntax $ choice
  [
    text "+=" $> AddAssignOperator,
    text "-=" $> SubtractAssignOperator,
    text "*=" $> MultiplyAssignOperator,
    text "/=" $> DivideAssignOperator,
    text "%=" $> ModuloAssignOperator,
    (try (char '=' <* notFollowedBy (char '=')) <?> "“=”") $> PlainAssignOperator,
    text "*" $> MultiplyOperator,
    text "/" $> DivideOperator,
    text "%" $> ModuloOperator,
    text "+" $> AddOperator,
    text "-" $> SubtractOperator,
    text ">=" $> GreaterOrEqualOperator,
    text ">" $> GreaterOperator,
    text "<=" $> LessOrEqualOperator,
    text "<" $> LessOperator,
    text "==" $> EqualOperator,
    text "!=" $> NotEqualOperator,
    keyword "and" $> AndOperator,
    keyword "or" $> OrOperator,
    keyword "xor" $> XorOperator
  ]


symbolId :: Stream s m Char => ParserT s m SymbolId
symbolId = syntax $ do
  name <- identifier
  pure (SymbolId name)


typeId :: Stream s m Char => ParserT s m TypeId
typeId = choice
  [
    syntax $ do
      name <- identifier
      pure (PlainTypeId name),

    do
      open <- token "["
      innerTypeId <- s *> typeId
      close <- s *> token "]"
      pure (ArrayTypeId open innerTypeId close)
  ]


comment :: Stream s m Char => ParserT s m Token
comment = flip label "comment" $ do
  token <- syntax $ do
    text "//"
    skipMany (noneOf ['\n', '\v', '\r', '\x85', '\x2028', '\x2029'])
    pure Token

  modifyState (++ [token])
  pure token


syntax :: Stream s m Char => ParserT s m ((Int, Int) -> a) -> ParserT s m a
syntax mf = do
  start <- getOffset
  f <- mf
  end <- getOffset
  pure (f (start, end))


keyword :: Stream s m Char => String -> ParserT s m Token
keyword literal = flip label ("keyword “" ++ literal ++ "”") $ try $ syntax $ do
  name <- identifier
  guard (name == literal)
  pure Token


token :: Stream s m Char => String -> ParserT s m Token
token literal = syntax $ do
  text literal
  pure Token


text :: Stream s m Char => String -> ParserT s m String
text literal = try (string literal) <?> "“" ++ literal ++ "”"


-- [\p{L}\p{Nl}\p{Pc}][\p{L}\p{Nl}\p{Pc}\p{Mn}\p{Mc}\p{Nd}]*
identifier :: Stream s m Char => ParserT s m String
identifier = flip label "identifier" $ do
  start <- satisfy (isStart . generalCategory)
  continue <- many (satisfy (isContinue . generalCategory))
  pure (start : continue)

  where
    isStart UppercaseLetter = True
    isStart LowercaseLetter = True
    isStart TitlecaseLetter = True
    isStart ModifierLetter = True
    isStart OtherLetter = True
    isStart LetterNumber = True
    isStart ConnectorPunctuation = True
    isStart _ = False

    isContinue NonSpacingMark = True
    isContinue SpacingCombiningMark = True
    isContinue DecimalNumber = True
    isContinue category = isStart category


s :: Stream s m Char => ParserT s m ()
s = skipMany (skipMany1 (space <?> "") <|> void (comment <?> ""))