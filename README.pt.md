# SalaryTicker

<!-- language-bar -->
[English](README.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · **Português** · [Bahasa Melayu](README.ms.md)
<!-- language-bar -->

Um app de barra de menus para macOS que mostra quanto você já ganhou hoje, contando a cada segundo.

<img src="docs/panel.png" width="360" alt="O painel: o ganho de hoje, os valores por trás dele, o acumulado do mês e duas metas de poupança com as datas em que estarão pagas.">

Ele fica na barra de menus como um número e um pequeno anel de progresso. Clique nele para ver o detalhe do dia, o mês até agora e o quanto falta para aquilo que você está juntando.

- **Conta a cada segundo** de acordo com o seu horário real — jornada, almoço não remunerado, dias úteis.
- **Entende de folgas.** Feriados, folgas pagas e folgas sem pagamento caem em lugares diferentes, e a folga sem pagamento só mexe no salário base, nunca nos subsídios.
- **Mede preços em trabalho.** Uma meta aparece em dias de trabalho e na data em que o horário diz que ela estará paga, não só em dinheiro.
- **Nove idiomas**, qualquer símbolo de moeda, qualquer fuso horário IANA.
- **Sem conta, sem rede, sem telemetria.** Tudo é calculado no seu Mac a partir dos ajustes que você digitou.

## Instalação

Requer **macOS 14 ou posterior** e um toolchain Swift 6. Compilado e testado com o Swift 6.3; versões anteriores do Swift 6 não foram testadas.

```bash
git clone https://github.com/EnRui11/SalaryTicker.git
cd SalaryTicker
./Packaging/build_app.sh install
```

Isso compila um binário de release, gera o ícone do app a partir do código, monta o `SalaryTicker.app`, assina em modo ad-hoc, copia para `/Applications` e abre o app. Sem o argumento `install`, a compilação fica no diretório de trabalho e nada é instalado.

Não há nada para tirar da quarentena: você mesmo compilou o binário, então ele nunca carrega a marca de download que o Gatekeeper procura. A assinatura é ad-hoc, o que basta para um app compilado localmente e dá ao item de início uma identidade estável.

Para atualizar, faça o pull e rode o mesmo comando — ele substitui a cópia instalada e reabre o app. Os seus ajustes ficam fora do bundle e não são tocados.

Para desinstalar: use Sair no painel, apague `/Applications/SalaryTicker.app` e, se quiser eliminar também os ajustes, `defaults delete com.steve.salaryticker`.

## Primeira execução

A barra de menus mostra `Definir salário` até que o horário faça sentido. Abra **Ajustes** pelo painel e preencha três coisas:

1. **Aba Salário** — o seu salário base e qualquer subsídio fixo ao lado dele.
2. **Aba Horário** — entrada, saída e o almoço não remunerado.
3. **Aba Salário, Dias úteis** — em que dias da semana você trabalha e quais deles são de meio dia.

<img src="docs/settings.png" width="420" alt="A aba Salário: salário base, subsídios, a contagem de dias úteis do mês, o valor por hora derivado e a grade do mês para marcar folgas.">

Isso já basta para começar. Todo o resto é opcional.

## Como configurar

### Salário base e subsídios

Dois campos, porque um contracheque tem pelo menos duas linhas e as folgas tratam cada uma de um jeito:

- O **salário base** é a parte de onde sai a folga sem pagamento.
- Os **subsídios** são um valor mensal fixo — transporte, telefone — pago por inteiro, com ou sem folga sem pagamento.

Se você não recebe subsídio, deixe em zero e nada muda. Se recebe, separar os dois corretamente é o que impede que um dia de folga sem pagamento custe mais do que realmente custa.

### Dias úteis, feriados e folgas

Escolha os seus dias da semana e marque qualquer um deles como **meio dia** (um sábado de manhã, por exemplo) — ele conta pela metade em todo lugar.

Clique numa data da grade do mês para percorrer os estados: **dia útil → feriado pago → sem pagamento → dia útil**. As setas dos dois lados do título passam de um mês para outro, e o próprio título é o caminho de volta para hoje, então os feriados do ano que vem podem ser lançados antes de chegarem.

Os dois tipos de folga caem em lugares diferentes, e a diferença é justamente o que importa:

|                        | O que faz                                                                                                                                                                                                       |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Feriado **pago**       | Não custa nada. O mesmo salário agora cobre menos dias úteis, então cada dia que você *realmente* trabalha vale um pouco mais. Nada é contado no próprio feriado — a parte dele é carregada pelos outros dias. |
| Folga **sem pagamento** | Custa um dia de salário **base**. Os seus subsídios continuam chegando por inteiro.                                                                                                                          |

Uma consequência que vale conhecer: marcar como feriado pago um dia que **já passou** faz o acumulado do mês cair, porque a parte daquele dia agora precisa ser ganha nos dias que ainda faltam. No fim do mês, tudo volta a bater com o seu salário.

### Hora extra

Desligada por padrão. Ligada, ela continua contando depois da saída, com um multiplicador que você define.

Ela tem um **limite** — quatro horas por padrão, e nunca passa da meia-noite — porque o app não faz ideia de quando você realmente saiu. Sem um teto, um Mac deixado ligado a noite toda inventaria uma noite inteira de pagamento.

### Metas

Adicione as coisas que você está juntando dinheiro para comprar. Cada uma mostra quanto custa em **dias de trabalho** e a data em que o horário diz que ela estará paga. Ative Mostrar no painel nas que você quiser; as outras ficam em Ajustes.

**Reordene-os com as setas ao lado de cada um, ou arrastando.** Um ringgit só pode ser gasto uma vez, então os objetivos são financiados de cima para baixo: um objetivo só começa a encher depois de pagos os que estão acima, e a sua data inclui essa espera. O dinheiro já ganho para um objetivo fica lá — pôr um novo no topo não retira o que um mais antigo já recebeu.

A data **não se move enquanto você trabalha.** O que você ganha e o que o relógio faz avançam juntos, então seguir o seu horário cumpre a promessa em vez de adiá-la. A única coisa que a desloca é mudar o horário por baixo — marcar uma folga, tirar um dia útil, encurtar a jornada.

### A barra de menus

| Opção                           | O que faz                                                                                        |
| ------------------------------- | ------------------------------------------------------------------------------------------------ |
| Anel de progresso               | Um pequeno anel ao lado do número, que vai se enchendo ao longo do dia                           |
| Símbolo da moeda                | Mostre ou oculte, para recuperar um caractere de largura                                         |
| Apenas ícone fora do horário    | Encolhe o item quando o número não está andando — à noite, nos fins de semana, antes da entrada |
| **Ocultar valor**               | Tira o dinheiro da barra de menus até você pedir de volta, seja qual for a hora                  |

**Ocultar valor** é também o primeiro item do painel, a um clique da barra de menus, para quando uma chamada está começando ou alguém está lendo por cima do seu ombro. Ele nunca esconde *tudo* — o anel permanece, senão não sobraria nada em que clicar para trazer o número de volta.

### Abrir ao iniciar sessão

Exige que o app esteja rodando a partir de `/Applications`. O que fica guardado é o que você pediu: o app se registra na inicialização quando a opção está ligada e nunca cancela esse registro, porque o macOS lista apps de barra de menus como itens de início só por terem sido executados uma vez, e a resposta dele não é confiável em nenhum dos dois sentidos.

## Como o número é calculado

```
basic per day     = basic salary ÷ (scheduled days − paid leave)
allowance per day = allowance    ÷ (scheduled days − all leave)
per second        = (basic per day + allowance per day) ÷ paid seconds per day
today             = paid seconds elapsed today × per second
this month        = days already earned × daily pay + today
```

Os dois divisores são contados sobre o **mês real do calendário**, então um mês trabalhado por inteiro soma exatamente o seu salário, e a diária varia um pouco de mês para mês — agosto de 2026 tem 21 dias úteis, setembro tem 22, fevereiro de 2027 tem 20.

As horas pagas por dia vêm da entrada, da saída e do almoço. Não existe um campo separado de "horas por dia", então os dois nunca podem se contradizer.

### Não tem como acumular erro

Cada atualização recalcula a partir de `(settings, now)` e **não acumula nada**. Fechar a tampa, dormir, sair e reabrir, mudar o relógio do sistema, atravessar fusos horários de avião — nada disso pode deixar o número errado, porque não existe um total acumulado para dar errado.

O timer só diz "hora de redesenhar". Ele não conta, e desacelera para uma soneca de 20 segundos sempre que o número está congelado, o que acontece na maioria das noites e em todos os fins de semana.

### Não há botão de pausa, de propósito

A contagem satura nas duas pontas da janela paga: um instante antes do expediente vale zero, um instante depois vale um dia inteiro. Então o número **para sozinho depois da saída e zera sozinho à meia-noite** — não há timer para parar, nem estado para reiniciar.

Uma pausa manual existiu por pouco tempo. Era o único estado acumulado do app e a origem dos seus dois piores bugs: uma pausa deixada correndo a noite toda cobrava mais do que um dia inteiro de trabalho e zerava o dia seguinte, e uma pausa iniciada depois da saída fazia o total diário já fechado andar *para trás*. Apagar o recurso apagou a classe inteira de bugs.

## Limitações conhecidas

- **Sem turnos noturnos.** A saída precisa ser depois da entrada; caso contrário, o app diz "Configuração incompleta" em vez de mostrar um número errado.
- **Sem bônus.** Só um subsídio mensal fixo é modelado. Um pagamento eventual ou de fim de ano teria que ser diluído em um valor por segundo para aparecer aqui, e isso maquia o número em vez de descrevê-lo.
- **Sem imposto, EPF ou SOCSO.** Todos os valores são brutos.
- **Sem histórico.** O acumulado do mês é derivado do horário deste mês, não de um registro do que foi realmente trabalhado. Editar o seu salário ou o seu horário reprecifica os dias que já ficaram para trás no mês corrente.
- **Um único horário.** Um padrão que não seja semanal — sábados alternados, uma escala de turnos — não tem como ser expresso, a não ser marcando as exceções à mão.

## Desenvolvimento

```bash
swift build          # build
swift test           # 210 tests
./Packaging/build_app.sh    # assemble the .app without installing
```

Clean Architecture orientada a funcionalidades, um target SwiftPM por camada, para que a direção das dependências seja imposta pelo compilador, e não pela disciplina. As decisões de projeto, os invariantes do modelo de dinheiro e os bugs que os moldaram estão descritos em [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Licença

MIT — veja [LICENSE](LICENSE).
