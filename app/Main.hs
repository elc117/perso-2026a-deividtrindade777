{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric     #-}

{- |
Module      : Main
Description : Camada de IO e servidor HTTP do FocusFlow
Stability   : experimental

Este módulo é a __única camada impura__ da aplicação. Toda operação
que envolve efeitos colaterais ('IO') está aqui — leitura de requisições
HTTP, escrita de respostas e o estado simulado da agenda.

=== Separação de responsabilidades

@
┌─────────────────────────────────────────────────────────┐
│                    Main.hs  (IO)                        │
│  servidor HTTP, roteamento, serialização JSON           │
│                        │                               │
│            chama, mas não mistura                       │
│                        ▼                               │
│                   Logic.hs  (puro)                      │
│            temConflito, conflitosEm, ...                │
│                        │                               │
│                        ▼                               │
│                   Types.hs  (puro)                      │
│             Tarefa, Categoria, Prioridade               │
└─────────────────────────────────────────────────────────┘
@

A lógica de negócios em 'Logic' __nunca conhece__ o Scotty, o Aeson
ou qualquer conceito de HTTP. A fronteira IO está contida aqui.

=== Nota sobre o estado

Na ausência de banco de dados (Sprint 3), a agenda é um valor
imutável definido em 'agendaMock'. Nas sprints seguintes, este
valor será substituído por um 'IORef' ou integração com SQLite.
-}
module Main (main) where

import           Control.Monad.IO.Class (liftIO)
import           Data.Aeson             (ToJSON (..), FromJSON (..), object,
                                         (.=), encode, genericToJSON,
                                         genericParseJSON, defaultOptions,
                                         Options (..))
import           Data.Text.Lazy         (Text)
import qualified Data.Text.Lazy         as TL
import           Data.Time              (fromGregorian, TimeOfDay (..))
import           GHC.Generics           (Generic)
import           Network.HTTP.Types     (status201, status409)
import           Web.Scotty             (ScottyM, ActionM, scotty, get, post,
                                         json, jsonData, status, text)

import           Logic                  (temConflito, conflitosEm)
import           Types                  (Tarefa (..), Categoria (..),
                                         Prioridade (..))

-- ---------------------------------------------------------------------------
-- * Tipos de resposta da API
-- ---------------------------------------------------------------------------

{- |
Envelope de resposta de __erro__ da API.

Toda resposta de erro segue este esquema JSON:

@
{
  "erro": "Descrição legível do problema",
  "codigo": "MACHINE_READABLE_CODE"
}
@

Separar o campo humano ('erroMensagem') do campo de máquina ('erroCode')
permite que clientes façam tratamento programático sem depender de strings.
-}
data ErroResponse = ErroResponse
    { erroMensagem :: Text    -- ^ Descrição legível por humanos
    , erroCode     :: Text    -- ^ Código de erro para o cliente (ex: "CONFLICT")
    } deriving (Show, Eq, Generic)

-- Remove o prefixo "erro" nos campos JSON: { "mensagem": ..., "code": ... }
erroJsonOptions :: Options
erroJsonOptions = defaultOptions
    { fieldLabelModifier = drop (length ("erro" :: String)) }

instance ToJSON   ErroResponse where toJSON = genericToJSON erroJsonOptions
instance FromJSON ErroResponse where parseJSON = genericParseJSON erroJsonOptions


{- |
Envelope de resposta de __sucesso__ da API.

Usado como wrapper consistente para todas as respostas 2xx, permitindo
que o cliente sempre espere o mesmo formato:

@
{ "dados": <payload>, "mensagem": "Descrição do sucesso" }
@
-}
data SucessoResponse a = SucessoResponse
    { sucessoDados    :: a     -- ^ Payload da resposta (polimórfico)
    , sucessoMensagem :: Text  -- ^ Mensagem descritiva
    } deriving (Show, Eq, Generic)

sucessoJsonOptions :: Options
sucessoJsonOptions = defaultOptions
    { fieldLabelModifier = drop (length ("sucesso" :: String)) }

instance ToJSON a => ToJSON (SucessoResponse a) where
    toJSON = genericToJSON sucessoJsonOptions


-- ---------------------------------------------------------------------------
-- * Estado simulado (Mock)
-- ---------------------------------------------------------------------------

{- |
Lista imutável de tarefas pré-cadastradas, simulando um banco de dados.

__Impureza controlada__: este valor é uma constante Haskell — tecnicamente
puro, mas representa o "estado do mundo externo" que em produção viria
de uma fonte de IO. Ao isolar o mock aqui, a troca por 'IORef' ou SQLite
na Sprint 4 exige mudança apenas nesta função.

As tarefas cobrem o dia @2025-10-20@ intencionalmente para que os testes
manuais com @POST /api/tarefas@ usem essa mesma data.
-}
agendaMock :: [Tarefa]
agendaMock =
    [ Tarefa
        { tarefaId         = 1
        , tarefaTitulo     = "Reunião de planejamento"
        , tarefaCategoria  = Trabalho
        , tarefaPrioridade = Alta
        , tarefaData       = fromGregorian 2025 10 20
        , tarefaInicio     = TimeOfDay 9 0 0
        , tarefaDuracao    = 60          -- 09:00 – 10:00
        , tarefaDescricao  = Just "Sprint planning semanal"
        }
    , Tarefa
        { tarefaId         = 2
        , tarefaTitulo     = "Aula de Paradigmas"
        , tarefaCategoria  = Faculdade
        , tarefaPrioridade = Alta
        , tarefaData       = fromGregorian 2025 10 20
        , tarefaInicio     = TimeOfDay 10 30 0
        , tarefaDuracao    = 90          -- 10:30 – 12:00
        , tarefaDescricao  = Nothing
        }
    , Tarefa
        { tarefaId         = 3
        , tarefaTitulo     = "Almoço + pausa"
        , tarefaCategoria  = Lazer
        , tarefaPrioridade = Baixa
        , tarefaData       = fromGregorian 2025 10 20
        , tarefaInicio     = TimeOfDay 12 0 0
        , tarefaDuracao    = 60          -- 12:00 – 13:00
        , tarefaDescricao  = Nothing
        }
    , Tarefa
        { tarefaId         = 4
        , tarefaTitulo     = "Treino de corrida"
        , tarefaCategoria  = Esportes
        , tarefaPrioridade = Media
        , tarefaData       = fromGregorian 2025 10 20
        , tarefaInicio     = TimeOfDay 18 0 0
        , tarefaDuracao    = 45          -- 18:00 – 18:45
        , tarefaDescricao  = Just "Ritmo leve, 5km"
        }
    ]


-- ---------------------------------------------------------------------------
-- * Rotas da API
-- ---------------------------------------------------------------------------

{- |
Rota @GET \/api\/status@.

Ponto de verificação de saúde da API (/health check/). Retorna sempre
HTTP 200 com um JSON indicando o status e a versão da aplicação.

Não acessa nenhum estado — é a função mais pura possível dentro de 'IO'.
-}
rotaStatus :: ActionM ()
rotaStatus = json $ object
    [ "status"  .= ("ok" :: Text)
    , "app"     .= ("FocusFlow API" :: Text)
    , "versao"  .= ("0.1.0" :: Text)
    , "sprint"  .= (3 :: Int)
    ]


{- |
Rota @POST \/api\/tarefas@.

Recebe o JSON de uma 'Tarefa' no corpo da requisição e verifica conflitos
de horário contra a 'agendaMock'.

=== Fluxo de decisão

@
parseJSON body
    │
    ├─ falha de parse  →  400 Bad Request  (tratado pelo Scotty)
    │
    └─ Tarefa válida
           │
           ├─ temConflito == True   →  409 Conflict  + lista de conflitos
           │
           └─ temConflito == False  →  201 Created   + tarefa confirmada
@

=== Separação IO / Puro

A única chamada impura aqui é @jsonData@ (lê o corpo HTTP).
A decisão de conflito é delegada inteiramente a 'temConflito' e
'conflitosEm', que são funções puras de 'Logic' — sem IO.
-}
rotaPostTarefa :: ActionM ()
rotaPostTarefa = do
    -- [IO] Lê e desserializa o corpo da requisição
    novaTarefa <- jsonData :: ActionM Tarefa

    -- [PURO] Toda a lógica de negócios acontece aqui, sem IO
    let conflito      = temConflito novaTarefa agendaMock
        tarefasEmConf = conflitosEm novaTarefa agendaMock

    if conflito
        -- 409 Conflict: retorna quais tarefas causaram o conflito
        then do
            status status409
            json $ object
                [ "erro"      .= ("Conflito de horário detectado" :: Text)
                , "codigo"    .= ("SCHEDULE_CONFLICT" :: Text)
                , "conflitos" .= tarefasEmConf
                ]
        -- 201 Created: devolve a tarefa como confirmação de agendamento
        else do
            status status201
            json $ SucessoResponse
                { sucessoDados    = novaTarefa
                , sucessoMensagem = "Tarefa agendada com sucesso"
                }


-- ---------------------------------------------------------------------------
-- * Definição do servidor
-- ---------------------------------------------------------------------------

{- |
Define todas as rotas da aplicação Scotty.

Separar o roteamento de 'main' facilita os testes: em sprints futuras,
'app' poderá ser passado para @scottyApp@ do Warp e testado com
@Network.Wai.Test@ sem subir um servidor real.
-}
app :: ScottyM ()
app = do
    get  "/api/status"  rotaStatus
    post "/api/tarefas" rotaPostTarefa


-- ---------------------------------------------------------------------------
-- * Ponto de entrada
-- ---------------------------------------------------------------------------

{- |
Ponto de entrada da aplicação.

Sobe o servidor Scotty na porta @3000@. Todo o código de 'IO' da
aplicação converge aqui; as funções de lógica de negócios ('Logic')
nunca precisam saber que este módulo existe.
-}
main :: IO ()
main = do
    putStrLn "╔══════════════════════════════════╗"
    putStrLn "║   FocusFlow API  -  Sprint 3     ║"
    putStrLn "║   http://localhost:3000          ║"
    putStrLn "╚══════════════════════════════════╝"
    putStrLn $ "Agenda mock carregada: "
             ++ show (length agendaMock)
             ++ " tarefa(s)"
    scotty 3000 app
