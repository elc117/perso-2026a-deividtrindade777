# Backend Web com Haskell+Scotty

## 1. Identificação
*   **Nome:** Deivid Da Silva Trindade
*   **Curso:** Sistemas de Informação

## 2. Tema/objetivo
A ideia inicial do projeto era criar uma agenda no estilo do Google Agenda, mas com um foco bem forte em produtividade e organização de horários divididos entre trabalho, estudos e lazer. O objetivo era ter um sistema onde fosse possível cadastrar as tarefas do dia a dia e organizar a rotina de forma inteligente.

O serviço desenvolvido é o FocusFlow, uma API REST para gerenciamento dessas tarefas. A principal sacada usando programação funcional é a verificação de horários. Quando você cadastra uma atividade nova, o sistema precisa garantir que você não está marcando duas coisas para o mesmo horário. Implementei toda essa lógica de detecção de conflitos (`temConflito` e `conflitosEm`) usando funções puras, recebendo os dados das tarefas, usando `filter` e retornando se está tudo certo, sem precisar alterar nada no banco de dados na hora de fazer o cálculo. Só depois que a lógica funcional aprova, a tarefa é salva no SQLite.

## 3. Processo de desenvolvimento
Como eu já faço estágio e trabalho com backend em Python, vir para o Haskell foi um choque de realidade. No Python tudo é muito dinâmico, mas o Haskell (e o GHC) não perdoa nada.

A minha ideia inicial era fazer as rotas no Scotty primeiro e ir enfiando a lógica dentro delas. Mas lendo o material da aula, percebi que isso ia dar muita dor de cabeça. A principal decisão que tomei logo no início foi criar um arquivo `Logic.hs` totalmente separado do `Main.hs` (onde fica o Scotty) e do `Database.hs`.

**Erros e Dificuldades:**
Uma das minhas maiores dores de cabeça iniciais foi o ambiente de desenvolvimento. Eu tentei subir o servidor localmente no Windows sem o SQLite, só para testar as rotas básicas do Scotty, e o servidor simplesmente não subia de jeito nenhum. Tive muitos problemas de incompatibilidade e o Windows brigou feio com o Haskell. Acabou que eu só consegui ver as rotas respondendo perfeitamente quando joguei tudo para o deploy no Linux via Docker.

Além disso, apanhei bastante para entender a ordem das coisas nos arquivos. Teve um erro clássico logo no começo: `parse error on input 'module'`. Eu não entendia o porquê, já que a palavra module estava escrita certa. Fui descobrir que no Haskell os `{-# LANGUAGE ... #-}` precisam ficar no topo absoluto do arquivo, antes de qualquer import ou declaração.

Outra mudança de rumo foi nos tipos das respostas. Tive que usar a biblioteca `Data.Aeson` com `Generic` para conseguir converter minhas estruturas de dados (como `Tarefa` ou `SucessoResponse`) direto para JSON nas requisições da web, porque tentar formatar string na mão em Haskell seria inviável.

**Planos para o futuro:**
Esse projeto me deu uma base muito boa, e como planos futuros, pretendo construir um frontend para consumir essa API e integrar um bot de WhatsApp. O objetivo é que o sistema funcione como as notificações do Google Agenda, mandando uma mensagem no celular avisando 5 ou 10 minutos antes de um compromisso, estudo ou reunião começar.

## 4. Testes
Eu separei os testes totalmente da parte web. Não faria sentido testar o Scotty agora, então foquei no módulo `Logic.hs`.

*   Usei o HUnit para testar as funções puras.
*   Testei principalmente as funções `temConflito` e `conflitosEm`.
*   A organização foi criar algumas "Tarefas" falsas em memória, com horários que se sobrepunham e outras com horários livres. Com o HUnit, eu verificava se a função retornava `True` quando os horários batiam (exemplo: duas tarefas começando às 14:00) e `False` quando eram sequenciais. Isso me deu a garantia de que a regra de negócio funcionava antes mesmo de eu conectar o banco de dados.

## 5. Execução
Para rodar o projeto na sua máquina:

1.  Precisa ter o `ghc` e o `cabal` instalados.
2.  É necessário ter a biblioteca do sqlite: `sudo apt-get install libsqlite3-dev` (no Linux/WSL).
3.  Na pasta do projeto, rode `cabal update` e depois `cabal build`.
4.  Para subir o servidor, use `cabal run focusflow`.
5.  Ele vai rodar na porta 8080 (acessar via `localhost:8080`).

## 6. Deploy
**Link do serviço publicado:** https://focusflow-api-nlhc.onrender.com/api/status

O deploy foi, de longe, a parte mais difícil do trabalho. Tentei seguir a base do Render com Docker, mas tive vários problemas seguidos:

*   O Render (Linux) dava erro que não achava meu arquivo `.cabal`. Descobri que era problema de letra maiúscula/minúscula no Dockerfile (meu arquivo no Windows era `FocusFlow.cabal` e no Docker tava minúsculo).
*   O aplicativo dava um crash instantâneo com `Exited with status 1` logo depois de dar o deploy. Olhando os logs bem de perto, vi o erro `commitBuffer: invalid argument`. Isso aconteceu porque o Linux do Docker não tava configurado para ler acentos (UTF-8) que eu mandava imprimir no terminal com `putStrLn`. Tive que adicionar algumas variáveis de ambiente (`ENV LANG=C.UTF-8`) no Dockerfile pra resolver.

## 7. Resultado final
O sistema está rodando em produção e pode ser consumido por qualquer cliente HTTP (como Postman, Insomnia ou curl). Abaixo demonstro o fluxo principal de funcionamento da API.

**1. Rota de Status (GET /api/status)**
Garante que o servidor Haskell e o banco de dados estão online e respondendo.

Resposta do Servidor:
```json
{
  "projeto": "FocusFlow",
  "status": "ok"
}
```

**2. Criando uma nova Tarefa (POST /api/tarefas)**
Nesta rota, o sistema recebe o JSON, passa pela lógica funcional (Logic.hs) para verificar se há conflito de horários usando temConflito. Se o horário estiver livre, a tarefa é persistida no SQLite.

Corpo da Requisição (JSON enviado):

```json
{
  "titulo": "Estudar Paradigmas",
  "categoria": "Estudos",
  "inicio": "14:00",
  "fim": "16:00"
}
```

Resposta de Sucesso:

```json
{
  "mensagem": "Tarefa criada com sucesso",
  "id_gerado": 1
}
```

Demonstração Visual:
Abaixo, a execução prática batendo no link de deploy, comprovando o funcionamento na nuvem:

![Demonstração da API](assets/FocusFlow.gif)

### 7.1 Como testar a API na prática (via cURL)
Para facilitar a avaliação, abaixo estão os comandos `curl` prontos para testar todas as rotas e a lógica de negócios da API pelo terminal.

*(Os exemplos abaixo apontam para o deploy no Render. Se estiver rodando o projeto localmente via `.devcontainer` ou nativo, basta substituir `https://focusflow-api-nlhc.onrender.com` por `http://localhost:8080`).*

**1. Cadastrar a primeira tarefa (Horário Livre)**

Este comando insere uma tarefa das 14:00 às 16:00. O parser do Haskell exige a chave `"id"`, mas passamos `0` pois o banco SQLite gera o ID real automaticamente.

```bash
curl -X POST https://focusflow-api-nlhc.onrender.com/api/tarefas -H "Content-Type: application/json" -d '{"id": 0, "titulo": "Estudar Paradigmas", "categoria": "Estudos", "inicio": "14:00", "fim": "16:00"}'
```

**2. Testar a Lógica Funcional (Forçar Conflito de Horários)**

Ao tentar cadastrar uma reunião que começa às 15:00, a função pura `temConflito` (do módulo `Logic.hs`) detecta a sobreposição com a tarefa anterior e bloqueia a inserção, retornando um erro 400.

```bash
curl -X POST https://focusflow-api-nlhc.onrender.com/api/tarefas -H "Content-Type: application/json" -d '{"id": 0, "titulo": "Reunião de Estágio", "categoria": "Trabalho", "inicio": "15:00", "fim": "17:00"}'
```

**3. Listar todas as tarefas (Verificar Banco de Dados)**

Retorna a lista completa de tarefas salvas para confirmar que a reunião conflitante realmente não foi gravada.

```bash
curl -X GET https://focusflow-api-nlhc.onrender.com/api/tarefas
```

**4. Deletar uma tarefa**

Para liberar o horário na agenda, basta deletar a tarefa passando o seu ID na URL (neste caso, deletando a tarefa de ID 1).

```bash
curl -X DELETE https://focusflow-api-nlhc.onrender.com/api/tarefas/1
```

## 8. Uso de IA

### 8.1 Ferramentas de IA utilizadas
Gemini 3.1 Pro (via Web) - Plano pago. Usei principalmente para me ajudar a traduzir as mensagens de erro gigantescas do compilador GHC e para me guiar nos erros de infraestrutura do Docker.

### 8.2 Interações relevantes com IA
**Interação 1**

Objetivo da consulta: Entender por que o GHC estava dando erro na palavra module no meu Main.hs.

Trecho do prompt ou resumo fiel: Mandei o log de erro: app/Main.hs:6:1: error: [GHC-58481] parse error on input 'module' junto com um print do topo do meu código.

O que foi aproveitado: A explicação de que os imports estavam acima da declaração do módulo e as pragmas de linguagem também estavam fora de ordem.

O que foi modificado ou descartado: Arrumar a ordem resolveu o problema na hora, não precisei mudar a lógica do meu código.

**Interação 2**

Objetivo da consulta: Tentar resolver o erro de build no Render dizendo que o arquivo cabal não existia.

Trecho do prompt ou resumo fiel: "failed to calculate checksum of ref... "/focusflow.cabal": not found"

O que foi aproveitado: A IA percebeu pelo erro que o problema era case-sensitivity no Linux do servidor. Meu repositório tinha letras maiúsculas. Mudei a linha COPY focusflow.cabal ./ no Dockerfile para COPY FocusFlow.cabal ./.

**Interação 3**

Objetivo da consulta: Descobrir o porquê do servidor cair (crash) imediatamente após subir no Render, sem dar erro de código no Haskell.

Trecho do prompt ou resumo fiel: Mandei um print do log do render que dizia focusflow-exe: <stdout>: commitBuffer: invalid argument e logo em seguida Exited with status 1.

O que foi aproveitado: A dica de adicionar ENV LANG=C.UTF-8 no Dockerfile. O container enxuto não entendia os acentos dos prints do meu código Haskell.

### 8.3 Exemplo de erro, limitação ou sugestão inadequada da IA
Enquanto eu configurava as rotas com o Scotty, deu um erro porque a função param (que pega o ID da URL) não estava sendo reconhecida. Pedi ajuda pra IA e ela sugeriu fazer um import diferente: import qualified Web.Scotty as S e usar S.param.
Fiz isso e continuou dando erro de escopo (Module 'Web.Scotty' does not export 'param'). Percebi que a sugestão da IA era furada porque o problema real era de versão. Nas versões mais novas do pacote do Scotty que o Render baixou, a função param não faz mais isso, ela foi substituída por pathParam (ou captureParam). A IA tava com as documentações desatualizadas na cabeça. Tive que olhar o erro, pesquisar na documentação atual do Scotty e ajustar na mão para tid <- pathParam "id".

### 8.4 Comentário pessoal sobre o processo envolvendo IA
Usar IA com Haskell é uma faca de dois gumes. Foi incrível para lidar com a infraestrutura (como os erros chatos do Docker, do Windows local e os bugs do Linux de UTF-8), que eram coisas que só iam roubar tempo do aprendizado principal. Ela também é muito boa pra "traduzir" as mensagens de erro do GHC, que muitas vezes não são intuitivas.
Por outro lado, notei que a IA se perde bastante em atualizações de pacotes e tipos. No caso do Scotty, ela tentou inventar imports mirabolantes para resolver um problema que era, na verdade, só uma função que tinha mudado de nome na biblioteca. Se eu não tivesse uma base da aula para desconfiar da sugestão dela, eu teria ficado preso num loop de erros.

## 9. Referências e créditos
Documentação do Scotty: https://hackage.haskell.org/package/scotty

Biblioteca SQLite Simple: https://hackage.haskell.org/package/sqlite-simple

Material das aulas de Paradigmas de Programação (UFSM) sobre funções de alta ordem (map, filter) e tipos de dados algébricos.

Documentação do Render para deploy com Docker.
