# README

## Setup
```
make build
make bash
ruby console.rb
rake db:migrate
```

**Setup credentials**
https://console.cloud.google.com/

- Crie um novo projeto ou selecione um projeto existente.
- No menu lateral, vá para "APIs & Services" > "Credentials".
- Clique em "Create credentials" e selecione "OAuth client ID".
- Escolha "Web application" como o tipo de aplicativo.
- Em "Authorized redirect URIs", adicione a URL de retorno após a autenticação. Por exemplo, http://localhost:4567/auth/google_oauth2/callback para desenvolvimento local.
- Após criar as credenciais, o GOOGLE_CLIENT_ID e GOOGLE_CLIENT_SECRET serão exibidos. Copie-os e substitua 'GOOGLE_CLIENT_ID' e 'GOOGLE_CLIENT_SECRET' no arquivo ```.env```.

Você também vai precisar configurar as credenciais abaixo no arquivo .env:
Exemplo:
```
SESSION_SECRET=your_secret_key
COOKIE_SECRET='your_secret_key123456789012345678901234567890123456789012345678901234567890'
```

## To run application
```
make server
```

## To generate 
Add the keys above in .env:
- PRIMARY_KEY
- DETERMINISTIC_KEY
- KEY_DERIVATION_SALT

To generate them:
```rake db:encryption:init```

## Tests
```
rspec spec
```
