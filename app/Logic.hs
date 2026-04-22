{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : Logic
Description : Lógica de negócios pura do FocusFlow
Stability   : experimental

Este módulo contém exclusivamente __funções puras__ — nenhuma opera em 'IO'.
Toda entrada é explícita nos parâmetros; toda saída é determinada apenas
por eles. Isso garante testabilidade total e raciocínio local sobre o código,
duas propriedades centrais do paradigma funcional.

=== Invariante do módulo

Uma função @f@ aqui presente satisfaz:

@
f x == f x   -- para todo x, em qualquer contexto, em qualquer momento
@

O compilador não pode verificar a ausência de 'IO' automaticamente neste
módulo, mas a assinatura de cada função serve como contrato explícito.
-}
module Logic
    ( -- * Cálculo de intervalos
      calcularFim

      -- * Validação de conflitos
    , temConflito
    , conflitosEm

      -- * Tipos auxiliares
    , Intervalo (..)
    , intervaloDaTarefa
    ) where

import Data.List  (filter)
import Data.Time  (TimeOfDay (..), timeToTimeOfDay, timeOfDayToTime)

import Types      (Tarefa (..))

-- ---------------------------------------------------------------------------
-- $intro
-- #intro#
-- As funções seguem uma hierarquia de abstração deliberada:
--
-- 1. 'calcularFim'      — opera sobre 'TimeOfDay' e 'Int' (minutos)
-- 2. 'Intervalo'        — captura o par (início, fim) de uma tarefa
-- 3. 'intervaloDaTarefa' — eleva uma 'Tarefa' ao domínio de 'Intervalo'
-- 4. 'sobrepoem'        — verifica sobreposição entre dois 'Intervalo's
-- 5. 'temConflito'      — ponto de entrada público, compõe as anteriores
-- 6. 'conflitosEm'      — retorna a lista de tarefas conflitantes
-- ---------------------------------------------------------------------------


-- ---------------------------------------------------------------------------
-- * Tipos auxiliares
-- ---------------------------------------------------------------------------

{- |
'Intervalo' representa o período de execução de uma tarefa no dia,
definido pelo horário de __início__ (inclusivo) e __fim__ (exclusivo).

Usar um tipo dedicado em vez de uma tupla @(TimeOfDay, TimeOfDay)@ torna as
assinaturas mais expressivas e impede que inicio e fim sejam trocados por
engano — uma forma leve de /type-driven development/.
-}
data Intervalo = Intervalo
    { inicio :: TimeOfDay  -- ^ Horário de início (inclusivo)
    , fim    :: TimeOfDay  -- ^ Horário de término (exclusivo)
    } deriving (Show, Eq)


-- ---------------------------------------------------------------------------
-- * Cálculo de intervalos
-- ---------------------------------------------------------------------------

{- |
Calcula o horário de término de uma tarefa somando sua duração em minutos
ao horário de início.

=== Propriedades

* Pureza total: sem efeitos colaterais.
* Se @duracao <= 0@, retorna o próprio @inicioTarefa@ (tarefa sem duração).
* Não extrapola para o dia seguinte — limite superior é @23:59:59@.

=== Exemplos

>>> calcularFim (TimeOfDay 9 0 0) 90
10:30:00

>>> calcularFim (TimeOfDay 23 30 0) 60
23:59:59

@
calcularFim :: TimeOfDay  -- ^ Horário de início
            -> Int        -- ^ Duração em minutos
            -> TimeOfDay  -- ^ Horário de término calculado
@
-}
calcularFim :: TimeOfDay -> Int -> TimeOfDay
calcularFim inicioTarefa duracaoMin =
    let -- 'timeOfDayToTime' converte TimeOfDay para segundos desde meia-noite
        -- como um valor do tipo 'DiffTime'
        inicioSeg   = timeOfDayToTime inicioTarefa
        duracaoSeg  = fromIntegral (max 0 duracaoMin) * 60
        fimSeg      = inicioSeg + duracaoSeg
        -- Teto de 86399 segundos (23:59:59) para não cruzar a meia-noite
        fimSegClamp = min fimSeg 86399
    in  timeToTimeOfDay fimSegClamp


{- |
Constrói um 'Intervalo' a partir de uma 'Tarefa', usando
'tarefaInicio' e 'tarefaDuracao' como fonte de dados.

Esta função é o ponto de contato entre o domínio de dados ('Types')
e o domínio de lógica ('Logic'), aplicando o princípio de
separação de responsabilidades.
-}
intervaloDaTarefa :: Tarefa -> Intervalo
intervaloDaTarefa t = Intervalo
    { inicio = tarefaInicio t
    , fim    = calcularFim (tarefaInicio t) (tarefaDuracao t)
    }


-- ---------------------------------------------------------------------------
-- * Detecção de sobreposição
-- ---------------------------------------------------------------------------

{- |
Verifica se dois 'Intervalo's se sobrepõem no tempo.

Dois intervalos @A@ e @B@ __não__ se sobrepõem apenas quando:

@
fim A <= inicio B   —   A termina antes (ou exatamente quando) B começa
fim B <= inicio A   —   B termina antes (ou exatamente quando) A começa
@

A negação dessas duas condições define a sobreposição. Isso é o
__Teorema do Intervalo Separado__ aplicado ao domínio de agendas.

Note que o fim é tratado como __exclusivo__: uma tarefa que termina às
10:00 NÃO conflita com outra que começa às 10:00.

=== Exemplos (em pseudocódigo)

@
-- [09:00, 10:30) x [10:00, 11:00)  =>  True   (sobreposição parcial)
-- [09:00, 10:00) x [10:00, 11:00)  =>  False  (adjacentes, sem sobreposição)
-- [09:00, 11:00) x [10:00, 10:30)  =>  True   (contenção total)
@
-}
sobrepoem :: Intervalo -> Intervalo -> Bool
sobrepoem a b =
    inicio a < fim b   -- A começa antes de B terminar
    &&
    inicio b < fim a   -- B começa antes de A terminar


-- ---------------------------------------------------------------------------
-- * API pública de validação
-- ---------------------------------------------------------------------------

{- |
Verifica se uma 'Tarefa' nova possui conflito de horário com qualquer
tarefa de uma lista de tarefas existentes.

A função aplica três filtros em sequência, usando composição e funções
de alta ordem:

1. @filter mesmoDia@  — descarta tarefas em dias diferentes (sem custo de cálculo de intervalo)
2. @map intervaloDaTarefa@ — eleva as tarefas restantes para o domínio de 'Intervalo'
3. @any (sobrepoem ivNova)@ — retorna 'True' se __qualquer__ intervalo conflita

=== Uso esperado

@
let tarefas = [almoço, reunião, academia]
let novaTarefa = standup
temConflito novaTarefa tarefas  -- False se standup não sobrepõe nenhuma
@

=== Propriedades

* @temConflito t [] == False@ para qualquer @t@ (lista vazia não conflita)
* @temConflito t [t] == True@  — uma tarefa sempre conflita consigo mesma
-}
temConflito :: Tarefa   -- ^ Tarefa nova a ser agendada
            -> [Tarefa] -- ^ Lista de tarefas já existentes
            -> Bool     -- ^ 'True' se existe ao menos um conflito de horário
temConflito nova existentes =
    let ivNova     = intervaloDaTarefa nova
        mesmoDia t = tarefaData t == tarefaData nova
        -- Pipeline funcional: filtrar → transformar → verificar
        conflita   = any (sobrepoem ivNova)
                   . map intervaloDaTarefa
                   . filter mesmoDia
                   $ existentes
    in  conflita


{- |
Retorna a sublista de tarefas que conflitam com a tarefa nova.

Enquanto 'temConflito' responde "existe conflito?" (curto-circuito),
'conflitosEm' responde "quais conflitam?" — útil para gerar mensagens
de erro detalhadas na camada de API.

=== Relação com 'temConflito'

@
temConflito nova existentes == (not . null) (conflitosEm nova existentes)
@

Essa propriedade pode ser usada como teste de regressão (QuickCheck).
-}
conflitosEm :: Tarefa   -- ^ Tarefa nova a ser agendada
            -> [Tarefa] -- ^ Lista de tarefas já existentes
            -> [Tarefa] -- ^ Sublista de tarefas que conflitam
conflitosEm nova existentes =
    let ivNova      = intervaloDaTarefa nova
        mesmoDia  t = tarefaData t == tarefaData nova
        conflitaCom t = sobrepoem ivNova (intervaloDaTarefa t)
    in  filter conflitaCom
      . filter mesmoDia
      $ existentes