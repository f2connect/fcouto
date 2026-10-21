# F2 Conect · publicação com Supabase + Vercel

Pasta pronta para publicar. O sistema é um site estático (Vercel) que guarda tudo no Supabase (banco, login, anexos e sincronização em tempo real).

| Arquivo | Para que serve |
| --- | --- |
| `index.html` | O sistema inteiro: painel da F2 e portal do cliente (gestor e condutor) |
| `config.js` e `api/config.js` | Leem a URL e a chave pública do Supabase, que a integração Supabase ↔ Vercel preenche sozinha |
| `qrcode.js` | Gera o QR code de check-in de cada carro (biblioteca qrcode-generator, licença MIT) |
| `instalacao.sql` | Cria tabelas, regras de acesso, tempo real e a pasta de anexos no Supabase |
| `manifest.webmanifest`, `icon.svg` | Permitem instalar o site como app no celular |
| `vercel.json` | Cabeçalhos de segurança e cache para o Vercel |

## 1. Supabase (uma vez)

1. Crie uma conta em supabase.com e um projeto novo. Região: **South America (São Paulo)**.
2. Abra **SQL Editor → New query**, cole todo o conteúdo de `instalacao.sql` e clique **Run**.
3. Em **Project Settings → API**, copie **Project URL** e a chave **anon** (ou **publishable**).
4. Cole os dois em `config.js`. Nunca use a chave `service_role` / `secret`.
5. Em **Authentication → Sign In / Providers → Email**, decida sobre **Confirm email**:
   - ligado (mais seguro): cada pessoa confirma o e-mail pelo link antes de entrar;
   - desligado (mais simples para começar): a conta já entra direto, aguardando liberação da F2.

## 2. Vercel

**Opção A, pelo GitHub (recomendado, atualiza sozinho a cada mudança):**

1. Crie um repositório no GitHub e envie os arquivos desta pasta.
2. No Vercel: **Add New → Project → Import** o repositório.
3. Framework Preset: **Other**. Não há comando de build. Clique **Deploy**.

**Opção B, pela linha de comando:** com Node instalado, rode `npm i -g vercel`, entre nesta pasta e rode `vercel --prod`.

Depois de publicado, anote o endereço (ex.: `https://f2-conect.vercel.app`). Se quiser um domínio próprio, adicione em **Project → Settings → Domains**.

## 3. Ligar o endereço ao login

No Supabase, em **Authentication → URL Configuration**:

- **Site URL**: o endereço do Vercel.
- **Redirect URLs**: o mesmo endereço.

Sem isso, os links de confirmação e de "Esqueci minha senha" não voltam para o site.

## 4. Primeiro acesso

1. Abra o site e clique **Criar conta**. **A primeira conta criada vira Administrador.**
2. Cadastre o cliente Direção, os veículos e os contratos (com km contratado).
3. Gestores e condutores da Direção criam a própria conta pelo site. Elas aparecem como pendentes em **Configurações → Usuários**. Lá você define o perfil (gestor ou condutor), o cliente e ativa.
4. Para trazer o que foi cadastrado no painel de teste: lá, **Configurações → Exportar backup**; aqui, **Configurações → Importar backup**. Os PDFs e fotos do teste não vêm junto; reenvie pelos formulários.

## 5. Celular

Abra o site no celular e use **Adicionar à tela inicial** (Safari ou Chrome). Ele abre como app.

## Área do motorista e QR code (versão 2)

- Em cada veículo, no painel da F2 (ou na janela do veículo do gestor), o botão **QR code** abre o código para imprimir e colar no carro.
- O motorista aponta a câmera: se já tem conta, cai direto no check-in daquele carro; se não tem, cria a conta, preenche CPF, telefone e CNH, e o pedido vai para o **gestor do cliente**, que libera na aba **Motoristas**.
- Check-in e checkout registram km, foto do odômetro, fotos do carro, observação e localização (só naquele momento). A data e a hora vêm do servidor.
- O motorista também registra abastecimento (litros, valor, nota), vistoria com fotos (frente, traseira, laterais, painel), manutenção, problema, emergência, sinistro, reembolso e documentos.
- Manutenção preventiva: intervalos padrão em **Configurações**, ajustáveis por veículo. O app avisa quando está chegando e quando venceu.
- A F2 pode usar **Ver como cliente** no Painel para ver o app exatamente como o gestor ou o motorista, sem gravar nada.
- Ao atualizar uma instalação antiga, rode o `instalacao.sql` de novo no SQL Editor: ele só acrescenta o que falta.

## Perfis

| Perfil | Vê e faz |
| --- | --- |
| Administrador F2 | Tudo, inclusive configurações, usuários e auditoria |
| Operacional F2 | Frota, contratos, uso, vistorias, manutenção, multas, documentos |
| Financeiro F2 | Faturas, resultado, lançamentos, reembolsos |
| Gestor do cliente | Os veículos da própria empresa, contratos e franquias, uso, abastecimento, manutenção, faturas, multas, chamados, e libera os motoristas |
| Motorista (condutor) | Check-in/checkout, abastecimento, vistoria com fotos, km, manutenção, emergência, seguro e reembolso; não vê faturas |

O isolamento entre clientes é feito pelas regras do banco (Row Level Security): um cliente não consegue ler dados de outro nem chamando a API diretamente. Lançamentos financeiros internos e a auditoria nunca chegam ao cliente.

## Limites conhecidos desta versão

- O e-mail padrão do Supabase tem limite baixo de envios por hora. Para uso real, configure um SMTP próprio em **Authentication → Emails**.
- O plano gratuito do Supabase tem limites de uso e pode pausar projetos inativos. Confira em supabase.com/pricing antes de colocar em produção.
- Notificações chegam como avisos dentro do sistema. E-mail e WhatsApp automáticos ficam para a etapa 2.
- Depreciação, valor de mercado, índice de saúde, ponto ótimo de venda e simulador de compra seguem nas etapas 2 e 3 do Prompt-Mestre.
