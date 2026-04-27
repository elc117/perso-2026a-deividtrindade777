{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric     #-}

module Main (main) where

import           Control.Monad.IO.Class (liftIO)
import           Database.SQLite.Simple (Connection)
import           Data.Aeson             (ToJSON, object, (.=))
import           Data.Text.Lazy         (Text)
import           Data.Time              (fromGregorian, TimeOfDay (..))
import           GHC.Generics           (Generic)
import           Network.HTTP.Types     (status201, status409)
import           Web.Scotty

import           Database (inicializarDB, listarTarefas, inserirTarefa)
import           Logic    (temConflito, conflitosEm)
import           Types    (Tarefa (..), Categoria (..), Prioridade (..))

-- Envelopes de resposta
data ErroResponse = ErroResponse
    { mensagem :: Text
    , codigo   :: Text
    } deriving (Show, Generic)

instance ToJSON ErroResponse

data SucessoResponse a = SucessoResponse
    { dados :: a
    } deriving (Show, Generic)

instance ToJSON a => ToJSON (SucessoResponse a)

-- GET /api/status
rotaStatus :: ActionM ()
rotaStatus = json $ object
    [ "status"  .= ("ok" :: Text)
    , "projeto" .= ("FocusFlow" :: Text)
    ]

-- GET /api/tarefas
-- liftIO "sobe" a operação IO para dentro do contexto ActionM do Scotty.
-- Sem ele, o compilador reclamaria que IO e ActionM são contextos diferentes.
rotaGetTarefas :: Connection -> ActionM ()
rotaGetTarefas conn = do
    tarefas <- liftIO (listarTarefas conn)
    json tarefas

-- POST /api/tarefas
rotaPostTarefa :: Connection -> ActionM ()
rotaPostTarefa conn = do
    novaTarefa <- jsonData

    -- Busca a agenda atual do banco para checar conflitos (substitui agendaMock)
    existentes <- liftIO (listarTarefas conn)

    let conflito      = temConflito novaTarefa existentes
        tarefasEmConf = conflitosEm novaTarefa existentes

    if conflito
        then do
            status status409
            json $ object
                [ "erro"      .= ("Conflito de horário" :: Text)
                , "conflitos" .= tarefasEmConf
                ]
        else do
            liftIO (inserirTarefa conn novaTarefa)
            status status201
            json $ SucessoResponse novaTarefa

-- Rotas
app :: Connection -> ScottyM ()
app conn = do
    get  "/api/status"  rotaStatus
    get  "/api/tarefas" (rotaGetTarefas conn)
    post "/api/tarefas" (rotaPostTarefa conn)

-- Ponto de entrada
main :: IO ()
main = do
    conn <- inicializarDB

    putStrLn "╔══════════════════════════════════╗"
    putStrLn "║   FocusFlow API  -  Sprint 4     ║"
    putStrLn "║   http://localhost:8080          ║"
    putStrLn "╚══════════════════════════════════╝"

    scotty 8080 (app conn)
