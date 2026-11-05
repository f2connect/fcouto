# F2 Conect · publicação com Supabase + Vercel

Pasta pronta para publicar. O sistema é um site estático (Vercel) que guarda tudo no Supabase (banco, login, anexos e sincronização em tempo real).

| Arquivo | Para que serve |
| --- | --- |
| `index.html` | O sistema inteiro: painel da F2, portal do cliente (gestor e condutor) e o modelo do contrato |
| `api/agente.js` | O assistente de chat: confere quem está logado e conversa com a IA (Google Gemini gratuito, ou Claude se preferir). A chave fica só na Vercel |
| `config.js` e `api/config.js` | Leem a URL e a chave pública do Supabase, que a integração Supabase ↔ Vercel preenche sozinha |
| `qrcode.js` | Gera o QR code de check-in de cada carro (biblioteca qrcode-generator, licença MIT) |
| `instalacao.sql` | Cria tabelas, regras de acesso, tempo real e a pasta de anexos no Supabase (a versão 6 acrescenta o item 10: sugestões de melhoria do cliente) |
| `manifest.webmanifest`, `icon.svg` | Permitem instalar o site como app no celular |
| `vercel.json` | Cabeçalhos de segurança e cache para o Vercel |

## Versão 15: km do mês

- Nova tela Veículos → **Km do mês**: todos os carros numa lista, com o último km e um campo para o km de hoje. Salva tudo de uma vez e não aceita km menor que o último.
- A partir do dia 5 (ajustável em Configurações → Avisos e prazos), o Painel mostra a pendência "Km do mês não lançado" com as placas que faltam. Clicar na pendência abre a tela.

## Versão 14: quem pagou a manutenção

- No formulário de manutenção, logo depois do valor, o campo "Quem pagou": F2 ou Cliente. F2 vira conta paga no custo do carro; Cliente fica só no histórico (aparece "pago pelo cliente" nas Últimas trocas). Trocar de F2 para Cliente cancela a conta ligada.
- O formulário ficou mais curto: saíram chamado de origem, entrada/liberação da oficina e próxima por data/km (o quadro calcula sozinho).

## Versão 13: só a F2, contas numa tela e últimas trocas

- Modo interno: saíram a área do cliente, a área do motorista, check-in/checkout, QR code, abastecimento e chamados. Quem abre /cliente ou /motorista vê "Área desativada". Nada foi apagado: para religar, trocar `SO_F2 = true` para `false` no index.html.
- Menu: Painel, Clientes, Veículos, Contratos · Faturas, Contas a pagar, Resultado · Configurações (Melhorias e Histórico de alterações ficam dentro de Configurações).
- Contas a pagar junta fixas e variáveis. Ao lançar uma conta de um carro, dá para marcar o tipo de manutenção (pneus, bateria, alinhamento, óleo, revisão, freios...) com data e km: a troca entra no histórico do carro e o km é atualizado. Editar a manutenção atualiza a mesma conta.
- Cada carro mostra o quadro "Últimas trocas" (pneus a cada 30.000 km ou 5 anos, bateria a cada 2 anos, alinhamento, óleo e revisão), com botão "Registrar troca". Os prazos ficam em Configurações → Manutenção preventiva.
- Gerar fatura pede o km atual do carro (opcional); não aceita km menor que o último registrado.

## Versão 12: painel enxuto e clicável

- Cada cartão do Painel abre a tela correspondente: Clientes, Frota (Veículos), Contratos ativos, Faturas e Contas a pagar. Os do mês (Faturado, Custos e Resultado) abrem Faturas e Resultado.
- Saiu do Painel o que não serve na fase de cadastro: "A receber até o fim dos contratos", "Capital na frota" (continua em Rentabilidade), o gráfico vazio, a lista repetida de carros e o controle de km sem franquia.
- O bloco do mês, o gráfico, "Em uso agora" e "Controle de km" só aparecem quando há dados.
- As abas "Rentabilidade por carro" e "Clientes e risco" aparecem sozinhas quando houver faturas/contas lançadas e 2 ou mais clientes com contrato.

## Versão 11: limpeza e correções

- Painel: a frota mostra quantos carros há em cada situação (a soma bate com o total). "A receber" agora mostra "—" quando os contratos são mensais sem prazo e diz o valor por mês. "Capital na frota" avisa quando falta o preço de compra dos carros. O mês mostra "Faturado" e o aluguel previsto lado a lado.
- Pendências novas: carro "em preparação", "à venda" ou "vendido" que ainda tem contrato ativo; e fatura do mês anterior não emitida.
- Rentabilidade: não aponta "melhor" e "pior" carro enquanto não houver faturas ou custos lançados.
- Menu: "Contratos a receber" passou a se chamar "Faturas".
- Venda de carro: se o carro tiver contrato ativo, o contrato é encerrado automaticamente na data da venda (antes dava erro).
- Campos de valor e de km aceitam o jeito brasileiro: 54.190 ou 54.190,00 viram cinquenta e quatro mil. Antes, digitar 54.190 gravava R$ 54,19.
- Configurações em 5 abas, com textos simples: Usuários, Avisos e prazos, Manutenção preventiva, Quem paga o quê e Backup. Saíram as informações técnicas (endereço do banco, importador antigo).

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

### Ligar o assistente de graça (Google Gemini)

Enquanto não houver chave, o botão **Assistente** fica escondido e nada é cobrado.

1. Entre em **aistudio.google.com** com uma conta Google (a da F2, de preferência).
2. Clique em **Get API key** → **Create API key** e copie a chave.
3. Na **Vercel**, abra o projeto **f2-conect** → **Settings** → **Environment Variables** → **Add**:
   - Key: `GEMINI_API_KEY`
   - Value: cole a chave
   - Marque Production, Preview e Development e clique em **Save**.
4. Em **Deployments**, clique nos três pontinhos do mais recente → **Redeploy**.
5. Abra o site: o botão **Assistente** aparece no canto da tela.

Não precisa cadastrar cartão. Cuidados do plano gratuito:

- Tem limite de mensagens por minuto e por dia. Quando passar, o assistente avisa e volta a funcionar depois.
- No plano gratuito, o Google pode usar as conversas para melhorar os produtos dele. Evite colar no chat dados sensíveis (o assistente já não envia CPF nem número de CNH).

Opcional, pago: para usar o Claude no lugar do Gemini, apague `GEMINI_API_KEY` e crie `ANTHROPIC_API_KEY` com uma chave de console.anthropic.com (cobrança por uso). Para desligar o assistente, apague a variável e faça Redeploy.

## Contratos e documento para assinatura (versão 10)

- Novo menu **Contratos**, separado de Configurações: lista dos contratos, modelos de plano e o **modelo do contrato** (texto da minuta v3).
- O cadastro do contrato tem todos os campos do quadro-resumo: plano (mensal, semestral, anual ou 24 meses), aluguel, vencimento, caução, reajuste, franquia de km (mensal **cumulativa**, mensal não cumulativa ou total), km excedente e valor acima de 30% da franquia, seguro e franquias de sinistro, despesas do cliente, taxas, local de devolução e condições especiais. Tudo editável. O número do contrato é gerado sozinho (F2-2026-001…).
- O cadastro do cliente ganhou representante legal, cargo e CPF, que vão para o contrato.
- Botão **Documento** (em Contratos, na aba Contrato de cada carro e nos contratos do cliente): mostra o contrato preenchido, avisa os dados que faltam (em amarelo) e baixa em **Word (.docx)** ou abre para **imprimir / salvar em PDF**. Envie ao cliente para assinar e depois anexe o PDF assinado em Editar → Contrato assinado.
- **Modelo do contrato:** o administrador pode editar o texto em Contratos → Modelo do contrato. Campos entre chaves duplas, como `{{aluguel}}`, são preenchidos sozinhos. Há um botão para voltar ao modelo padrão.
- **Franquia cumulativa no controle de km e na fatura:** o km não usado passa para os meses seguintes; o excedente só é cobrado quando o saldo acumulado fica negativo. Se houver valor para o km acima de 30% da franquia, a fatura separa as duas faixas.

## Despesas fixas e rendimento de cada carro (versão 9)

- Dentro de cada carro, a aba **Rendimento** mostra o faturamento mensal (aluguel do contrato), as despesas fixas do carro e quanto ele **rende por mês** (faturamento − despesas fixas). Também mostra o rendimento descontando a média dos custos variáveis e o valor faturado no mês.
- Botões prontos para lançar **Consórcio**, **Seguro** ou qualquer outra despesa fixa. Elas viram contas a pagar todo mês sozinhas, em Contas fixas.
- **Consórcio com 2 carros:** marque **Dividir com outro carro**, escolha o segundo carro e a porcentagem (padrão: metade para cada). A conta é uma só (um boleto), e o custo vai metade para cada carro no resultado.
- Despesas que se repetem **uma vez por ano** (IPVA, licenciamento, seguro à vista) entram no rendimento divididas por 12.
- Se o cadastro do carro tiver parcela de consórcio que ainda não está nas despesas fixas, o sistema avisa e lança com um clique.
- O cartão de cada carro em **Veículos** e a aba **Rentabilidade por carro** do Painel mostram o "rende por mês". O assistente também responde ("quanto rende o RTA1B23?").

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
