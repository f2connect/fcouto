# F2 Conect · publicação com Supabase + Vercel

Pasta pronta para publicar. O sistema é um site estático (Vercel) que guarda tudo no Supabase (banco, login, anexos e sincronização em tempo real).

| Arquivo | Para que serve |
| --- | --- |
| `index.html` | O sistema inteiro: painel da F2 e portal do cliente (gestor e condutor) |
| `api/agente.js` | O assistente de chat: confere quem está logado e conversa com o Claude (Anthropic). A chave fica só na Vercel |
| `config.js` e `api/config.js` | Leem a URL e a chave pública do Supabase, que a integração Supabase ↔ Vercel preenche sozinha |
| `qrcode.js` | Gera o QR code de check-in de cada carro (biblioteca qrcode-generator, licença MIT) |
| `instalacao.sql` | Cria tabelas, regras de acesso, tempo real e a pasta de anexos no Supabase (a versão 6 acrescenta o item 10: sugestões de melhoria do cliente) |
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

## Assistente de chat (versões 5 e 6)

Botão **Assistente** no canto da tela, na Área da F2 e na Área do cliente (administrativo do cliente). O motorista não vê o assistente.

- **Conhece o sistema inteiro:** explica qualquer tela ou regra (fatura, franquia de km, centro de custo, recorrências, check-in, perfis) e responde com os números do próprio sistema.
- **Faz pelo chat o que as telas fazem:** lança contas, abastecimentos, manutenções, chamados, multas, documentos, motoristas, clientes, veículos e contratos; altera registros (situação de chamado, aprovar reembolso, encerrar contrato, corrigir valor); exclui com motivo; paga contas; registra recebimento e cancela faturas; aprova ou recusa km adicional; libera ou bloqueia motoristas; verifica leituras e vistorias; abre check-in, checkout, uso esquecido, QR code e emissão de fatura.
- **Confirmação com um clique:** ele mostra um cartão com o que vai fazer e só grava quando você clica em **Confirmar**. O botão **Abrir formulário** permite revisar antes. Quando precisa de foto ou nota fiscal, ele abre o formulário já preenchido para você anexar.
- **Melhorias:** durante as conversas, o assistente anota sozinho sugestões para melhorar o sistema (algo que ele não consegue fazer, um processo repetido à mão, um dado que falta, um erro). Elas ficam em **Sistema → Melhorias**, com prioridade e situação. Aprove as que valem a pena e use **Copiar lista para o Claude** para me mandar e eu implementar.
- Vê apenas o que o usuário já vê nas telas. O administrativo do cliente só consulta a frota da empresa dele; o perfil operacional não acessa o financeiro.

### Ligar o assistente (uma vez)

1. Entre em **console.anthropic.com** (o endereço pode abrir como **platform.claude.com**) e crie a conta da F2.
2. Em **Billing**, coloque crédito (o uso é cobrado por mensagem; cada pergunta custa alguns centavos).
3. Em **API Keys**, clique em **Create Key**, dê o nome `F2 Conect` e copie a chave (começa com `sk-ant-`). Ela só aparece uma vez.
4. Na **Vercel**, abra o projeto **f2-conect** → **Settings** → **Environment Variables** → **Add**:
   - Key: `ANTHROPIC_API_KEY`
   - Value: cole a chave
   - Marque Production, Preview e Development e clique em **Save**.
5. Ainda na Vercel, vá em **Deployments**, clique nos três pontinhos do mais recente → **Redeploy**.
6. Abra o site, clique em **Assistente** e pergunte "como está a empresa este mês?".

A chave nunca vai para o navegador nem para o GitHub. Para trocar o modelo, crie a variável `ANTHROPIC_MODEL` (padrão: `claude-sonnet-5-5`). Para desligar o assistente, apague a variável `ANTHROPIC_API_KEY` e faça Redeploy.

## Painel completo (versão 5)

O Painel tem quatro abas:

- **Visão geral:** clientes, frota, aluguel mensal, total a receber, faturas em aberto, receita, custo fixo, custo variável, resultado do mês, gráfico de 6 meses e pendências.
- **Rentabilidade por carro:** ranking dos carros pelo resultado acumulado desde a compra, com receita, custos, margem, custo por km, aluguel ÷ preço do carro, retorno sobre a compra e estimativa de quantos meses faltam para o carro se pagar. Mostra os carros sem contrato. Exporta CSV.
- **Fluxo de caixa:** previsão dos próximos 6 meses com as faturas em aberto, os aluguéis que ainda serão faturados, as contas a pagar e as fixas recorrentes. Dá para informar o saldo em conta de hoje para ver o saldo acumulado.
- **Clientes e risco:** receita de 12 meses, concentração (quanto cada cliente representa do aluguel mensal), atrasos, pontualidade, contratos terminando em 90 dias, multas a repassar e um nível de risco (baixo, médio, alto) com o motivo.

As abas de rentabilidade e fluxo de caixa aparecem só para Administrador e Financeiro.

## Menu da Área da F2 (versão 4)

- **Painel:** resumo de tudo (veja as abas acima): clientes ativos, frota, aluguel mensal, total a receber até o fim dos contratos (estimado), faturas em aberto, receita, custo fixo, custo variável e resultado do mês, gráfico dos últimos 6 meses e pendências.
- **Clientes:** os clientes com contrato ativo. Dentro de cada um: resumo com os carros do contrato, contratos (e pedidos de km), motoristas, faturas e chamados.
- **Veículos:** busca por placa, modelo, cliente ou situação. Dentro de cada carro: contrato, uso e check-in, quilometragem, abastecimento, vistorias, manutenções, chamados e reembolsos, documentos e seguros, multas, financeiro e histórico.
- **Financeiro:** contratos a receber (faturas), contas fixas, contas variáveis e resultado. Cada conta tem um **centro de custo**: a placa do carro ou **Administrativo**. O tipo (fixa ou variável) é escolhido em cada conta.
- **Contas fixas recorrentes:** cadastradas uma vez (valor e dia do vencimento) e geradas sozinhas todo mês. É só marcar como paga.
- Manutenção paga pela F2, documento pago (IPVA, seguro, licenciamento) e reembolso pago viram uma conta no centro de custo do carro automaticamente.
- **Resultado:** por centro de custo, com receita das faturas emitidas e custos das contas do mês (pagas ou a pagar). O caixa operacional mostra só o que foi recebido e pago; compra de veículos aparece à parte.

## Três áreas separadas (versão 3)

| Endereço | Quem usa | O que tem |
| --- | --- | --- |
| `/f2` | Equipe da F2 | Painel interno completo |
| `/cliente` | Administrativo da empresa cliente | Carros, contratos e franquias, uso, abastecimento, manutenção, faturas, multas, chamados e liberação dos motoristas |
| `/motorista` | Motorista | Check-in e checkout com km, abastecimento (nota e litros), vistoria por foto e chamado de manutenção |

- O endereço principal (`/`) mostra as três opções. Quem já está conectado vai direto para a sua área.
- Cada conta só entra na sua área. Se entrar pela porta errada, o sistema avisa e mostra o botão para a área certa.
- O motorista não vê valores, contratos, faturas, multas, documentos nem dados de outros motoristas. Isso é bloqueado no banco (Row Level Security), não só na tela.
- Preço de compra, consórcio e venda dos carros ficam num registro separado (`veiculos_fin`), visível só para a F2. Os modelos de plano (preços) também.

## QR code e cadastro do motorista

- Em cada veículo, no painel da F2 (ou na janela do veículo do gestor), o botão **QR code** abre o código para imprimir e colar no carro.
- O motorista aponta a câmera: se já tem conta, cai direto no check-in daquele carro; se não tem, cria a conta, preenche CPF, telefone e CNH, e o pedido vai para o **gestor do cliente**, que libera na aba **Motoristas**.
- Check-in e checkout registram km, foto do odômetro, fotos do carro, observação e localização (só naquele momento). A data e a hora vêm do servidor.
- Manutenção preventiva: intervalos padrão em **Configurações**, ajustáveis por veículo. O app avisa quando está chegando e quando venceu.
- Ao atualizar uma instalação antiga, rode o `instalacao.sql` de novo no SQL Editor: ele só acrescenta o que falta.

## Perfis

| Perfil | Vê e faz |
| --- | --- |
| Administrador F2 | Tudo, inclusive configurações, usuários e auditoria |
| Operacional F2 | Frota, contratos, uso, vistorias, manutenção, multas, documentos |
| Financeiro F2 | Faturas, resultado, lançamentos, reembolsos |
| Gestor do cliente | Os veículos da própria empresa, contratos e franquias, uso, abastecimento, manutenção, faturas, multas, chamados, e libera os motoristas |
| Motorista (condutor) | Check-in/checkout com km, abastecimento, vistoria com fotos e chamado de manutenção; não vê valores nem contratos |

O isolamento entre clientes é feito pelas regras do banco (Row Level Security): um cliente não consegue ler dados de outro nem chamando a API diretamente. Lançamentos financeiros internos e a auditoria nunca chegam ao cliente.

## Limites conhecidos desta versão

- O e-mail padrão do Supabase tem limite baixo de envios por hora. Para uso real, configure um SMTP próprio em **Authentication → Emails**.
- O plano gratuito do Supabase tem limites de uso e pode pausar projetos inativos. Confira em supabase.com/pricing antes de colocar em produção.
- Notificações chegam como avisos dentro do sistema. E-mail e WhatsApp automáticos ficam para a etapa 2.
- Depreciação, valor de mercado, índice de saúde, ponto ótimo de venda e simulador de compra seguem nas etapas 2 e 3 do Prompt-Mestre.
