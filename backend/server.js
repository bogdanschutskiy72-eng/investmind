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

// ------------------------------------------------------------
// Sector detection
// ------------------------------------------------------------

function resolveSectorProfile(industry) {
  const value = String(industry ?? '')
    .toLowerCase()
    .trim();

  if (
    value.includes('semiconductor') ||
    value.includes('chip')
  ) {
    return 'semiconductors';
  }

  if (
    value.includes('bank') ||
    value.includes('banking') ||
    value.includes('financial') ||
    value.includes('capital market') ||
    value.includes('insurance') ||
    value.includes('credit service') ||
    value.includes('asset management')
  ) {
    return 'financials';
  }

  if (
    value.includes('software') ||
    value.includes('information technology') ||
    value.includes('it service') ||
    value.includes('computer') ||
    value.includes('internet') ||
    value.includes('technology')
  ) {
    return 'technology';
  }

  if (
    value.includes('beverage') ||
    value.includes('food') ||
    value.includes('tobacco') ||
    value.includes('household') ||
    value.includes('personal product') ||
    value.includes('consumer defensive') ||
    value.includes('consumer staples')
  ) {
    return 'consumerStaples';
  }

  if (
    value.includes('retail') ||
    value.includes('restaurant') ||
    value.includes('apparel') ||
    value.includes('leisure') ||
    value.includes('travel') ||
    value.includes('consumer cyclical') ||
    value.includes('consumer discretionary')
  ) {
    return 'consumerDiscretionary';
  }

  if (
    value.includes('oil') ||
    value.includes('gas') ||
    value.includes('energy') ||
    value.includes('petroleum') ||
    value.includes('coal')
  ) {
    return 'energy';
  }

  if (
    value.includes('pharma') ||
    value.includes('biotech') ||
    value.includes('health') ||
    value.includes('medical') ||
    value.includes('drug')
  ) {
    return 'healthcare';
  }

  if (
    value.includes('automotive') ||
    value.includes('automobile') ||
    value.includes('vehicle') ||
    value.includes('auto manufacturer')
  ) {
    return 'automotive';
  }

  if (
    value.includes('industrial') ||
    value.includes('machinery') ||
    value.includes('aerospace') ||
    value.includes('defense') ||
    value.includes('construction') ||
    value.includes('transportation')
  ) {
    return 'industrials';
  }

  if (
    value.includes('utility') ||
    value.includes('utilities') ||
    value.includes('electric') ||
    value.includes('water utility')
  ) {
    return 'utilities';
  }

  if (
    value.includes('reit') ||
    value.includes('real estate')
  ) {
    return 'realEstate';
  }

  return 'generic';
}

// ------------------------------------------------------------
// Sector-specific AI guidance
// ------------------------------------------------------------

function buildSectorGuidance(sectorProfile) {
  switch (sectorProfile) {
    case 'financials':
      return `
ОТРАСЛЕВАЯ ЛОГИКА: FINANCIALS / BANKING

Компания относится к финансовой или банковской отрасли.

Для банков и финансовых компаний:

- НЕ применяй обычные корпоративные пороги Debt/Equity.
- Высокий Debt/Equity сам по себе НЕ является доказательством слабого финансового здоровья банка.
- НЕ называй Debt/Equity самостоятельным фундаментальным риском только потому, что значение высокое.
- НЕ используй Current Ratio и Quick Ratio как основные показатели банковской ликвидности.
- Отсутствие Current Ratio и Quick Ratio НЕ считай существенным недостатком анализа банка.
- Free Cash Flow per Share для банка имеет другую экономическую природу, чем для обычной промышленной компании.
- Отсутствие Free Cash Flow per Share НЕ считай самостоятельным риском банка.- P/S для банка имеет ограниченную аналитическую ценность и не должен доминировать в оценке.
- Основное внимание по доступным данным уделяй:
  ROE,
  чистой марже,
  росту EPS,
  росту выручки,
  P/E,
  Forward P/E,
  Fundamental Score,
  Profitability Score,
  Valuation Score,
  Financial Health Score,
  Risk Score.
- Если Financial Health Score около 50, трактуй это как нейтральную оценку по доступным данным, а не как доказательство финансовой слабости.
- Не утверждай, что долговая нагрузка банка чрезмерна, если специальных банковских показателей капитала и качества активов в данных нет.
`;

    case 'semiconductors':
    case 'technology':
      return `
ОТРАСЛЕВАЯ ЛОГИКА: TECHNOLOGY

Для технологических компаний особенно важны:
рост выручки,
рост EPS,
маржинальность,
оценка P/E и P/S,
Free Cash Flow,
темпы роста относительно высокой рыночной оценки.

Высокие мультипликаторы допустимы чаще, чем в зрелых секторах,
но должны подтверждаться ростом бизнеса.
`;

    case 'consumerStaples':
      return `
ОТРАСЛЕВАЯ ЛОГИКА: CONSUMER STAPLES

Для зрелого защитного бизнеса:
не требуй технологических темпов роста.
Особое внимание уделяй стабильности прибыли,
маржинальности,
финансовой устойчивости,
денежному потоку,
оценке акции и уровню риска.
`;

    case 'energy':
      return `
ОТРАСЛЕВАЯ ЛОГИКА: ENERGY

Учитывай цикличность бизнеса.
Рост и маржинальность могут значительно меняться между периодами.
Особое внимание уделяй денежному потоку,
долгу,
прибыльности,
valuation и рыночному риску.
`;

    case 'healthcare':
      return `
ОТРАСЛЕВАЯ ЛОГИКА: HEALTHCARE

Оценивай рост,
прибыльность,
денежный поток,
valuation и финансовую устойчивость.
Не делай выводов о препаратах,
испытаниях или регуляторных событиях,
если такие данные не переданы.
`;

    case 'automotive':
      return `
ОТРАСЛЕВАЯ ЛОГИКА: AUTOMOTIVE

Учитывай цикличность,
капиталоёмкость,
маржинальность,
долговую нагрузку,
ликвидность и valuation.
Низкий P/S сам по себе не означает недооценённость,
особенно при слабой прибыльности.
`;

    case 'utilities':
    case 'realEstate':
      return `
ОТРАСЛЕВАЯ ЛОГИКА: CAPITAL-INTENSIVE

Для капиталоёмкого бизнеса более высокий долг может быть типичнее,
чем для технологических компаний.
Не оценивай долговую нагрузку вне контекста отрасли.
Особое внимание уделяй устойчивости прибыли,
денежным потокам и риску.
`;

    default:
      return `
ОТРАСЛЕВАЯ ЛОГИКА: GENERAL

Используй стандартную фундаментальную интерпретацию,
но всегда учитывай отрасль компании
и не применяй один и тот же порог механически
ко всем типам бизнеса.
`;
  }
}

// ------------------------------------------------------------
// Deep Analysis
// ------------------------------------------------------------

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

    const sectorProfile =
      resolveSectorProfile(
        data.company.industry,
      );

    const sectorGuidance =
      buildSectorGuidance(
        sectorProfile,
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
- Technical Score- технические сильные стороны
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

Определённый InvestMind отраслевой профиль:
${sectorProfile}

${sectorGuidance}

Твоя задача — сделать единый анализ компании,
объединяя:

- техническое состояние акции;
- фундаментальное состояние бизнеса;
- отраслевую специфику;
- качество доступных данных;
- итоговую оценку InvestMind.

ВАЖНО:

Confidence Score уже рассчитан системой InvestMind.

Ты НЕ рассчитываешь Confidence самостоятельно.
Ты НЕ изменяешь Confidence Score.
Ты НЕ предлагаешь другой процент уверенности.

Confidence Score является системным показателем
достоверности анализа и будет добавлен backend
после завершения AI-анализа.

ОБЩИЕ ПРАВИЛА:

1. Используй только переданные данные.

2. Не выдумывай новости,
отчётность,
прогнозы аналитиков,
макроэкономические события
или отсутствующие показатели.

3. Если показатель равен null,
считай его отсутствующим.

4. Никогда не трактуй null как 0.

5. Не давай прямых рекомендаций
покупать или продавать акции.

6. Не обещай будущую доходность.

7. Отделяй качество бизнеса
от рыночной оценки акции.

8. Высокий рост бизнеса
не означает автоматически
хорошую оценку акции.

9. Высокий P/E или P/S
рассматривай в контексте отрасли,
темпов роста и Valuation Score.

10. Низкие мультипликаторы
при отрицательной прибыли
не считай автоматически
признаком дешевизны.

11. Beta,
волатильность
и максимальную просадку
учитывай как показатели
рыночного риска.

12. Technical Score
и Fundamental Score
могут противоречить друг другу.

Если между ними есть существенный разрыв,
объясни его.

13. Combined Score используй
как итоговую количественную оценку,
но не повторяй его механически.

14. Учитывай фактические веса
Technical и Fundamental,
переданные в investMind.

15. Учитывай полноту
фундаментальных данных.

16. Отсутствие данных
не является автоматически
негативным фактором.

Пиши:
"показатель отсутствует"
или
"по доступным данным оценить нельзя".

17. Не превращай отсутствие
Free Cash Flow,
P/E,
EPS Growth
или другой метрики
в отрицательное значение.

18. Перед интерпретацией любого
финансового коэффициента
учитывай отрасль компании.

19. Не называй показатель риском
только потому,
что он отличается от универсального порога.

20. Если отраслевой профиль
указывает, что показатель
имеет ограниченную применимость,
не используй его
как главный аргумент анализа.

21. Пиши простым,
понятным русским языком.

22. Не используй Markdown.

23. Не добавляй поля,
которых нет
в заданной JSON-структуре.

summary:

Дай краткий общий вывод о:

- качестве бизнеса;
- оценке акции;
- технической картине;
- основных рисках;
- согласованности Technical и Fundamental;
- качестве доступных данных.

strengths:

Выбери только
наиболее значимые сильные стороны.

Не перечисляй слабые
или отсутствующие данные
как сильные стороны.

risks:

Выбери только
реальные подтверждённые риски.

Не превращай
отраслевую особенность
в риск.

Не превращай
отсутствующую метрику
в доказанный риск.

watch:

Укажи конкретные показатели,
за которыми стоит следить дальше.

Выбирай прежде всего
релевантные для отрасли показатели.

Если отсутствующий показатель
не особенно информативен
для данной отрасли,
не включай его
в список наблюдения
только из-за отсутствия.

Не рассчитывай
и не возвращай Confidence.
`,

        input: JSON.stringify(
          data,
          null,
          2,
        ),

        text: {
          format: {
            type: 'json_schema',
            name:
              'investmind_deep_analysis',
            strict: true, schema: {
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

    if (
      !response.output_text ||
      response.output_text.trim().isEmpty
    ) {
      throw new Error(
        'OpenAI вернул пустой AI-анализ.',
      );
    }

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
      `Deep Analysis: ${data.company.symbol} | Sector: ${sectorProfile} | Confidence: ${confidenceScore}%`
    );

    res.json({
      status: 'ok',
      message:
        'InvestMind Deep Analysis завершён',
      analysis,
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
    `InvestMind Backend запущен на порту ${PORT}`
  );
});