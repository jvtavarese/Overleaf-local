# Overleaf Local no MacBook Apple Silicon (M1/M2/M3)

Este repositório existe para documentar uma instalação **real** do Overleaf Community Edition localmente em MacBook com Apple Silicon.

## Por que este repo foi criado

A instalação no macOS Apple Silicon não foi "clone e rodar": tivemos alguns pontos de fricção práticos (Docker, arquitetura de imagem e scripts do toolkit no macOS).

A ideia aqui é concentrar:

- passos diretos que funcionaram;
- comandos mais importantes do dia a dia;
- problemas reais que aconteceram e como resolver.

## Pré-requisitos

```bash
# Homebrew
brew --version

# Git
git --version

# Docker Desktop (instalado e aberto)
docker --version
docker compose version
```

Se faltar algo:

```bash
brew install coreutils
brew install --cask docker
open -a Docker
```

## Setup rápido (script)

Este repositório inclui um script para automatizar o setup no Apple Silicon:

```bash
chmod +x bootstrap.sh
./bootstrap.sh ~/Projetos/Overleaf
```

O script:

- clona o toolkit (se ainda não existir);
- roda `bin/init`;
- ajusta `MONGO_VERSION=8.0.0`;
- ajusta `SIBLING_CONTAINERS_ENABLED=false`;
- força `platform: linux/amd64` no `sharelatex`;
- aplica compatibilidade de parsing para macOS em `lib/shared-functions.sh`;
- sobe o ambiente com `bin/up -d`.

## Instalação (passo a passo)

```bash
# 1) Clone o toolkit oficial
cd ~/Projetos
git clone https://github.com/overleaf/toolkit.git Overleaf
cd Overleaf

# 2) Inicialize configuração local
bin/init
```

## Ajustes necessários para Apple Silicon

### 1) Garantir Mongo com tag válida

No arquivo `config/overleaf.rc`, manter algo como:

```bash
MONGO_IMAGE=mongo
MONGO_VERSION=8.0.0
```

### 2) Desabilitar sibling containers na Community Edition

No mesmo `config/overleaf.rc`:

```bash
SIBLING_CONTAINERS_ENABLED=false
```

### 3) Rodar imagem do Overleaf em amd64 (emulação)

A imagem `sharelatex/sharelatex` usada nesta instalação não tinha manifest arm64.

No arquivo `lib/docker-compose.base.yml`, no serviço `sharelatex`:

```yaml
sharelatex:
  image: "${IMAGE}"
  platform: linux/amd64
```

### 4) Compatibilidade de parsing no macOS (BSD `sed`)

Durante a validação de `MONGO_VERSION`, tivemos erro por parsing em script shell do toolkit (`sed -r` no macOS).

Na prática, a correção foi ajustar as funções de leitura em `lib/shared-functions.sh` para parsing compatível com macOS.

## Subir o Overleaf

```bash
cd ~/Projetos/Overleaf
bin/up -d
bin/docker-compose ps
```

Quando estiver de pé, acesse:

- <http://localhost/launchpad> (criar admin)
- <http://localhost/login>

## Comandos mais importantes

```bash
# Subir em background
bin/up -d

# Iniciar novamente (já com stack criada)
bin/start

# Parar
bin/stop

# Status dos serviços
bin/docker-compose ps

# Logs do web
bin/logs -f web

# Logs do mongo
bin/logs -f mongo
```

## Dificuldades reais que tivemos

1. `docker: command not found`
2. Docker Desktop instalado, mas daemon ainda não iniciado (`docker.sock` indisponível)
3. Erro de validação de `MONGO_VERSION`
4. Aviso de `SIBLING_CONTAINERS_ENABLED=true` na Community Edition
5. Erro de arquitetura: `no matching manifest for linux/arm64/v8` para `sharelatex/sharelatex`
6. Incompatibilidade de script shell do toolkit no macOS (parsing via `sed -r`)

## Estado final validado

- `mongo` saudável
- `redis` ativo
- `sharelatex` ativo na porta `127.0.0.1:80`
- criação de projeto testada (projeto "teste" persistido no Mongo)

## Observações

- Este guia é para ambiente local de estudo/desenvolvimento.
- Community Edition não oferece isolamento forte entre usuários como no Server Pro.
