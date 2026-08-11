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

    if (!data || !data.symbol) {
      return res.status(400).json({
        status: 'error',
        message: 'Не передан symbol',
      });
    }

    const response = await openai.responses.create({
      model: 'gpt-5.6',

      instructions: `
Ты — аналитический модуль InvestMind.

Твоя задача — объяснить пользователю переданные
количественные показатели акции.

Правила:

1. Используй только переданные данные.
2. Не выдумывай новости, отчётность или фундаментальные показатели.
3. Не давай прямых рекомендаций покупать или продавать.
4. Не обещай будущую доходность.
5. Учитывай, что InvestMind Score пока является
   технической оценкой, а не полной оценкой бизнеса.
6. Пиши простым и понятным русским языком.
7. Не используй Markdown.
8. Не добавляй поля, которых нет в заданной структуре.

Поле confidence показывает уверенность именно
в качестве технического вывода на основании переданных данных.

Не завышай confidence, если:
- сила тренда низкая;
- волатильность высокая;
- показатели противоречат друг другу.
`,

      input: JSON.stringify(data, null, 2),

      text: {
        format: {
          type: 'json_schema',
          name: 'investmind_analysis',
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
                type: 'array',
                items: {
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
     `I анализ выполнен для ${ data.symbol }`
    );

    res.json({
      status: 'ok',
      message: 'InvestMind AI завершил анализ',
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
        'Не удалось выполнить AI-анализ',
    });
  }
});

app.listen(PORT, () => {
  console.log(
    `InvestMind Backend запущен на порту ${ PORT }`,
  );
});