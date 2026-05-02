{-# LANGUAGE OverloadedStrings #-}
-- test/Spec.hs
-- Testes unitários das funções puras de Logic.hs
-- Rode com: cabal test
-- Ou diretamente: runhaskell test/Spec.hs

import Test.HUnit
import Data.Time (fromGregorian, TimeOfDay (..))

import Types
import Logic

-- ---------------------------------------------------------------------------
-- Dados de apoio para os testes
-- ---------------------------------------------------------------------------

-- Tarefa das 09:00 às 10:00 (60 min)
tarefaA :: Tarefa
tarefaA = Tarefa
    { tarefaId         = 1
    , tarefaTitulo     = "Reunião"
    , tarefaCategoria  = Trabalho
    , tarefaPrioridade = Alta
    , tarefaData       = fromGregorian 2025 10 20
    , tarefaInicio     = TimeOfDay 9 0 0
    , tarefaDuracao    = 60
    , tarefaDescricao  = Nothing
    }

-- Tarefa das 09:30 às 10:30 — conflita com tarefaA
tarefaB :: Tarefa
tarefaB = tarefaA
    { tarefaId     = 2
    , tarefaTitulo = "Call urgente"
    , tarefaInicio = TimeOfDay 9 30 0
    , tarefaDuracao = 60
    }

-- Tarefa das 10:00 às 11:00 — adjacente, NÃO conflita com tarefaA
tarefaC :: Tarefa
tarefaC = tarefaA
    { tarefaId     = 3
    , tarefaTitulo = "Stand-up"
    , tarefaInicio = TimeOfDay 10 0 0
    , tarefaDuracao = 60
    }

-- Tarefa no dia seguinte — nunca conflita
tarefaD :: Tarefa
tarefaD = tarefaA
    { tarefaId     = 4
    , tarefaTitulo = "Aula amanhã"
    , tarefaData   = fromGregorian 2025 10 21
    , tarefaInicio = TimeOfDay 9 0 0
    , tarefaDuracao = 60
    }

-- ---------------------------------------------------------------------------
-- Testes de calcularFim
-- ---------------------------------------------------------------------------

testeFimNormal :: Test
testeFimNormal = TestCase $
    assertEqual
        "09:00 + 90min deve ser 10:30"
        (TimeOfDay 10 30 0)
        (calcularFim (TimeOfDay 9 0 0) 90)

testeFimTeto :: Test
testeFimTeto = TestCase $
    assertEqual
        "23:30 + 60min não pode passar de 23:59:59"
        (TimeOfDay 23 59 59)
        (calcularFim (TimeOfDay 23 30 0) 60)

testeFimDuracaoZero :: Test
testeFimDuracaoZero = TestCase $
    assertEqual
        "Duração zero deve retornar o próprio início"
        (TimeOfDay 9 0 0)
        (calcularFim (TimeOfDay 9 0 0) 0)

-- ---------------------------------------------------------------------------
-- Testes de temConflito
-- ---------------------------------------------------------------------------

testeConflitoSobreposicaoParcial :: Test
testeConflitoSobreposicaoParcial = TestCase $
    assertBool
        "tarefaB (09:30) deve conflitar com tarefaA (09:00-10:00)"
        (temConflito tarefaB [tarefaA])

testeConflitoAdjacente :: Test
testeConflitoAdjacente = TestCase $
    assertBool
        "tarefaC (10:00) NÃO deve conflitar com tarefaA (09:00-10:00)"
        (not $ temConflito tarefaC [tarefaA])

testeConflitoListaVazia :: Test
testeConflitoListaVazia = TestCase $
    assertBool
        "Qualquer tarefa contra lista vazia nunca conflita"
        (not $ temConflito tarefaA [])

testeConflitoDiaDiferente :: Test
testeConflitoDiaDiferente = TestCase $
    assertBool
        "Mesmos horários em dias diferentes não conflitam"
        (not $ temConflito tarefaD [tarefaA])

testeConflitoPropriaTarefa :: Test
testeConflitoPropriaTarefa = TestCase $
    assertBool
        "Uma tarefa sempre conflita consigo mesma"
        (temConflito tarefaA [tarefaA])

-- ---------------------------------------------------------------------------
-- Testes de conflitosEm
-- ---------------------------------------------------------------------------

testeConflitosEmRetornaLista :: Test
testeConflitosEmRetornaLista = TestCase $
    assertEqual
        "conflitosEm deve retornar exatamente tarefaA como conflitante"
        [tarefaA]
        (conflitosEm tarefaB [tarefaA, tarefaD])

testeConflitosEmListaVazia :: Test
testeConflitosEmListaVazia = TestCase $
    assertEqual
        "conflitosEm com lista vazia retorna []"
        []
        (conflitosEm tarefaA [])

-- ---------------------------------------------------------------------------
-- Suíte principal
-- ---------------------------------------------------------------------------

todosTestes :: Test
todosTestes = TestList
    [ TestLabel "calcularFim normal"            testeFimNormal
    , TestLabel "calcularFim teto 23:59:59"     testeFimTeto
    , TestLabel "calcularFim duração zero"      testeFimDuracaoZero
    , TestLabel "conflito sobreposição parcial" testeConflitoSobreposicaoParcial
    , TestLabel "conflito adjacente (false)"    testeConflitoAdjacente
    , TestLabel "conflito lista vazia"          testeConflitoListaVazia
    , TestLabel "conflito dia diferente"        testeConflitoDiaDiferente
    , TestLabel "conflito mesma tarefa"         testeConflitoPropriaTarefa
    , TestLabel "conflitosEm retorna lista"     testeConflitosEmRetornaLista
    , TestLabel "conflitosEm lista vazia"       testeConflitosEmListaVazia
    ]

main :: IO ()
main = do
    resultado <- runTestTT todosTestes
    putStrLn $ "\nTestes:  " ++ show (tried resultado)
    putStrLn $ "Falhas:  " ++ show (failures resultado)
    putStrLn $ "Erros:   " ++ show (errors resultado)
