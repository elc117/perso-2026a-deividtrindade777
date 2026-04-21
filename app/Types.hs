{-# LANGUAGE DeriveGeneric    #-}
{-# LANGUAGE DeriveAnyClass   #-}
{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : Types
Description : Modelagem de dados do domínio FocusFlow
Maintainer  : seu.email@exemplo.com

Define os Tipos de Dados Algébricos (ADTs) centrais da aplicação.
Toda a lógica de negócio parte dessas definições imutáveis.
-}
module Types
    ( -- * Tipos exportados
      Categoria (..)
    , Prioridade (..)
    , Tarefa (..)
    , TarefaId
    ) where

import           Data.Aeson       (FromJSON, ToJSON, toJSON, parseJSON,
                                   genericToJSON, genericParseJSON,
                                   defaultOptions, Options(..))
import           Data.Text        (Text)
import           Data.Time        (TimeOfDay, Day)
import           GHC.Generics     (Generic)
import           Data.Char        (toLower)

-- ---------------------------------------------------------------------------
-- | Aliases de tipo para semântica explícita
-- ---------------------------------------------------------------------------

-- | Identificador único de uma tarefa.
-- Usar 'type' (alias) e não 'newtype' aqui é uma escolha consciente para
-- a Sprint 1; nas próximas sprints refatoramos para 'newtype TarefaId Int'
-- a fim de ganhar segurança de tipos em tempo de compilação.
type TarefaId = Int


-- ---------------------------------------------------------------------------
-- | ADT Soma: Categoria
-- ---------------------------------------------------------------------------

{- |
'Categoria' é um tipo soma (sum type), a forma mais pura de ADT.
Cada construtor representa um estado mutuamente exclusivo — o compilador
Haskell garante em tempo de compilação que nenhum valor inválido existe.

Isso substitui com vantagem o uso de strings ou enums de outras linguagens:
não há como criar uma Categoria "Viagem" sem alterar o tipo.
-}
data Categoria
    = Trabalho
    | Estudos
    | Faculdade
    | Lazer
    | Esportes
    deriving (Show, Eq, Ord, Enum, Bounded, Generic)

-- Instâncias JSON manuais para controlar a serialização:
-- { "categoria": "Trabalho" } em vez de uma estrutura aninhada.
instance ToJSON   Categoria
instance FromJSON Categoria


-- ---------------------------------------------------------------------------
-- | ADT Soma: Prioridade
-- ---------------------------------------------------------------------------

{- |
'Prioridade' é outro tipo soma que expressa urgência de uma tarefa.
A ordem dos construtores é relevante pois derivamos 'Ord':
Alta > Media > Baixa é a ordenação natural gerada pelo compilador.

'Bounded' permite iterar sobre todos os valores com [minBound..maxBound].
-}
data Prioridade
    = Baixa
    | Media
    | Alta
    deriving (Show, Eq, Ord, Enum, Bounded, Generic)

instance ToJSON   Prioridade
instance FromJSON Prioridade


-- ---------------------------------------------------------------------------
-- | ADT Produto: Tarefa
-- ---------------------------------------------------------------------------

{- |
'Tarefa' é um tipo produto (product type) — equivalente funcional de uma
struct/record, porém imutável por padrão.

Decisões de modelagem:
  * 'tarefaId'        — Int simples na Sprint 1; será 'newtype' na Sprint 2.
  * 'tarefaTitulo'    — 'Text' (UTF-8 eficiente) em vez de 'String' ([Char]).
  * 'tarefaData'      — 'Day' do módulo 'Data.Time'; representa apenas a data
                         sem fuso horário, adequado para uma agenda local.
  * 'tarefaInicio'    — 'TimeOfDay' representa HH:MM:SS, preciso e sem ambiguidade.
  * 'tarefaDuracao'   — Duração em minutos como 'Int'. Alternativa seria 'NominalDiffTime',
                         mas 'Int' é mais legível no JSON e suficiente para o domínio.
  * 'tarefaDescricao' — 'Maybe Text': campo opcional expresso no tipo.
                         O compilador nos obriga a tratar a ausência explicitamente.
-}
data Tarefa = Tarefa
    { tarefaId        :: TarefaId
    , tarefaTitulo    :: Text
    , tarefaCategoria :: Categoria
    , tarefaPrioridade:: Prioridade
    , tarefaData      :: Day
    , tarefaInicio    :: TimeOfDay
    , tarefaDuracao   :: Int          -- ^ Duração em minutos (> 0)
    , tarefaDescricao :: Maybe Text   -- ^ Descrição opcional da tarefa
    } deriving (Show, Eq, Generic)

-- Customizamos a serialização JSON para remover o prefixo "tarefa"
-- dos nomes dos campos, gerando um JSON idiomático:
-- { "id": 1, "titulo": "...", "categoria": "Trabalho", ... }
tarefaJsonOptions :: Options
tarefaJsonOptions = defaultOptions
    { fieldLabelModifier = drop (length ("tarefa" :: String))
                         . toLowerFirst
    }
  where
    toLowerFirst []     = []
    toLowerFirst (c:cs) = toLower c : cs
    toLower c
        | c >= 'A' && c <= 'Z' = toEnum (fromEnum c + 32)
        | otherwise             = c

instance ToJSON   Tarefa where
    toJSON = genericToJSON tarefaJsonOptions

instance FromJSON Tarefa where
    parseJSON = genericParseJSON tarefaJsonOptions