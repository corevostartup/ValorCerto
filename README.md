# ValorCerto (MVP)

Projeto com app iOS nativo em `iOS` e backend serverless para deploy no Netlify.

## Estrutura

- `iOS/`: app SwiftUI (iPhone)
- `netlify/functions/`: endpoints serverless (Node.js)
- `web/`: página simples publicada pelo Netlify
- `netlify.toml`: configuração de build, functions e redirects

## Endpoints disponíveis

- `GET /api/health`
- `POST /api/price-check`

Exemplo de payload:

```json
{
  "barcode": "7891000315507",
  "user_price": 12.9
}
```

## Rodar localmente

Pré-requisitos:

- Node 18+
- npm

Instalação e execução:

```bash
npm install
npm run dev
```

O Netlify Dev vai expor:

- Site: `http://localhost:8888`
- API: `http://localhost:8888/api/health`

## Publicar no GitHub

1. Verifique o remote:

```bash
git remote -v
```

2. Ajuste staging e commit:

```bash
git add .
git commit -m "chore: setup iOS repo and Netlify serverless backend"
```

3. Envie para o GitHub:

```bash
git push -u origin main
```

## Deploy no Netlify

1. Crie um novo site a partir do repositório no GitHub.
2. Build command: `npm run build`
3. Publish directory: `web/dist`
4. Functions directory: `netlify/functions` (já definido em `netlify.toml`)
5. Deploy.

Após deploy, endpoints:

- `https://SEU-SITE.netlify.app/api/health`
- `https://SEU-SITE.netlify.app/api/price-check`

## Integração no iOS

No app Swift, aponte seu `URLSession` para a URL do Netlify:

- Base URL produção: `https://SEU-SITE.netlify.app/api`
- Endpoint principal: `/price-check`

