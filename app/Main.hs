{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric     #-}

module Main (main) where

import           Web.Scotty
import           Web.Scotty.Internal.Types (ActionT)
import           Control.Monad.IO.Class (liftIO)
import           Database.SQLite.Simple (Connection)
import           Data.Aeson             (ToJSON, object, (.=))
import           Data.Text.Lazy         (Text)
import           GHC.Generics           (Generic)
import           Network.HTTP.Types     (status201, status404, status409)

import           Database (inicializarDB, listarTarefas, inserirTarefa, deletarTarefa)
import           Logic    (temConflito, conflitosEm)
import           Types    (Tarefa (..), Categoria (..), Prioridade (..))

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
rotaGetTarefas :: Connection -> ActionM ()
rotaGetTarefas conn = do
    tarefas <- liftIO (listarTarefas conn)
    json tarefas

-- POST /api/tarefas
rotaPostTarefa :: Connection -> ActionM ()
rotaPostTarefa conn = do
    novaTarefa <- jsonData
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

-- DELETE /api/tarefas/:id
-- `param "id"` lê o segmento dinâmico da URL e converte para Int automaticamente.
-- Se o id não existir na tabela, o SQLite simplesmente não apaga nada (0 linhas afetadas).
-- Retornamos 200 com mensagem de sucesso de qualquer forma, pois o estado final é o mesmo.
rotaDeleteTarefa :: Connection -> ActionM ()
rotaDeleteTarefa conn = do
    tid <- pathParam "id" :: ActionM Int
    liftIO (deletarTarefa conn tid)
    json $ object [ "mensagem" .= ("Tarefa removida com sucesso" :: Text) ]

-- Rotas
app :: Connection -> ScottyM ()
app conn = do
    get    "/api/status"       rotaStatus
    get    "/api/tarefas"      (rotaGetTarefas  conn)
    post   "/api/tarefas"      (rotaPostTarefa  conn)
    delete "/api/tarefas/:id"  (rotaDeleteTarefa conn)

main :: IO ()
main = do
    conn <- inicializarDB

    putStrLn "╔══════════════════════════════════╗"
    putStrLn "║   FocusFlow API  -  Sprint 5     ║"
    putStrLn "║   http://localhost:8080          ║"
    putStrLn "╚══════════════════════════════════╝"

    scotty 8080 (app conn)
