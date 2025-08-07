# Projeto Gamma - Domínio e Regras de Negócio

Este documento descreve o domínio, os perfis de usuário, as entidades principais e as regras de negócio do Sistema de Logística.

## Perfis de Usuário (User Roles)

- **`ADMIN`**: Acesso total ao sistema, incluindo gerenciamento de usuários, armazéns, caminhões, rotas e configurações gerais.
- **`DISPATCHER`**: Responsável pela criação de remessas, planejamento de envios e alocação de pacotes às rotas.
- **`DRIVER`**: Pode visualizar as remessas associadas às suas rotas e atualizar o status dessas remessas durante o transporte.

---

## Entidades Principais (Core Entities)

- **User**: Usuários autenticados no sistema, com papéis (roles) associados que definem seus níveis de acesso e permissões.
- **Warehouse**: Representa os armazéns físicos de origem e destino das remessas.
- **Truck**: Veículo utilizado para o transporte, com atributos como placa, capacidade máxima de carga e status (ex: `AVAILABLE`, `UNDER_MAINTENANCE`, `INACTIVE`).
- **Route**: Rota lógica planejada entre um armazém de origem e um de destino, com um caminhão específico vinculado e status (ex: `ACTIVE`, `INACTIVE`).
- **MapRoute**: Detalhamento geográfico de uma `Route`, contendo coordenadas reais, distância e tempo estimado de percurso, obtidos através de uma API de mapas.
- **Shipment**: Representa uma remessa, que é um conjunto de pacotes a serem transportados de uma origem para um destino. Possui um status (ex: `PENDING_VALIDATION`, `AWAITING_DISPATCH`, `IN_TRANSIT`, `DELIVERED`, `CANCELLED`, `VALIDATION_FAILED`, `DELIVERY_FAILED`) e um custo de frete (`freightCost`).
- **Package**: Pacotes individuais que compõem uma remessa, cada um com descrição, peso e identificador único. Pode ter um status de inventário (ex: `IN_WAREHOUSE`, `ALLOCATED_TO_SHIPMENT`, `IN_TRANSIT`).
- **ShipmentStatusHistory**: Registro cronológico de todas as alterações de status de uma remessa, incluindo quem alterou e quando.
- **EventMessage**: Estrutura padrão para mensagens trocadas de forma assíncrona através das filas de eventos (e.g., para auditoria, notificações, processamento de tarefas).
- **Notification**: Registro de notificações enviadas aos usuários do sistema.

---

## Regras de Negócio (Business Rules)

### Regra #001 - Criação de Remessa (Shipment Creation)

**Objetivo:** Permitir que `DISPATCHER` ou `ADMIN` cadastrem uma nova remessa com pacotes vinculados a uma rota.

**Regras:**

1.  Apenas usuários com perfil `DISPATCHER` ou `ADMIN` podem criar remessas.
2.  A remessa deve conter ao menos um pacote.
3.  O peso total dos pacotes da remessa não pode exceder a capacidade máxima de carga do caminhão (`Truck`) alocado à rota (`Route`).
4.  A rota selecionada deve:
    - Estar previamente cadastrada e com status `ACTIVE`.
    - Ter um caminhão vinculado com status `AVAILABLE`.
5.  O status inicial da remessa deve ser `PENDING_VALIDATION`.
6.  Cada pacote (`Package`) da remessa deve conter:
    - Descrição textual clara do conteúdo.
    - Peso em quilogramas (deve ser > 0 kg).
    - Um identificador único para o pacote.
7.  A criação da remessa dispara um evento (ex: `SHIPMENT_CREATION_REQUESTED`) para uma fila. Este evento acionará uma validação assíncrona (ver Regra #009) para confirmar a alocação na rota.

---

### Regra #002 - Rastreamento de Remessa (Shipment Tracking)

**Objetivo:** Permitir a consulta do status atual e do histórico de movimentações de uma remessa por meio de um código de rastreamento.

**Regras:**

1.  O código de rastreamento deve ser único, seguro e gerado automaticamente para cada remessa.
2.  A consulta de rastreamento pode ser pública (acessível sem autenticação) ou restrita a usuários autenticados, conforme configuração do sistema.
3.  A resposta da consulta deve incluir:
    - O status atual da remessa (ex: `AWAITING_DISPATCH`, `IN_TRANSIT`, `DELIVERED`).
    - O histórico completo de status (`ShipmentStatusHistory`), com data/hora de cada alteração e, se aplicável, o usuário ou sistema responsável.
    - Informações básicas da remessa (ex: origem, destino, data prevista de entrega, se aplicável).
4.  Se o acesso público estiver habilitado, deve-se considerar uma camada de segurança adicional (ex: rate limiting por IP).

---

### Regra #003 - Atualização de Status de Remessa (Shipment Status Update)

**Objetivo:** Permitir que `DRIVER`s atualizem o status da remessa à medida que ela progride na rota de entrega.

**Regras:**

1.  Apenas o `DRIVER` atualmente vinculado à rota da remessa pode atualizar seu status.
2.  Os status válidos e suas transições devem ser claramente definidos. Exemplo de fluxo:
    - `AWAITING_DISPATCH` -> `IN_TRANSIT`
    - `AWAITING_DISPATCH` -> `CANCELLED`
    - `IN_TRANSIT` -> `DELIVERED`
    - `IN_TRANSIT` -> `DELIVERY_FAILED` (com motivo obrigatório)
    - `IN_TRANSIT` -> `CANCELLED` (ex: em caso de problemas maiores na rota, com justificativa)
    - `DELIVERY_FAILED` -> `IN_TRANSIT` (para nova tentativa, se aplicável)
    - `DELIVERY_FAILED` -> `AWAITING_RETURN` (se for retornar ao remetente/armazém)
    - `DELIVERED` (estado final)
    - `CANCELLED` (estado final)
3.  Cada mudança de status deve ser registrada na entidade `ShipmentStatusHistory`.
4.  Não é permitido pular etapas obrigatórias do fluxo de status sem justificativa ou permissão específica.
5.  Atualizações de status disparam eventos (ex: `SHIPMENT_STATUS_UPDATED`) para uma fila, que podem ser consumidos para auditoria e notificações.

---

### Regra #004 - Planejamento de Rota (Route Planning)

**Objetivo:** Permitir que `ADMIN` ou `DISPATCHER` criem e gerenciem rotas lógicas disponíveis para o envio de remessas.

**Regras:**

1.  Uma rota (`Route`) deve obrigatoriamente conter:
    - Um armazém de origem (`Warehouse`).
    - Um armazém de destino (`Warehouse`).
    - Um caminhão (`Truck`) alocado para realizar o transporte nessa rota.
    - Um status (ex: `ACTIVE`, `INACTIVE`).
2.  Um caminhão (`Truck`) com status `AVAILABLE` pode estar alocado a apenas uma rota `ACTIVE` por vez.
3.  A capacidade de carga total da rota é determinada pela capacidade do caminhão associado. O sistema deve auxiliar no controle de ocupação da rota.
4.  Uma rota lógica (`Route`) deve estar vinculada a uma rota geográfica (`MapRoute`) que contém os detalhes do percurso.

---

### Regra #005 - Cadastro de Armazéns (Warehouse Management)

**Objetivo:** Permitir a criação e manutenção da infraestrutura de armazéns.

**Regras:**

1.  Apenas usuários com perfil `ADMIN` podem cadastrar, editar ou remover armazéns.
2.  Armazéns (`Warehouse`) devem possuir no mínimo:
    - Nome ou identificação.
    - Endereço completo (incluindo cidade e UF).
    - Um código único identificador.

---

### Regra #006 - Criação e Gerenciamento de Usuários (User Management)

**Objetivo:** Permitir a criação e o controle de acesso dos diferentes perfis de usuários ao sistema.

**Regras:**

1.  Apenas usuários com perfil `ADMIN` podem registrar novos usuários no sistema.
2.  Cada usuário (`User`) deve estar associado a um dos perfis definidos (`ADMIN`, `DISPATCHER`, `DRIVER`).
3.  O login será realizado através de um endpoint específico (`/auth/login`) que, em caso de sucesso, retornará um JSON Web Token (JWT).
4.  O JWT terá um tempo de expiração definido e deverá ser enviado no header `Authorization` (Bearer token) em requisições subsequentes a endpoints protegidos.

---

### Regra #007 - Auditoria de Ações (Action Auditing)

**Objetivo:** Registrar ações sensíveis e importantes realizadas no sistema para fins de rastreabilidade e segurança.

**Regras:**

1.  As seguintes ações (tipos de evento de auditoria) devem ser auditadas:
    - `SHIPMENT_CREATED`, `SHIPMENT_UPDATED`, `SHIPMENT_CANCELLED`
    - `SHIPMENT_STATUS_CHANGED` (detalhando de/para status)
    - `USER_LOGIN_SUCCESS`, `USER_LOGIN_FAILED`
    - `USER_CREATED`, `USER_UPDATED`, `USER_ROLE_CHANGED`
    - `ROUTE_CREATED`, `ROUTE_UPDATED`, `ROUTE_DELETED`
    - `TRUCK_CREATED`, `TRUCK_UPDATED`, `TRUCK_STATUS_CHANGED`
    - `WAREHOUSE_CREATED`, `WAREHOUSE_UPDATED`, `WAREHOUSE_DELETED`
2.  Os logs de auditoria devem conter, no mínimo:
    - ID do usuário que realizou a ação (ou "system" para ações automatizadas).
    - Timestamp (data e hora exata) da ocorrência.
    - Tipo de ação realizada (conforme lista acima).
    - Dados relevantes da operação (ex: ID da entidade afetada, valores antigos e novos se aplicável).
3.  O registro de auditoria deve ser feito de forma assíncrona, enviando um `EventMessage` para uma fila dedicada.

---

### Regra #008 - Geração Automática de Rota Geográfica (Geographic Route Generation)

**Objetivo:** Gerar automaticamente o trajeto geográfico (`MapRoute`) com base nas coordenadas dos armazéns de origem e destino de uma rota lógica (`Route`), utilizando uma API externa de mapas.

**Regras:**

1.  A rota geográfica (`MapRoute`) é gerada (ou recuperada de um cache) automaticamente quando uma rota lógica (`Route`) é criada ou quando seus armazéns de origem/destino são alterados.
2.  As informações de endereço dos armazéns são convertidas em coordenadas geográficas para consulta na API de mapas.
3.  A resposta da API de mapas externa deve fornecer, no mínimo: lista de coordenadas, distância estimada e tempo estimado de percurso.
4.  Falha na geração da `MapRoute` pode marcar a `Route` como `INACTIVE` ou com status `PENDING_GEOROUTE` e notificar o `ADMIN`.

---

### Regra #009 - Processamento Assíncrono de Tarefas com Filas (Asynchronous Task Processing with Queues)

**Objetivo:** Utilizar filas de mensagens para processar tarefas de forma assíncrona, melhorando a responsividade, escalabilidade e resiliência.

**Regras:**

1.  A criação de uma remessa (Regra #001.7) dispara o evento `SHIPMENT_CREATION_REQUESTED` para uma fila.
2.  Um worker (consumidor da fila) processará este evento para:
    - Validar a capacidade do caminhão na rota (considerando concorrência e peso/volume de outras remessas já alocadas para a mesma viagem/rota).
    - Verificar disponibilidade e status da rota e do caminhão.
    - Atualizar o status da remessa para `AWAITING_DISPATCH` (se validação OK) ou para `VALIDATION_FAILED` (com motivo) e disparar notificação (Regra #010).
3.  Atualizações de status de remessas (Regra #003.5) disparam o evento `SHIPMENT_STATUS_UPDATED` para processamento de auditoria e notificações.
4.  Falhas no processamento de mensagens devem ser tratadas com _retry_ e DLQ (Dead Letter Queue).
5.  Ações de auditoria (Regra #007.3) e envio de notificações (Regra #010) também devem ser processadas via eventos e filas.

---

### Regra #010 - Notificações do Sistema (System Notifications)

**Objetivo:** Manter os usuários informados proativamente sobre eventos relevantes e críticos no sistema.

**Regras:**

1.  O sistema deve gerar notificações para os seguintes eventos e destinatários:
    - **`DISPATCHER` / `ADMIN`**:
      - Falha na validação de remessa (`SHIPMENT_VALIDATION_FAILED`).
      - Remessa marcada como `DELIVERY_FAILED`.
      - Falha na geração de `MapRoute`.
    - **`DRIVER`**:
      - Nova remessa alocada à sua rota ativa.
      - Alterações significativas em rotas atribuídas.
    - **`ADMIN`**:
      - Mensagens acumuladas na DLQ.
      - Erros críticos do sistema.
    - **(Opcional) Cliente Final**:
      - Remessa `IN_TRANSIT` (com código de rastreio).
      - Remessa `DELIVERED`.
      - Remessa `DELIVERY_FAILED` (com instruções).
2.  As notificações podem ser entregues por diferentes canais, configuráveis (ex: e-mail, dashboard interno do sistema).
3.  O conteúdo da notificação deve ser claro, conciso e incluir links ou informações relevantes para a ação necessária.
4.  Usuários devem poder gerenciar suas preferências de notificação (se aplicável).
5.  O envio de notificações deve ser assíncrono, utilizando filas.

---

### Regra #011 - Gerenciamento de Falhas na Entrega e Devoluções (Delivery Failure and Returns Management)

**Objetivo:** Definir o processo para lidar com remessas que não puderam ser entregues ao destinatário final.

**Regras:**

1.  Um `DRIVER` pode atualizar o status de uma remessa para `DELIVERY_FAILED`, devendo obrigatoriamente informar um motivo padronizado (ex: `RECIPIENT_ABSENT`, `ADDRESS_INCORRECT`, `GOODS_DAMAGED`, `RECIPIENT_REFUSED`).
2.  Uma remessa com status `DELIVERY_FAILED` deve:
    - Registrar o motivo e a tentativa de entrega.
    - Disparar uma notificação para `DISPATCHER` ou `ADMIN` para acompanhamento.
3.  O sistema deve permitir o registro de múltiplas tentativas de entrega para uma mesma remessa, se aplicável.
4.  Após um número limite de tentativas de entrega sem sucesso, ou por decisão do `DISPATCHER`, a remessa pode ser encaminhada para:
    - Retorno ao armazém de origem (status `AWAITING_RETURN` ou `RETURNING_TO_ORIGIN`).
    - Redirecionamento para um novo endereço (se aplicável, gerando uma nova etapa de transporte).
    - Descarte ou outra destinação, conforme regras de negócio específicas do cliente.
5.  O fluxo de devolução também deve ter seus status rastreados (ex: `RETURNED_TO_WAREHOUSE`).

---

### Regra #012 - Gerenciamento e Manutenção de Caminhões (Truck Management and Maintenance)

**Objetivo:** Rastrear e gerenciar o status e a manutenção dos caminhões para garantir sua disponibilidade operacional e segurança.

**Regras:**

1.  Apenas usuários com perfil `ADMIN` podem cadastrar, editar ou remover caminhões (`Truck`).
2.  Caminhões (`Truck`) devem possuir, além dos campos básicos (placa, capacidade):
    - Um status operacional: `AVAILABLE`, `UNDER_MAINTENANCE`, `INACTIVE`.
    - (Opcional) Data da última manutenção, próxima manutenção prevista.
3.  Apenas caminhões com status `AVAILABLE` podem ser alocados a novas rotas (`Route`) ativas.
4.  Ao mudar o status de um caminhão para `UNDER_MAINTENANCE` ou `INACTIVE`:
    - Se o caminhão estiver alocado a uma rota `ACTIVE` com remessas `AWAITING_DISPATCH` ou `PENDING_VALIDATION`, o `ADMIN`/`DISPATCHER` deve ser notificado para reatribuir as remessas/rota a outro caminhão.
    - Rotas que dependiam exclusivamente deste caminhão podem precisar ser temporariamente desativadas.

---

### Regra #013: Cálculo de Custo de Frete (Freight Cost Calculation)

**Objetivo:** Calcular automaticamente o custo de frete para uma remessa no momento de sua criação ou planejamento.

**Regras:**

1.  O cálculo do custo de frete deve ser acionado durante a criação da remessa (`Shipment`).
2.  A lógica de cálculo deve ser encapsulada em um **Serviço de Domínio** (ex: `FreightCalculatorService`), garantindo que a regra complexa não sobrecarregue a entidade `Shipment`.
3.  O cálculo deve levar em consideração múltiplos fatores, como:
    - **Peso e Dimensões:** Peso real ou peso cúbico (o maior dos dois).
    - **Distância:** Baseado na distância calculada na `MapRoute` associada.
    - **Tipo de Serviço:** Tabelas de preço diferentes para serviços (ex: `STANDARD`, `EXPRESS`, `URGENT`).
    - **Fatores Adicionais:** Taxas configuráveis como sobretaxa de combustível, taxa para área remota, seguro da carga.
4.  O resultado do cálculo deve ser um **Objeto de Valor `Money`**, contendo valor e moeda, para evitar imprecisões com tipos `float`.
5.  O custo calculado (`freightCost`) deve ser armazenado na entidade `Shipment` para referência futura e faturamento.

---

### Regra #014: Consolidação de Remessas em Rotas (Shipment Consolidation)

**Objetivo:** Otimizar o uso da capacidade dos caminhões permitindo que uma única viagem/rota contenha múltiplas remessas.

**Regras:**

1.  O sistema deve tratar uma `Route` ativa como uma "viagem" ou "manifesto" de um caminhão, que pode ser carregado com múltiplas remessas.
2.  Um `DISPATCHER` pode alocar diferentes remessas (`Shipment`) à mesma instância de rota ativa.
3.  A cada tentativa de alocação, o sistema deve validar se a capacidade restante do caminhão (em peso e/ou volume) é suficiente para a nova remessa, considerando todas as outras remessas já consolidadas naquela viagem.
4.  A alocação deve ser bloqueada se a capacidade for excedida.
5.  O sistema pode oferecer uma interface de planejamento para o `DISPATCHER` visualizar a ocupação das rotas ativas e facilitar a decisão de consolidação.
6.  (Avançado) Se a rota for multi-stop (A -> B -> C), o sistema deve gerenciar o embarque e desembarque de remessas em cada ponto, ajustando a capacidade disponível dinamicamente.

---

### Regra #015: Controle de Inventário de Pacotes no Armazém (Warehouse Package Inventory)

**Objetivo:** Manter um registro dos pacotes que estão fisicamente em cada armazém antes de serem alocados a uma remessa.

**Regras:**

1.  Esta regra introduz um fluxo alternativo/avançado: os pacotes (`Package`) podem ser registrados no sistema com um status `IN_WAREHOUSE` e associados a um `Warehouse` específico antes da criação da remessa.
2.  Ao criar uma `Shipment`, o `DISPATCHER` poderá selecionar pacotes que já existem no inventário do armazém de origem.
3.  Quando um pacote é alocado a uma remessa, seu status deve mudar de `IN_WAREHOUSE` para `ALLOCATED_TO_SHIPMENT`.
4.  O sistema deve impedir que um mesmo pacote seja alocado a mais de uma remessa ativa.
5.  Quando o status da remessa muda para `IN_TRANSIT`, o status de todos os seus pacotes deve ser atualizado para `IN_TRANSIT` também, removendo-os efetivamente do inventário do armazém de origem.
6.  O sistema deve fornecer uma visão do inventário de pacotes para cada armazém.
