## Modelo Relacional (MySQL)

```mermaid
%%{init: {"theme": "base", "themeVariables": {
  "primaryColor":        "#D6E8FA",
  "primaryTextColor":    "#1a2b3c",
  "primaryBorderColor":  "#7BAFD4",
  "lineColor":           "#94A3B8",
  "secondaryColor":      "#FDE8D0",
  "tertiaryColor":       "#D1F5F0",
  "edgeLabelBackground": "#F8FAFC",
  "fontFamily":          "monospace",
  "fontSize":            "13px"
}}}%%
erDiagram

    cliente {
        int         id_cliente    PK
        char(11)    cpf           UK
        char(14)    cnpj          UK "nullable"
        varchar(150) nome
        varchar(150) email        UK
        enum        segmento      "PF|PJ|MEI"
        datetime    criado_em
    }

    produto {
        int         id_produto    PK
        varchar(120) nome         UK
        enum        categoria     "CREDITO|INVESTIMENTO|SEGURO|CONTA"
        decimal     taxa_juros    "7,4"
        tinyint     ativo
    }

    tipo_transacao {
        int         id_tipo       PK
        varchar(60) descricao     UK
        tinyint     sinal         "+1 credito|-1 debito"
    }

    conta {
        int         id_conta      PK
        int         id_cliente    FK
        varchar(20) numero        UK
        enum        tipo_conta    "CORRENTE|POUPANCA|SALARIO|PAGAMENTO"
        decimal     saldo         "15,2"
        enum        status        "ATIVA|INATIVA|BLOQUEADA|ENCERRADA"
    }

    contratacao {
        int         id_contratacao   PK
        int         id_cliente       FK
        int         id_produto       FK
        date        data_contratacao
        enum        status           "ATIVA|CANCELADA|ENCERRADA|PENDENTE"
    }

    transacao {
        bigint      id_transacao     PK
        int         id_conta         FK
        int         id_produto       FK
        int         id_tipo          FK
        int         id_contratacao   FK "nullable"
        decimal     valor            "15,2"
        datetime    data_hora
        char(36)    id_idempotencia  UK "UUID v4"
    }

    cliente      ||--o{ conta          : "possui"
    cliente      ||--o{ contratacao    : "contrata"
    produto      ||--o{ contratacao    : "contratado em"
    produto      ||--o{ transacao      : "referenciado em"
    conta        ||--o{ transacao      : "origina"
    tipo_transacao ||--o{ transacao    : "classifica"
    contratacao  |o--o{ transacao      : "associada a"
```

## Modelo Cassandra (CQL — query-first)

> Sem JOIN, sem FK, sem AUTO_INCREMENT. Os dados são **desnormalizados**: uma
> tabela por padrão de acesso. `PK` = *partition key*, `CK` = *clustering column*.
> Linhas tracejadas indicam cópias denormalizadas da mesma entidade lógica.

```mermaid
%%{init: {"theme": "base", "themeVariables": {
  "primaryColor":        "#D1F5F0",
  "primaryTextColor":    "#1a2b3c",
  "primaryBorderColor":  "#5EBDB0",
  "lineColor":           "#94A3B8",
  "secondaryColor":      "#FDE8D0",
  "tertiaryColor":       "#D6E8FA",
  "edgeLabelBackground": "#F8FAFC",
  "fontFamily":          "monospace",
  "fontSize":            "13px"
}}}%%
erDiagram

    cliente_by_id {
        uuid      id_cliente PK
        text      cpf
        text      cnpj
        text      nome
        text      email
        text      segmento
        timestamp criado_em
    }
    cliente_by_cpf {
        text cpf        PK
        uuid id_cliente
        text nome
        text email
        text segmento
    }
    cliente_by_email {
        text email      PK
        uuid id_cliente
        text nome
        text cpf
    }

    produto_by_id {
        uuid    id_produto PK
        text    nome
        text    categoria
        decimal taxa_juros
        boolean ativo
    }
    produto_by_categoria {
        text    categoria  PK
        text    nome "CK"
        uuid    id_produto
        decimal taxa_juros
        boolean ativo
    }

    tipo_transacao {
        uuid    id_tipo   PK
        text    descricao
        tinyint sinal
    }

    conta_by_cliente {
        uuid    id_cliente PK
        uuid    id_conta "CK"
        text    numero
        text    tipo_conta
        decimal saldo
        text    status
    }
    conta_by_numero {
        text    numero     PK
        uuid    id_conta
        uuid    id_cliente
        text    tipo_conta
        decimal saldo
        text    status
    }

    contratacao_by_cliente {
        uuid id_cliente       PK
        date data_contratacao "CK"
        uuid id_produto "CK"
        uuid id_contratacao
        text status
    }
    contratacao_by_produto {
        uuid id_produto       PK
        date data_contratacao "CK"
        uuid id_cliente "CK"
        uuid id_contratacao
        text status
    }

    transacao_by_conta {
        uuid      id_conta        PK
        timestamp data_hora "CK"
        timeuuid  id_transacao "CK"
        uuid      id_produto
        uuid      id_tipo
        uuid      id_contratacao
        decimal   valor
        text      id_idempotencia
    }
    transacao_by_idempotencia {
        text      id_idempotencia PK
        timeuuid  id_transacao
        uuid      id_conta
        decimal   valor
        timestamp data_hora
    }
    transacao_by_produto {
        uuid      id_produto   PK
        timestamp data_hora "CK"
        timeuuid  id_transacao "CK"
        uuid      id_conta
        uuid      id_tipo
        decimal   valor
    }

    cliente_by_id          ||..|| cliente_by_cpf             : "denormaliza"
    cliente_by_id          ||..|| cliente_by_email           : "denormaliza"
    produto_by_id          ||..|| produto_by_categoria       : "denormaliza"
    conta_by_cliente       ||..|| conta_by_numero            : "denormaliza"
    contratacao_by_cliente ||..|| contratacao_by_produto     : "denormaliza"
    transacao_by_conta     ||..|| transacao_by_idempotencia  : "denormaliza"
    transacao_by_conta     ||..|| transacao_by_produto       : "denormaliza"
```

### De relacional para colunar

| Tabela relacional | Tabela(s) Cassandra | Padrão de acesso |
|---|---|---|
| `cliente` | `cliente_by_id`, `cliente_by_cpf`, `cliente_by_email` | busca por id e por chaves únicas |
| `produto` | `produto_by_id`, `produto_by_categoria` | por id e listagem por categoria |
| `tipo_transacao` | `tipo_transacao` | tabela de lookup |
| `conta` (1:N) | `conta_by_cliente`, `conta_by_numero` | contas de um cliente / por número |
| `contratacao` (N:N) | `contratacao_by_cliente`, `contratacao_by_produto` | as duas direções do N:N |
| `transacao` | `transacao_by_conta`, `transacao_by_idempotencia`, `transacao_by_produto` | extrato (série temporal), dedup, analítico |
