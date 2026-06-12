-- =====================================================================
-- Quantum Finance - Modelo Cassandra (CQL)
-- Conversao do modelo relacional (quantum_finance_ddl.sql) para colunar
-- MBA Data Architecture
-- =====================================================================
--
-- DIFERENCAS-CHAVE em relacao ao modelo relacional (MySQL):
--   * Nao existe JOIN  -> os dados sao DESNORMALIZADOS (replicados por consulta)
--   * Nao existe FK    -> integridade referencial e responsabilidade da app
--   * Nao existe AUTO_INCREMENT -> usamos UUID / TIMEUUID como chave
--   * Nao existe UNIQUE arbitrario -> unicidade vem da PARTITION KEY
--   * Modelagem e QUERY-FIRST: uma tabela por padrao de acesso
--
-- Para cada entidade criamos tabelas espelhando as consultas necessarias.
-- =====================================================================


-- ---------------------------------------------------------------------
-- KEYSPACE
-- ---------------------------------------------------------------------
CREATE KEYSPACE IF NOT EXISTS quantum_finance
  WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 3};

USE quantum_finance;


-- =====================================================================
-- CLIENTE
-- Relacional: PK id_cliente; UNIQUE cpf, cnpj, email
-- Em Cassandra precisamos de uma tabela por forma de busca.
-- =====================================================================

-- Busca por id_cliente (acesso principal)
CREATE TABLE IF NOT EXISTS cliente_by_id (
    id_cliente  uuid,
    cpf         text,
    cnpj        text,
    nome        text,
    email       text,
    segmento    text,        -- MEDICO | DENTISTA | FISIOTERAPEUTA | OUTRO
    criado_em   timestamp,
    PRIMARY KEY (id_cliente)
);

-- Busca por CPF (garante unicidade logica via partition key)
CREATE TABLE IF NOT EXISTS cliente_by_cpf (
    cpf         text,
    id_cliente  uuid,
    nome        text,
    email       text,
    segmento    text,
    PRIMARY KEY (cpf)
);

-- Busca por e-mail (login / unicidade logica)
CREATE TABLE IF NOT EXISTS cliente_by_email (
    email       text,
    id_cliente  uuid,
    nome        text,
    cpf         text,
    PRIMARY KEY (email)
);


-- =====================================================================
-- PRODUTO
-- Relacional: PK id_produto; UNIQUE nome
-- Consultas: por id e listagem por categoria.
-- =====================================================================

CREATE TABLE IF NOT EXISTS produto_by_id (
    id_produto  uuid,
    nome        text,
    categoria   text,        -- CREDITO | INVESTIMENTO | SAAS | SERVICO
    taxa_juros  decimal,
    ativo       boolean,
    PRIMARY KEY (id_produto)
);

-- Listar produtos por categoria, ordenados por nome
CREATE TABLE IF NOT EXISTS produto_by_categoria (
    categoria   text,
    nome        text,
    id_produto  uuid,
    taxa_juros  decimal,
    ativo       boolean,
    PRIMARY KEY ((categoria), nome)
);


-- =====================================================================
-- TIPO_TRANSACAO
-- Tabela pequena e de referencia (lookup). sinal: +1 credito / -1 debito
-- =====================================================================

CREATE TABLE IF NOT EXISTS tipo_transacao (
    id_tipo     uuid,
    descricao   text,
    sinal       tinyint,     -- 1 = credito, -1 = debito
    PRIMARY KEY (id_tipo)
);


-- =====================================================================
-- CONTA
-- Relacional: 1 cliente : N contas; UNIQUE numero
-- Consultas: contas de um cliente e busca de conta por numero.
-- =====================================================================

-- Todas as contas de um cliente (relacao 1:N denormalizada)
CREATE TABLE IF NOT EXISTS conta_by_cliente (
    id_cliente  uuid,
    id_conta    uuid,
    numero      text,
    tipo_conta  text,        -- PF | PJ
    saldo       decimal,
    status      text,        -- ATIVA | BLOQUEADA | ENCERRADA
    PRIMARY KEY ((id_cliente), id_conta)
);

-- Busca direta de conta por numero (unicidade logica)
CREATE TABLE IF NOT EXISTS conta_by_numero (
    numero      text,
    id_conta    uuid,
    id_cliente  uuid,
    tipo_conta  text,
    saldo       decimal,
    status      text,
    PRIMARY KEY (numero)
);


-- =====================================================================
-- CONTRATACAO  (resolve N:N cliente x produto)
-- Consultas: contratacoes de um cliente e contratacoes de um produto.
-- =====================================================================

-- Contratacoes de um cliente, mais recentes primeiro
CREATE TABLE IF NOT EXISTS contratacao_by_cliente (
    id_cliente        uuid,
    data_contratacao  date,
    id_produto        uuid,
    id_contratacao    uuid,
    status            text,   -- ATIVA | SUSPENSA | LIQUIDADA | CANCELADA
    PRIMARY KEY ((id_cliente), data_contratacao, id_produto)
) WITH CLUSTERING ORDER BY (data_contratacao DESC, id_produto ASC);

-- Contratacoes de um produto (visao inversa)
CREATE TABLE IF NOT EXISTS contratacao_by_produto (
    id_produto        uuid,
    data_contratacao  date,
    id_cliente        uuid,
    id_contratacao    uuid,
    status            text,
    PRIMARY KEY ((id_produto), data_contratacao, id_cliente)
) WITH CLUSTERING ORDER BY (data_contratacao DESC, id_cliente ASC);


-- =====================================================================
-- TRANSACAO  (serie temporal - alto volume)
-- Relacional: PK id_transacao; UNIQUE id_idempotencia
-- Padrao classico de time-series: particiona por conta, ordena por data.
-- =====================================================================

-- Extrato de uma conta: transacoes mais recentes primeiro
CREATE TABLE IF NOT EXISTS transacao_by_conta (
    id_conta        uuid,
    data_hora       timestamp,
    id_transacao    timeuuid,
    id_produto      uuid,
    id_tipo         uuid,
    id_contratacao  uuid,
    valor           decimal,
    id_idempotencia text,
    PRIMARY KEY ((id_conta), data_hora, id_transacao)
) WITH CLUSTERING ORDER BY (data_hora DESC, id_transacao DESC);

-- Deduplicacao / idempotencia: garante que a mesma transacao nao repita
CREATE TABLE IF NOT EXISTS transacao_by_idempotencia (
    id_idempotencia text,
    id_transacao    timeuuid,
    id_conta        uuid,
    valor           decimal,
    data_hora       timestamp,
    PRIMARY KEY (id_idempotencia)
);

-- Transacoes por produto (analitico)
CREATE TABLE IF NOT EXISTS transacao_by_produto (
    id_produto      uuid,
    data_hora       timestamp,
    id_transacao    timeuuid,
    id_conta        uuid,
    id_tipo         uuid,
    valor           decimal,
    PRIMARY KEY ((id_produto), data_hora, id_transacao)
) WITH CLUSTERING ORDER BY (data_hora DESC, id_transacao DESC);


-- =====================================================================
-- DADOS DE EXEMPLO
-- =====================================================================

-- Cliente (replicado nas 3 tabelas de cliente)
INSERT INTO cliente_by_id    (id_cliente, cpf, cnpj, nome, email, segmento, criado_em)
  VALUES (uuid(), '12345678901', '12345678000199', 'Dra. Ana Souza', 'ana@clinica.com', 'MEDICO', toTimestamp(now()));
INSERT INTO cliente_by_cpf   (cpf, id_cliente, nome, email, segmento)
  VALUES ('12345678901', uuid(), 'Dra. Ana Souza', 'ana@clinica.com', 'MEDICO');
INSERT INTO cliente_by_email (email, id_cliente, nome, cpf)
  VALUES ('ana@clinica.com', uuid(), 'Dra. Ana Souza', '12345678901');

-- Produto
INSERT INTO produto_by_id        (id_produto, nome, categoria, taxa_juros, ativo)
  VALUES (uuid(), 'Score Hibrido', 'CREDITO', 2.5000, true);
INSERT INTO produto_by_categoria (categoria, nome, id_produto, taxa_juros, ativo)
  VALUES ('CREDITO', 'Score Hibrido', uuid(), 2.5000, true);

-- Tipo de transacao
INSERT INTO tipo_transacao (id_tipo, descricao, sinal) VALUES (uuid(), 'Aporte',     1);
INSERT INTO tipo_transacao (id_tipo, descricao, sinal) VALUES (uuid(), 'Liquidacao', -1);


-- =====================================================================
-- CONSULTAS DE EXEMPLO
-- =====================================================================
-- SELECT * FROM cliente_by_cpf  WHERE cpf = '12345678901';
-- SELECT * FROM conta_by_cliente WHERE id_cliente = <uuid>;
-- SELECT * FROM produto_by_categoria WHERE categoria = 'CREDITO';
-- SELECT * FROM transacao_by_conta   WHERE id_conta = <uuid>;          -- extrato
-- SELECT * FROM transacao_by_conta   WHERE id_conta = <uuid>
--        AND data_hora >= '2026-01-01' AND data_hora < '2026-02-01';   -- por periodo
-- SELECT * FROM transacao_by_idempotencia WHERE id_idempotencia = '<uuid-v4>';
