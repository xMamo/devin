module Type.Common (
  Type (..),
  Environment (..),
  Pass (..),
  Error (..),
  description,
  span,
  start,
  end
) where

import Prelude hiding (span)

import Data.Text (Text)
import qualified Data.Text as Text

import Span (Span)
import qualified Syntax


data Type where
  Unit :: Type
  Bool :: Type
  Int :: Type
  Float :: Type
  Function :: [Type] -> Type -> Type
  Unknown :: Text -> Type
  Error :: Type
  deriving (Eq, Show, Read)


data Environment where
  Environment :: [(Text, Type)] -> [(Text, Type, Bool)] -> [[(Text, [Type], Type)]] -> Environment
  deriving (Eq, Show, Read)


data Pass where
  Pass1 :: Pass
  Pass2 :: Pass
  deriving (Eq, Ord, Enum, Bounded, Show, Read)


data Error where
  UnknownTypeError :: Syntax.Identifier -> Error
  UnknownIdentifierError :: Syntax.Identifier -> Error
  UnknownFunctionError :: Syntax.Identifier -> [Type] -> Error
  DuplicateFunctionDefinition :: Syntax.Identifier -> [Type] -> Error
  UninitializedVariableError :: Syntax.Identifier -> Error
  InvalidUnaryError :: Syntax.UnaryOperator -> Type -> Error
  InvalidBinaryError :: Syntax.BinaryOperator -> Type -> Type -> Error
  InvalidAssignError :: Syntax.AssignOperator -> Type -> Type -> Error
  InvalidTypeError :: Syntax.Expression () -> Type -> Type -> Error
  InvalidReturnTypeError :: Syntax.Statement () -> Type -> Type -> Error
  MissingReturnValueError :: Syntax.Statement () -> Type -> Error
  MissingReturnPathError :: Syntax.Identifier -> [Type] -> Error
  deriving (Eq, Show, Read)


description :: Error -> Text
description = \case
  UnknownTypeError (Syntax.Identifier _ name) -> "Unknown type " <> name

  UnknownIdentifierError (Syntax.Identifier _ name) -> "Unknown identifier " <> name

  UnknownFunctionError (Syntax.Identifier _ name) parameterTypes ->
    "Unknown function " <> name <> "(" <> labels parameterTypes <> ")"

  DuplicateFunctionDefinition (Syntax.Identifier _ name) parameterTypes ->
    "Function " <> name <> "(" <> labels parameterTypes <> ") already defined"

  UninitializedVariableError (Syntax.Identifier _ name) -> "Uninitialized variable " <> name

  InvalidUnaryError unary operandType -> "Can’t apply unary " <> operator <> " to " <> label operandType
    where
      operator = case unary of
        Syntax.PlusOperator _ -> "+"
        Syntax.MinusOperator _ -> "-"
        Syntax.NotOperator _ -> "not"

  InvalidBinaryError binary leftType rightType ->
    "Can’t apply binary " <> operator <> " between " <> label leftType <> " and " <> label rightType
    where
      operator = case binary of
        Syntax.AddOperator _ -> "+"
        Syntax.SubtractOperator _ -> "-"
        Syntax.MultiplyOperator _ -> "*"
        Syntax.DivideOperator _ -> "/"
        Syntax.RemainderOperator _ -> "%"
        Syntax.EqualOperator _ -> "=="
        Syntax.NotEqualOperator _ -> "!="
        Syntax.LessOperator _ -> "<"
        Syntax.LessOrEqualOperator _ -> "<="
        Syntax.GreaterOperator _ -> ">"
        Syntax.GreaterOrEqualOperator _ -> ">="
        Syntax.AndOperator _ -> "and"
        Syntax.OrOperator _ -> "or"

  InvalidAssignError assign targetType valueType ->
    "Can’t apply assign " <> operator <> " to " <> label targetType <> " and " <> label valueType
    where
      operator = case assign of
        Syntax.AssignOperator _ -> "="
        Syntax.AddAssignOperator _ -> "+="
        Syntax.SubtractAssignOperator _ -> "-="
        Syntax.MultiplyAssignOperator _ -> "*="
        Syntax.DivideAssignOperator _ -> "/="
        Syntax.RemainderAssignOperator _ -> "%="

  InvalidTypeError _ expectedType actualType ->
    "Invalid type: expected " <> label expectedType <> ", but got " <> label actualType

  InvalidReturnTypeError _ expectedType actualType ->
    "Invalid return type: expected " <> label expectedType <> ", but got " <> label actualType

  MissingReturnValueError _ expectedType -> "Missing return value: expected " <> label expectedType

  MissingReturnPathError (Syntax.Identifier _ name) parameterTypes ->
    name <> "(" <> labels parameterTypes <> "): not all code paths return a value"

  where
    label Unit = "Unit"
    label Bool = "Bool"
    label Int = "Int"
    label Float = "Float"
    label (Function parameterTypes returnType) = "(" <> labels parameterTypes <> ") -> " <> label returnType
    label (Unknown name) = name
    label Error = "⊥"

    labels types = Text.intercalate ", " (label <$> types)


span :: Error -> Span
span (UnknownTypeError typeId) = Syntax.span typeId
span (UnknownIdentifierError name) = Syntax.span name
span (UnknownFunctionError name _) = Syntax.span name
span (DuplicateFunctionDefinition name _) = Syntax.span name
span (UninitializedVariableError variable) = Syntax.span variable
span (InvalidUnaryError unary _) = Syntax.span unary
span (InvalidBinaryError binary _ _) = Syntax.span binary
span (InvalidAssignError assign _ _) = Syntax.span assign
span (InvalidTypeError expression _ _) = Syntax.span expression
span (InvalidReturnTypeError statement _ _) = Syntax.span statement
span (MissingReturnValueError statement _) = Syntax.span statement
span (MissingReturnPathError name _) = Syntax.span name


start :: Integral a => Error -> a
start (UnknownTypeError typeId) = Syntax.start typeId
start (UnknownIdentifierError name) = Syntax.start name
start (UnknownFunctionError name _) = Syntax.start name
start (DuplicateFunctionDefinition name _) = Syntax.start name
start (UninitializedVariableError variable) = Syntax.start variable
start (InvalidUnaryError unary _) = Syntax.start unary
start (InvalidBinaryError binary _ _) = Syntax.start binary
start (InvalidAssignError assign _ _) = Syntax.start assign
start (InvalidTypeError expression _ _) = Syntax.start expression
start (InvalidReturnTypeError statement _ _) = Syntax.start statement
start (MissingReturnValueError statement _) = Syntax.start statement
start (MissingReturnPathError name _) = Syntax.start name


end :: Integral a => Error -> a
end (UnknownTypeError typeId) = Syntax.end typeId
end (UnknownIdentifierError name) = Syntax.end name
end (UnknownFunctionError name _) = Syntax.end name
end (DuplicateFunctionDefinition name _) = Syntax.end name
end (UninitializedVariableError variable) = Syntax.end variable
end (InvalidUnaryError unary _) = Syntax.end unary
end (InvalidBinaryError binary _ _) = Syntax.end binary
end (InvalidAssignError assign _ _) = Syntax.end assign
end (InvalidTypeError expression _ _) = Syntax.end expression
end (InvalidReturnTypeError statement _ _) = Syntax.end statement
end (MissingReturnValueError statement _) = Syntax.end statement
end (MissingReturnPathError name _) = Syntax.end name
