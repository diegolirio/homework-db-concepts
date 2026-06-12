-- =====================================================================
-- Quantum Finance - Modelo Relacional (MySQL / InnoDB)
-- Normalizado ate a 3FN | Integridade referencial + ACID
-- MBA Data Architecture
-- =====================================================================

CREATE DATABASE IF NOT EXISTS quantum_finance
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;
USE quantum_finance;

-- ---------------------------------------------------------------------
-- CLIENTE  (profissional de saude: medico, dentista, fisioterapeuta)
-- ---------------------------------------------------------------------
CREATE TABLE cliente (
  id_cliente   INT          NOT NULL AUTO_INCREMENT,
  cpf          CHAR(11)     NOT NULL,
  cnpj         CHAR(14)     NULL,
  nome         VARCHAR(150) NOT NULL,
  email        VARCHAR(150) NOT NULL,
  segmento     ENUM('MEDICO','DENTISTA','FISIOTERAPEUTA','OUTRO') NOT NULL,
  criado_em    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_cliente       PRIMARY KEY (id_cliente),
  CONSTRAINT uq_cliente_cpf   UNIQUE (cpf),
  CONSTRAINT uq_cliente_cnpj  UNIQUE (cnpj),
  CONSTRAINT uq_cliente_email UNIQUE (email),
  CONSTRAINT ck_cliente_cpf   CHECK (CHAR_LENGTH(cpf) = 11)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- PRODUTO  (Score Hibrido, Kit Abertura PJ, Fluxo de Caixa IA, SaaS...)
-- ---------------------------------------------------------------------
CREATE TABLE produto (
  id_produto   INT          NOT NULL AUTO_INCREMENT,
  nome         VARCHAR(120) NOT NULL,
  categoria    ENUM('CREDITO','INVESTIMENTO','SAAS','SERVICO') NOT NULL,
  taxa_juros   DECIMAL(7,4) NOT NULL DEFAULT 0.0000,
  ativo        TINYINT(1)   NOT NULL DEFAULT 1,
  CONSTRAINT pk_produto      PRIMARY KEY (id_produto),
  CONSTRAINT uq_produto_nome UNIQUE (nome),
  CONSTRAINT ck_produto_taxa CHECK (taxa_juros >= 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- TIPO_TRANSACAO  (aquisicao, liquidacao, aporte, resgate, encargo...)
-- sinal: +1 entra credito na conta / -1 sai
-- ---------------------------------------------------------------------
CREATE TABLE tipo_transacao (
  id_tipo    INT         NOT NULL AUTO_INCREMENT,
  descricao  VARCHAR(60) NOT NULL,
  sinal      TINYINT     NOT NULL,
  CONSTRAINT pk_tipo        PRIMARY KEY (id_tipo),
  CONSTRAINT uq_tipo_desc   UNIQUE (descricao),
  CONSTRAINT ck_tipo_sinal  CHECK (sinal IN (-1, 1))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- CONTA  (1 cliente : N contas - PF e PJ)
-- ---------------------------------------------------------------------
CREATE TABLE conta (
  id_conta    INT           NOT NULL AUTO_INCREMENT,
  id_cliente  INT           NOT NULL,
  numero      VARCHAR(20)   NOT NULL,
  tipo_conta  ENUM('PF','PJ') NOT NULL,
  saldo       DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  status      ENUM('ATIVA','BLOQUEADA','ENCERRADA') NOT NULL DEFAULT 'ATIVA',
  CONSTRAINT pk_conta        PRIMARY KEY (id_conta),
  CONSTRAINT uq_conta_numero UNIQUE (numero),
  CONSTRAINT fk_conta_cliente FOREIGN KEY (id_cliente)
      REFERENCES cliente (id_cliente)
      ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_conta_saldo  CHECK (saldo >= -1000000.00)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- CONTRATACAO  (tabela associativa que resolve o N:N cliente x produto)
-- ---------------------------------------------------------------------
CREATE TABLE contratacao (
  id_contratacao   INT  NOT NULL AUTO_INCREMENT,
  id_cliente       INT  NOT NULL,
  id_produto       INT  NOT NULL,
  data_contratacao DATE NOT NULL,
  status           ENUM('ATIVA','SUSPENSA','LIQUIDADA','CANCELADA') NOT NULL DEFAULT 'ATIVA',
  CONSTRAINT pk_contratacao        PRIMARY KEY (id_contratacao),
  CONSTRAINT fk_contr_cliente FOREIGN KEY (id_cliente)
      REFERENCES cliente (id_cliente)
      ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_contr_produto FOREIGN KEY (id_produto)
      REFERENCES produto (id_produto)
      ON UPDATE CASCADE ON DELETE RESTRICT,
  -- impede a mesma dupla cliente+produto duplicada na mesma data
  CONSTRAINT uq_contr_unica UNIQUE (id_cliente, id_produto, data_contratacao)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- TRANSACAO  (registro integro: conta + produto + valor certos)
-- id_idempotencia garante NAO duplicidade da mesma transacao
-- ---------------------------------------------------------------------
CREATE TABLE transacao (
  id_transacao    BIGINT        NOT NULL AUTO_INCREMENT,
  id_conta        INT           NOT NULL,
  id_produto      INT           NOT NULL,
  id_tipo         INT           NOT NULL,
  id_contratacao  INT           NULL,
  valor           DECIMAL(15,2) NOT NULL,
  data_hora       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  id_idempotencia CHAR(36)      NOT NULL,
  CONSTRAINT pk_transacao        PRIMARY KEY (id_transacao),
  CONSTRAINT uq_transacao_idem   UNIQUE (id_idempotencia),
  CONSTRAINT fk_trans_conta FOREIGN KEY (id_conta)
      REFERENCES conta (id_conta)
      ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_trans_produto FOREIGN KEY (id_produto)
      REFERENCES produto (id_produto)
      ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_trans_tipo FOREIGN KEY (id_tipo)
      REFERENCES tipo_transacao (id_tipo)
      ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_trans_contr FOREIGN KEY (id_contratacao)
      REFERENCES contratacao (id_contratacao)
      ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT ck_trans_valor CHECK (valor > 0)
) ENGINE=InnoDB;

-- Indices de apoio para consultas operacionais
CREATE INDEX ix_conta_cliente   ON conta (id_cliente);
CREATE INDEX ix_contr_cliente   ON contratacao (id_cliente);
CREATE INDEX ix_contr_produto   ON contratacao (id_produto);
CREATE INDEX ix_trans_conta     ON transacao (id_conta);
CREATE INDEX ix_trans_produto   ON transacao (id_produto);
CREATE INDEX ix_trans_data      ON transacao (data_hora);
