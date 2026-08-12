const express = require('express');
const cors = require('cors');
const OpenAI = require('openai');

const app = express();
const PORT = 3000;

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'InvestMind Backend',
  });
});

app.post('/api/analyze', async (req, res) => {
  try {
    const data = req.body;

    if (
      !data ||
      !data.company ||
      !data.company.symbol
    ) {
      return res.status(400).json({
        status: 'error',
        message: 'Не передан company.symbol',
      });
    }

    const response = await openai.responses.create({
      model: 'gpt-5.6',

      instructions: `
Ты — аналитический модуль InvestMind Deep Analysis.

Тебе передаются структурированные данные компании:

company:
- symbol
- name
- industry
- marketCapitalization

market:
- currentPrice
- dailyChangePercent

technical:
- изменение цены за период
- волатильность
- максимальная просадка
- MA20
- MA50
- сила тренда
- наклон тренда
- Technical Score
- технические сильные стороны и риски

fundamental:
- P/E
- Forward P/E
- P/S
- EPS
- рост EPS
- рост выручки
- валовая маржа
- чистая маржа
- ROE
- Current Ratio
- Beta
- 52-недельный максимум и минимум
- Fundamental Score
- Growth Score
- Profitability Score
- Valuation Score
- Financial Health Score
- Fundamental Risk Score
- фундаментальные сильные стороны и риски

investMind:
- итоговый Combined Score
- общий рейтинг
- веса Technical и Fundamental

Твоя задача — сделать единый анализ компании,
объединяя техническое состояние акции
и фундаментальное состояние бизнеса.

Правила:

1. Используй только переданные данные.
2. Не выдумывай новости, отчётность, прогнозы аналитиков
   или любые отсутствующие показатели.
3. Не давай прямых рекомендаций покупать или продавать.
4. Не обещай будущую доходность.
5. Отделяй сильный бизнес от дорогой оценки.
6. Высокий рост не должен автоматически означать хорошую оценку.
7. Высокий P/E или P/S рассматривай как риск оценки,
   особенно если valuationScore низкий.
8. Высокую Beta и волатильность учитывай как рыночный риск.
9. Technical Score и Fundamental Score могут противоречить друг другу.
   Если это происходит — обязательно объясни конфликт.
10. Combined Score используй как итоговую количественную оценку,
    но не повторяй его механически.
11. Пиши простым, понятным русским языком.
12. Не используй Markdown.
13. Не добавляй поля, которых нет в заданной JSON-структуре.

summary:
Дай краткий общий вывод о бизнесе, оценке,
технической картине и риске.

strengths:
Выбери наиболее важные сильные стороны
из технических и фундаментальных данных.

risks:
Выбери наиболее важные риски.
Особое внимание уделяй дорогой оценке,
низкой прибыльности, слабому тренду,
волатильности и высокой Beta.

watch:
Укажи конкретные показатели,
за которыми инвестору стоит следить дальше.

confidence:
Показывает уверенность в качестве общего анализа
на основании полноты и согласованности переданных данных.

Снижай confidence, если:
- Technical и Fundamental Score сильно расходятся;
- технические сигналы противоречат друг другу;
- valuationScore очень низкий при сильном росте;
- волатильность или Beta очень высокие;
- часть фундаментальных показателей отсутствует или равна 0.

Не повышай confidence только потому,
что Combined Score высокий.
`,

      input: JSON.stringify(data, null, 2),

      text: {
        format: {
          type: 'json_schema',
          name: 'investmind_deep_analysis',
          strict: true,

          schema: {
            type: 'object',

            properties: {
              summary: {
                type: 'string',
              },

              strengths: {
                type: 'array',
                items: {
                  type: 'string',
                },
              },

              risks: {
                type: 'array',
                items: {
                  type: 'string',
                },
              },

              watch: {
                type: 'array', items: {
                  type: 'string',
                },
              },

              confidence: {
                type: 'integer',
                minimum: 0,
                maximum: 100,
              },
            },

            required: [
              'summary',
              'strengths',
              'risks',
              'watch',
              'confidence',
            ],

            additionalProperties: false,
          },
        },
      },
    });

    const analysis = JSON.parse(
      response.output_text,
    );

    console.log(
     `Deep Analysis выполнен для ${ data.company.symbol }`,
    );

    res.json({
      status: 'ok',
      message: 'InvestMind Deep Analysis завершён',
      analysis: analysis,
    });
  } catch (error) {
    console.error(
      'OpenAI error:',
      error,
    );

    res.status(500).json({
      status: 'error',
      message:
        error?.message ??
        'Не удалось выполнить Deep Analysis',
    });
  }
});

app.listen(PORT, () => {
  console.log(
    `InvestMind Backend запущен на порту ${ PORT }`,
  );
});