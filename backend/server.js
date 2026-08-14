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

    if (
      !data.investMind ||
      typeof data.investMind.confidenceScore !== 'number'
    ) {
      return res.status(400).json({
        status: 'error',
        message:
          'Не передан investMind.confidenceScore',
      });
    }

    const confidenceScore = Math.max(
      0,
      Math.min(
        100,
        Math.round(
          data.investMind.confidenceScore,
        ),
      ),
    );

    const response =
      await openai.responses.create({
        model: 'gpt-5.6',

        instructions: `
Ты — аналитический модуль InvestMind Deep Analysis.

Тебе передаются структурированные данные компании.

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
- технические сильные стороны
- технические риски

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
- Quick Ratio
- Debt/Equity
- Free Cash Flow per Share
- Beta
- 52-недельный максимум
- 52-недельный минимум
- Fundamental Score
- Growth Score
- Profitability Score
- Valuation Score
- Financial Health Score
- Fundamental Risk Score
- полнота фундаментальных данных
- фундаментальные сильные стороны
- фундаментальные риски

investMind:
- Combined Score
- общий рейтинг
- фактический вес Technical
- фактический вес Fundamental
- Confidence Score

Твоя задача — сделать единый анализ компании,
объединяя техническое состояние акции,
фундаментальное состояние бизнеса,
качество доступных данных
и итоговую оценку InvestMind.

ВАЖНО:

Confidence Score уже рассчитан системой InvestMind.

Ты НЕ рассчитываешь Confidence самостоятельно.
Ты НЕ изменяешь Confidence Score.
Ты НЕ предлагаешь другой процент уверенности.

Confidence Score является системным показателем
достоверности анализа и будет добавлен backend
после завершения AI-анализа.

Правила:

1. Используй только переданные данные.

2. Не выдумывай новости, отчётность,
прогнозы аналитиков или отсутствующие показатели.

3. Если показатель равен null,
считай его отсутствующим.

4. Никогда не трактуй null как 0.

5. Не давай прямых рекомендаций
покупать или продавать акции.

6. Не обещай будущую доходность.

7. Отделяй качество бизнеса
от рыночной оценки акции.

8. Высокий рост бизнеса
не означает автоматически хорошую оценку акции.

9. Высокий P/E или P/S рассматривай
как риск оценки,
особенно если Valuation Score низкий.

10. Низкие мультипликаторы
при отрицательной прибыли
не считай автоматически признаком дешевизны.

11. Высокую Beta, волатильность
и большую максимальную просадку
учитывай как рыночный риск.

12. Technical Score и Fundamental Score
могут противоречить друг другу.

Если между ними есть существенный разрыв,
обязательно объясни его.

13. Combined Score используй
как итоговую количественную оценку,
но не повторяй его механически.

14. Учитывай фактические веса
Technical и Fundamental,
переданные в investMind.

15. Если полнота фундаментальных данных
ограничена,
обязательно учитывай это
при формулировке выводов.

16. Отсутствие данных
не является автоматически негативным фактором.

Нужно писать:
"показатель отсутствует"
или
"по доступным данным оценить нельзя".

17. Не превращай отсутствие Free Cash Flow,
P/E, EPS Growth или другой метрики
в отрицательное значение.

18. Пиши простым,понятным русским языком.

19. Не используй Markdown.

20. Не добавляй поля,
которых нет в заданной JSON-структуре.

summary:
Дай краткий общий вывод о:
- качестве бизнеса;
- оценке акции;
- технической картине;
- основных рисках;
- согласованности Technical и Fundamental.

strengths:
Выбери наиболее значимые сильные стороны.
Не перечисляй слабые или отсутствующие данные
как сильные стороны.

risks:
Выбери наиболее важные реальные риски.

Особое внимание уделяй:
- дорогой оценке;
- отрицательной прибыльности;
- высокому долгу;
- слабой ликвидности;
- слабой технической структуре;
- высокой Beta;
- высокой волатильности;
- большой исторической просадке.

Отсутствующий показатель
можно упомянуть как ограничение анализа,
но не как доказанный риск бизнеса.

watch:
Укажи конкретные показатели,
за которыми инвестору стоит следить дальше.

Если какой-то важный показатель отсутствует,
можно указать его появление
как предмет дальнейшего наблюдения.

Не рассчитывай и не возвращай Confidence.
`,

        input: JSON.stringify(
          data,
          null,
          2,
        ),

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
                  type: 'array',
                  items: {
                    type: 'string',
                  },
                },
              },

              required: [
                'summary',
                'strengths',
                'risks',
                'watch',
              ],

              additionalProperties: false,
            },
          },
        },
      });

    const parsedAnalysis = JSON.parse(
      response.output_text,
    );

    const analysis = {
      summary:
        parsedAnalysis.summary ?? '',
      strengths:
        Array.isArray(
          parsedAnalysis.strengths,
        )
          ? parsedAnalysis.strengths
          : [],
      risks:
        Array.isArray(
          parsedAnalysis.risks,
        )
          ? parsedAnalysis.risks
          : [],
      watch:
        Array.isArray(
          parsedAnalysis.watch,
        )
          ? parsedAnalysis.watch
          : [],

      // Единственный официальный Confidence
      // приходит из InvestMind.
      confidence: confidenceScore,
    };

    console.log(
      `Deep Analysis выполнен для ${data.company.symbol} | Confidence: ${confidenceScore} %`
    );

    res.json({
      status: 'ok',
      message:
        'InvestMind Deep Analysis завершён',
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
    `InvestMind Backend запущен на порту ${PORT}`,
  );
});