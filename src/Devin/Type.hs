module Devin.Type (Type (..)) where

import Data.Data

import Devin.Display


data Type
  = Unknown
  | Unit
  | Bool
  | Int
  | Float
  | Array Type
  | Function [Type] Type
  | Placeholder String
  deriving (Show, Read, Data)


instance Eq Type where
  (==) :: Type -> Type -> Bool
  Unknown == _ = True
  _ == Unknown = True
  Unit == Unit = True
  Bool == Bool = True
  Int == Int = True
  Float == Float = True
  Array t1 == Array t2 = t1 == t2
  Function ts1 t1 == Function t2 r2 = (ts1, t1) == (t2, r2)
  Placeholder name1 == Placeholder name2 = name1 == name2
  _ == _ = False


instance Display Type where
  displays :: Type -> ShowS
  displays Unknown = showChar '?'
  displays Unit = showString "Unit"
  displays Bool = showString "Bool"
  displays Int = showString "Int"
  displays Float = showString "Float"
  displays (Array t) = showChar '[' . displays t . showChar ']'
  displays (Placeholder name) = showString name

  displays (Function [] returnType) =
    showString "() → " . displays returnType

  displays (Function (parameterT : parameterTs) returnType) =
    showChar '(' . displays parameterT . go parameterTs
      where
        go [] = showString ") → " . displays returnType
        go (parameterT : parameterTs) = showString ", " . displays parameterT . go parameterTs