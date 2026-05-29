-- ============================================================
-- DDL extraído do diagrama ER
-- ============================================================

CREATE TABLE cliente (
    id_cliente  INT            NOT NULL AUTO_INCREMENT,
    cpf         CHAR(11)       NOT NULL,
    cnpj        CHAR(14)       NULL,
    nome        VARCHAR(150)   NOT NULL,
    email       VARCHAR(150)   NOT NULL,
    segmento    ENUM('PF','PJ','MEI') NOT NULL,
    criado_em   DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_cliente),
    UNIQUE KEY uq_cliente_cpf   (cpf),
    UNIQUE KEY uq_cliente_cnpj  (cnpj),
    UNIQUE KEY uq_cliente_email (email)
);

CREATE TABLE produto (
    id_produto  INT             NOT NULL AUTO_INCREMENT,
    nome        VARCHAR(120)    NOT NULL,
    categoria   ENUM('CREDITO','INVESTIMENTO','SEGURO','CONTA') NOT NULL,
    taxa_juros  DECIMAL(7,4)    NOT NULL DEFAULT 0.0000,
    ativo       TINYINT(1)      NOT NULL DEFAULT 1,
    PRIMARY KEY (id_produto),
    UNIQUE KEY uq_produto_nome (nome)
);

CREATE TABLE tipo_transacao (
    id_tipo     INT             NOT NULL AUTO_INCREMENT,
    descricao   VARCHAR(60)     NOT NULL,
    sinal       TINYINT         NOT NULL COMMENT '1 = crédito, -1 = débito',
    PRIMARY KEY (id_tipo),
    UNIQUE KEY uq_tipo_descricao (descricao)
);

CREATE TABLE conta (
    id_conta    INT             NOT NULL AUTO_INCREMENT,
    id_cliente  INT             NOT NULL,
    numero      VARCHAR(20)     NOT NULL,
    tipo_conta  ENUM('CORRENTE','POUPANCA','SALARIO','PAGAMENTO') NOT NULL,
    saldo       DECIMAL(15,2)   NOT NULL DEFAULT 0.00,
    status      ENUM('ATIVA','INATIVA','BLOQUEADA','ENCERRADA') NOT NULL DEFAULT 'ATIVA',
    PRIMARY KEY (id_conta),
    UNIQUE KEY uq_conta_numero (numero),
    CONSTRAINT fk_conta_cliente FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente)
);

CREATE TABLE contratacao (
    id_contratacao   INT    NOT NULL AUTO_INCREMENT,
    id_cliente       INT    NOT NULL,
    id_produto       INT    NOT NULL,
    data_contratacao DATE   NOT NULL,
    status           ENUM('ATIVA','CANCELADA','ENCERRADA','PENDENTE') NOT NULL DEFAULT 'ATIVA',
    PRIMARY KEY (id_contratacao),
    UNIQUE KEY uq_contratacao (id_cliente, id_produto, data_contratacao),
    CONSTRAINT fk_contratacao_cliente FOREIGN KEY (id_cliente) REFERENCES cliente  (id_cliente),
    CONSTRAINT fk_contratacao_produto FOREIGN KEY (id_produto) REFERENCES produto  (id_produto)
);

CREATE TABLE transacao (
    id_transacao    BIGINT          NOT NULL AUTO_INCREMENT,
    id_conta        INT             NOT NULL,
    id_produto      INT             NOT NULL,
    id_tipo         INT             NOT NULL,
    id_contratacao  INT             NULL,
    valor           DECIMAL(15,2)   NOT NULL,
    data_hora       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_idempotencia CHAR(36)        NOT NULL COMMENT 'UUID v4',
    PRIMARY KEY (id_transacao),
    UNIQUE KEY uq_transacao_idempotencia (id_idempotencia),
    CONSTRAINT fk_transacao_conta        FOREIGN KEY (id_conta)       REFERENCES conta        (id_conta),
    CONSTRAINT fk_transacao_produto      FOREIGN KEY (id_produto)     REFERENCES produto      (id_produto),
    CONSTRAINT fk_transacao_tipo         FOREIGN KEY (id_tipo)        REFERENCES tipo_transacao (id_tipo),
    CONSTRAINT fk_transacao_contratacao  FOREIGN KEY (id_contratacao) REFERENCES contratacao  (id_contratacao)
);
