{-# LANGUAGE OverloadedStrings #-}

module Database (inicializarDB, listarTarefas, inserirTarefa) where

import Database.SQLite.Simple
import Data.Text (unpack)

import Types

-- FromRow: ensina o sqlite-simple a converter uma linha da tabela em Tarefa
-- Cada `field` lê a próxima coluna na ordem do SELECT.
-- `read . unpack` faz o caminho inverso do `show`: TEXT -> tipo Haskell.
instance FromRow Tarefa where
    fromRow = Tarefa
        <$> field                     -- id        :: Int
        <*> field                     -- titulo    :: Text
        <*> (read . unpack <$> field) -- categoria :: Categoria
        <*> (read . unpack <$> field) -- prioridade:: Prioridade
        <*> (read . unpack <$> field) -- data      :: Day
        <*> (read . unpack <$> field) -- inicio    :: TimeOfDay
        <*> field                     -- duracao   :: Int
        <*> field                     -- descricao :: Maybe Text

inicializarDB :: IO Connection
inicializarDB = do
    conn <- open "focusflow.db"
    execute_ conn
        "CREATE TABLE IF NOT EXISTS tarefas \
        \(id INTEGER PRIMARY KEY AUTOINCREMENT, \
        \titulo TEXT NOT NULL, \
        \categoria TEXT NOT NULL, \
        \prioridade TEXT NOT NULL, \
        \data TEXT NOT NULL, \
        \inicio TEXT NOT NULL, \
        \duracao INTEGER NOT NULL, \
        \descricao TEXT)"
    putStrLn "Banco de dados inicializado: focusflow.db"
    return conn

inserirTarefa :: Connection -> Tarefa -> IO ()
inserirTarefa conn t =
    execute conn
        "INSERT INTO tarefas \
        \(titulo, categoria, prioridade, data, inicio, duracao, descricao) \
        \VALUES (?, ?, ?, ?, ?, ?, ?)"
        ( tarefaTitulo    t
        , show (tarefaCategoria  t)
        , show (tarefaPrioridade t)
        , show (tarefaData       t)
        , show (tarefaInicio     t)
        , tarefaDuracao   t
        , tarefaDescricao t
        )

listarTarefas :: Connection -> IO [Tarefa]
listarTarefas conn =
    query_ conn "SELECT id, titulo, categoria, prioridade, data, inicio, duracao, descricao FROM tarefas"
