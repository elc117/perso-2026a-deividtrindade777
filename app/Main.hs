{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric     #-}

module Main (main) where

import           Data.Aeson             (ToJSON, FromJSON, object, (.=))
import           Data.Text.Lazy         (Text)
import           Data.Time              (fromGregorian, TimeOfDay (..))
import           GHC.Generics           (Generic)
import           Network.HTTP.Types     (status201, status409)
import           Web.Scotty

-- Importação dos módulos locais
import           Logic                  (temConflito, conflitosEm)
import           Types                  (Tarefa (..), Categoria (..), Prioridade (..))

-- Envelopes para padronização das respostas da API
data ErroResponse = ErroResponse
    { mensagem :: Text
    , codigo   :: Text
    } deriving (Show, Generic)

instance ToJSON ErroResponse

data SucessoResponse a = SucessoResponse
    { dados    :: a
    } deriving (Show, Generic)

instance ToJSON a => ToJSON (SucessoResponse a)

-- Dados iniciais para teste (Simulação de DB)
agendaMock :: [Tarefa]
agendaMock =
    [ Tarefa 1 "Reunião de Sprint" Trabalho Alta (fromGregorian 2025 10 20) (TimeOfDay 9 0 0) 60 Nothing
    , Tarefa 2 "Aula de Paradigmas" Faculdade Alta (fromGregorian 2025 10 20) (TimeOfDay 10 30 0) 90 Nothing
    ]

-- Handlers das Rotas
rotaStatus :: ActionM ()
rotaStatus = json $ object [ "status" .= ("ok" :: Text), "projeto" .= ("FocusFlow" :: Text) ]

rotaPostTarefa :: ActionM ()
rotaPostTarefa = do
    novaTarefa <- jsonData
    let conflito      = temConflito novaTarefa agendaMock
        tarefasEmConf = conflitosEm novaTarefa agendaMock

    if conflito
        then do
            status status409
            json $ object [ "erro" .= ("Conflito de horário" :: Text), "conflitos" .= tarefasEmConf ]
        else do
            status status201
            json $ SucessoResponse novaTarefa

-- Definição do servidor
main :: IO ()
main = scotty 8080 $ do
    get  "/api/status"  rotaStatus
    post "/api/tarefas" rotaPostTarefa