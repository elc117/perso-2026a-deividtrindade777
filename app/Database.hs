{-# LANGUAGE OverloadedStrings #-}

module Database (inicializarDB, listarTarefas, inserirTarefa, deletarTarefa) where

import Database.SQLite.Simple
import Data.Text (unpack)

import Types

instance FromRow Tarefa where
    fromRow = Tarefa
        <$> field
        <*> field
        <*> (read . unpack <$> field)
        <*> (read . unpack <$> field)
        <*> (read . unpack <$> field)
        <*> (read . unpack <$> field)
        <*> field
        <*> field

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

-- Apaga a tarefa pelo id. Usa `execute` com parâmetro para evitar SQL injection.
-- `Only` é um wrapper do sqlite-simple para passar um único valor como parâmetro.
deletarTarefa :: Connection -> Int -> IO ()
deletarTarefa conn tid =
    execute conn "DELETE FROM tarefas WHERE id = ?" (Only tid)
