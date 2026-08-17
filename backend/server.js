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

// ------------------------------------------------------------
// Health
// ------------------------------------------------------------

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

Для банков и финансовых компаний:

- Не применяй обычные корпоративные пороги Debt/Equity.
- Высокий Debt/Equity сам по себе не является доказательством слабого банка.
- Не используй Current Ratio и Quick Ratio как основные показатели банковской ликвидности.
- Отсутствие Current Ratio и Quick Ratio не считай существенным недостатком.
- Free Cash Flow per Share имеет для банков другую экономическую природу.
- Отсутствие FCF/share не считай самостоятельным риском.
- P/S имеет ограниченную аналитическую ценность.- Основное внимание уделяй ROE, марже, EPS Growth, Revenue Growth,
  P/E, Forward P/E, Profitability, Valuation, Financial Health и Risk.
`;

    case 'semiconductors':
    case 'technology':
      return `
ОТРАСЛЕВАЯ ЛОГИКА: TECHNOLOGY

Особенно учитывай:
- рост выручки;
- рост EPS;
- маржинальность;
- P/E и P/S;
- Free Cash Flow;
- соответствие темпов роста высокой рыночной оценке.

Высокие мультипликаторы допустимы чаще, чем в зрелых секторах,
но должны подтверждаться сильным ростом бизнеса.
`;

    case 'consumerStaples':
      return `
ОТРАСЛЕВАЯ ЛОГИКА: CONSUMER STAPLES

Не требуй технологических темпов роста.
Особое внимание уделяй:
- стабильности прибыли;
- маржинальности;
- финансовой устойчивости;
- денежному потоку;
- оценке акции;
- уровню риска.
`;

    case 'energy':
      return `
ОТРАСЛЕВАЯ ЛОГИКА: ENERGY

Учитывай цикличность энергетического бизнеса.
Особое внимание уделяй:
- денежному потоку;
- долгу;
- прибыльности;
- valuation;
- рыночному риску.
`;

    case 'healthcare':
      return `
ОТРАСЛЕВАЯ ЛОГИКА: HEALTHCARE

Учитывай рост, прибыльность, денежный поток,
valuation и финансовую устойчивость.

Не выдумывай сведения о препаратах,
испытаниях или регуляторных событиях.
`;

    case 'automotive':
      return `
ОТРАСЛЕВАЯ ЛОГИКА: AUTOMOTIVE

Учитывай:
- цикличность;
- капиталоёмкость;
- маржинальность;
- долг;
- ликвидность;
- valuation.

Низкий P/S сам по себе не означает недооценённость.
`;

    case 'utilities':
    case 'realEstate':
      return `
ОТРАСЛЕВАЯ ЛОГИКА: CAPITAL-INTENSIVE

Более высокий долг может быть нормальнее,
чем для технологических компаний.

Не оценивай долговую нагрузку вне отраслевого контекста.
`;

    default:
      return `
ОТРАСЛЕВАЯ ЛОГИКА: GENERAL

Используй стандартную фундаментальную интерпретацию,
но не применяй одинаковые пороги механически
ко всем типам бизнеса.
`;
  }
}

// ------------------------------------------------------------
// Deep Analysis — single company
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

Тебе передаются структурированные данные одной компании.

Определённый отраслевой профиль:
${sectorProfile}

${sectorGuidance}

Confidence Score уже рассчитан системой InvestMind.

Ты НЕ рассчитываешь Confidence самостоятельно.
Ты НЕ меняешь Confidence.
Ты НЕ предлагаешь собственный процент.

Правила:

1. Используй только переданные данные.

2. Не выдумывай:
- новости;
- отчётность;
- прогнозы аналитиков;
- события;
- отсутствующие показатели.

3. null означает отсутствие данных.
Никогда не трактуй null как 0.

4. Не давай прямых рекомендаций
купить или продать акцию.

5. Не обещай будущую доходность.

6. Отделяй качество бизнеса
от рыночной оценки акции.

7. Учитывай отраслевой контекст.

8. Technical и Fundamental
могут противоречить друг другу.
Если разрыв существенный — объясни его.

9. Combined Score уже рассчитан InvestMind.
Не пересчитывай его.

10. Учитывай фактические веса
Technical и Fundamental.

11. Учитывай полноту данных.

12. Отсутствующий показатель
не является автоматически риском.

13.Не превращай отраслевую особенность
в доказанный риск.

14. Пиши простым русским языком.

15. Не используй Markdown.

16. Не возвращай Confidence.

summary:
Краткий единый вывод о бизнесе,
valuation, technical, рисках
и качестве данных.

strengths:
Самые значимые сильные стороны.

risks:
Только подтверждённые риски.

watch:
Конкретные показатели,
за которыми имеет смысл следить.
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

    if (
      !response.output_text ||
      response.output_text.trim().length === 0
    ) {
      throw new Error(
        'OpenAI вернул пустой AI-анализ.',
      );
    }

    const parsedAnalysis =
      JSON.parse(
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

      confidence: confidenceScore,
    };

    console.log(
      `Deep Analysis: ${data.company.symbol} | Sector: ${sectorProfile} | Confidence: ${confidenceScore} %`,
    );

    res.json({
      status: 'ok',
      message:
        'InvestMind Deep Analysis завершён',
      analysis,
    });
  } catch (error) {
    console.error(
      'Deep Analysis error:',
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

// ------------------------------------------------------------
// AI Comparison — 2 to 4 companies
// ------------------------------------------------------------

app.post('/api/compare', async (req, res) => {
  try {
    const data = req.body;

    if (
      !data ||
      !Array.isArray(data.companies)
    ) {
      return res.status(400).json({
        status: 'error',
        message:
          'Не передан массив companies.',
      });
    }

    if (
      data.companies.length < 2 ||
      data.companies.length > 4
    ) {
      return res.status(400).json({
        status: 'error',
        message:
          'AI-сравнение поддерживает от 2 до 4 компаний.',
      });
    }

    for (const company of data.companies) {
      if (
        !company ||
        !company.symbol ||
        typeof company.investMindScore !== 'number' ||
        typeof company.technicalScore !== 'number' ||
        typeof company.fundamentalScore !== 'number'
      ) {
        return res.status(400).json({
          status: 'error',
          message:
            'Одна из компаний содержит неполные данные.',
        });
      }
    }

    const comparisonData =
      data.companies.map(
        (company) => ({
          ...company,
          sectorProfile:
            resolveSectorProfile(company.industry,
            ),
        }),
      );

    const response =
      await openai.responses.create({
        model: 'gpt-5.6',

        instructions: `
Ты — модуль InvestMind AI Comparison.

Тебе передаются уже рассчитанные
InvestMind данные от 2 до 4 компаний.

ВАЖНО:

InvestMind уже рассчитал:
- InvestMind Score;
- Technical Score;
- Fundamental Score;
- Growth Score;
- Profitability Score;
- Valuation Score;
- Financial Health Score;
- Risk Score;
- Confidence;
- полноту данных.

Ты НЕ пересчитываешь эти показатели.
Ты НЕ меняешь их.
Ты НЕ создаёшь собственные баллы.

Твоя задача — объяснить различия между компаниями.

Правила:

1. Используй только переданные данные.

2. Не используй внешние новости,
аналитические прогнозы
или знания о событиях компании.

3. Не давай рекомендацию:
"купить",
"продать",
"обязательно выбрать".

4. Не обещай будущую доходность.

5. Учитывай отрасль каждой компании.

6. Компании из разных отраслей
нельзя механически сравнивать
по отдельным финансовым коэффициентам.

7. При сравнении банков
не трактуй Debt/Equity,
Current Ratio и Quick Ratio
как для обычной промышленной компании.

8. Высокий Growth Score
не компенсирует автоматически
низкий Valuation Score.

9. Высокий InvestMind Score
не означает отсутствия рисков.

10. Высокий Confidence означает,
что InvestMind лучше обеспечен данными,
а не то, что акция обязательно лучше.

11. Если Confidence компаний отличается,
учитывай это при силе формулировок.

12. Если результаты очень близкие,
не называй одного участника
явным победителем.

13. Перед тем как назвать компанию лучшей
по любому отдельному показателю,
обязательно сравни значение этого показателя
со всеми остальными компаниями.

Если лучший показатель одинаковый
у двух или более компаний,
никогда не называй одну из них
единоличным лидером.

В таком случае используй формулировки:
"делит лидерство",
"имеет совместно лучший показатель"
или
"находится среди лидеров по этому показателю".

Фразы:
"лучший в группе",
"максимальный в группе",
"единолично лидирует"
разрешены только если значение действительно
строго выше, чем у всех остальных компаний.

14. Объясняй компромиссы:
например сильный рост,
но слабая оценка;
сильный фундаментал,
но слабая техника;
хорошая valuation,
но низкая profitability.

15. Пиши простым русским языком.

16. Не используй Markdown.

Нужно вернуть:

summary:
Общий сравнительный вывод.

leader:
Тикер компании,
которая занимает первое место
по переданному InvestMind Score.
Если первое место делят несколько компаний,
перечисли тикеры через запятую.

leaderReason:
Почему лидер занимает первое место
с учётом структуры показателей.

tradeoffs:
Список основных компромиссов между компаниями.

companyInsights:
Короткий отдельный вывод
для каждой компании.

watch:
Какие различия и показатели
важно отслеживать при дальнейшем сравнении.

Не создавай новых числовых рейтингов.

Перед формированием leaderReason,
tradeoffs и companyInsights
сначала мысленно проверь все максимумы
по каждому Score и наличие ничьих.

Не делай вывод о лидерстве
только по одной компании без проверки остальных.
`,

        input: JSON.stringify(
          {
            companies: comparisonData,
          },
          null,
          2,
        ),

        text: {
          format: {
            type: 'json_schema',
            name:
              'investmind_company_comparison',
            strict: true,
            schema: {
              type: 'object',

              properties: {
                summary: {
                  type: 'string',
                },

                leader: {
                  type: 'string',
                },

                leaderReason: {
                  type: 'string',
                },

                tradeoffs: {
                  type: 'array',
                  items: {
                    type: 'string',
                  },
                },

                companyInsights: {
                  type: 'array',
                  items: {
                    type: 'object',

                    properties: {
                      symbol: {
                        type: 'string',
                      },

                      insight: {
                        type: 'string',
                      },
                    },

                    required: [
                      'symbol',
                      'insight',
                    ],

                    additionalProperties: false,
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
                'leader', 'leaderReason',
                'tradeoffs',
                'companyInsights',
                'watch',
              ],

              additionalProperties: false,
            },
          },
        },
      });

    if (
      !response.output_text ||
      response.output_text.trim().length === 0
    ) {
      throw new Error(
        'OpenAI вернул пустое AI-сравнение.',
      );
    }

    const parsedComparison =
      JSON.parse(
        response.output_text,
      );

    const comparison = {
      summary:
        parsedComparison.summary ?? '',

      leader:
        parsedComparison.leader ?? '',

      leaderReason:
        parsedComparison.leaderReason ?? '',

      tradeoffs:
        Array.isArray(
          parsedComparison.tradeoffs,
        )
          ? parsedComparison.tradeoffs
          : [],

      companyInsights:
        Array.isArray(
          parsedComparison.companyInsights,
        )
          ? parsedComparison.companyInsights
          : [],

      watch:
        Array.isArray(
          parsedComparison.watch,
        )
          ? parsedComparison.watch
          : [],
    };

    console.log(
      `AI Comparison: ${comparisonData
        .map((company) => company.symbol)
        .join(' vs ')}`,
    );

    res.json({
      status: 'ok',
      message:
        'InvestMind AI Comparison завершён',
      comparison,
    });
  } catch (error) {
    console.error(
      'AI Comparison error:',
      error,
    );

    res.status(500).json({
      status: 'error',
      message:
        error?.message ??
        'Не удалось выполнить AI Comparison',
    });
  }
});

// ------------------------------------------------------------
// Start server
// ------------------------------------------------------------

app.listen(PORT, () => {
  console.log(
    `InvestMind Backend запущен на порту ${PORT}`,
  );
});