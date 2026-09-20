require('dotenv').config();

const express = require('express');
const cors = require('cors');
const OpenAI = require('openai');

const {
  MarketDataCache,
} = require('./market_data_cache');

const app = express();
const PORT = 3000;

// ------------------------------------------------------------
// Backend cache
// ------------------------------------------------------------

const marketDataCache =
  new MarketDataCache({
    maxEntries: 1000,
  });

const CACHE_TTL = {
  quote: {
    fresh: 60 * 1000,
    stale: 10 * 60 * 1000,
  },

  search: {
    fresh: 5 * 60 * 1000,
    stale: 30 * 60 * 1000,
  },

  profile: {
    fresh: 24 * 60 * 60 * 1000,
    stale: 7 * 24 * 60 * 60 * 1000,
  },

  metrics: {
    fresh: 6 * 60 * 60 * 1000,
    stale: 24 * 60 * 60 * 1000,
  },

  intraday: {
    fresh: 5 * 60 * 1000,
    stale: 30 * 60 * 1000,
  },

  dailyHistory: {
    fresh: 60 * 60 * 1000,
    stale: 24 * 60 * 60 * 1000,
  },
};

// ------------------------------------------------------------
// API configuration
// ------------------------------------------------------------

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

const FINNHUB_API_KEY =
  process.env.FINNHUB_API_KEY;

const TWELVE_DATA_API_KEY =
  process.env.TWELVE_DATA_API_KEY;

if (!FINNHUB_API_KEY) {
  console.warn(
    'FINNHUB_API_KEY не задан на backend.',
  );
}

if (!TWELVE_DATA_API_KEY) {
  console.warn(
    'TWELVE_DATA_API_KEY не задан на backend.',
  );
}

app.use(cors());
app.use(express.json());

// ------------------------------------------------------------
// Common helpers
// ------------------------------------------------------------

function wait(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

function normalizeSymbol(value) {
  const symbol = String(value ?? '')
    .trim()
    .toUpperCase();

  if (
    !symbol ||
    symbol.length > 20 ||
    !/^[A-Z0-9.\-]+$/.test(symbol)
  ) {
    return null;
  }

  return symbol;
}

function parseJsonText(text) {
  try {
    return JSON.parse(text);
  } catch (_) {
    return null;
  }
}

// ------------------------------------------------------------
// Finnhub queue
// ------------------------------------------------------------

const finnhubQueue = [];

let finnhubQueueRunning = false;
let lastFinnhubRequestAt = 0;

const FINNHUB_MIN_INTERVAL = 1200;

async function runFinnhubQueue() {
  if (finnhubQueueRunning) {
    return;
  }

  finnhubQueueRunning = true;

  while (finnhubQueue.length > 0) {
    const job = finnhubQueue.shift();

    try {
      const elapsed =
        Date.now() -
        lastFinnhubRequestAt;

      const remaining =
        FINNHUB_MIN_INTERVAL -
        elapsed;

      if (remaining > 0) {
        await wait(remaining);
      }

      lastFinnhubRequestAt =
        Date.now();

      const response =
        await fetch(job.url);

      const text =
        await response.text();

      job.resolve({
        status: response.status,
        text,
      });
    } catch (error) {
      job.reject(error);
    }
  }

  finnhubQueueRunning = false;
}

function finnhubRequest(
  url,
  {
    priority = false,
  } = {},
) {
  return new Promise(
    (resolve, reject) => {
      const job = {
        url,
        resolve,
        reject,
      };

      if (priority) {
        finnhubQueue.unshift(job);
      } else {
        finnhubQueue.push(job);
      }

      runFinnhubQueue();
    },
  );
}

async function sendFinnhubRequest(
  res,
  path,
  params,
  {
    priority = false,
    cacheKey = null,
    cachePolicy = null,
  } = {},
) {
  if (!FINNHUB_API_KEY) {
    return res.status(500).json({
      status: 'error',
      message:
        'Finnhub не настроен на backend.',
    });
  }

  const searchParams =
    new URLSearchParams({
      ...params,
      token: FINNHUB_API_KEY,
    });

  const url =
    `https://finnhub.io${path}?${searchParams.toString()}`;

  const loadFromFinnhub =
    async () => {
      let result =
        await finnhubRequest(
          url,
          {
            priority,
          },
        );

      if (result.status === 429) {
        await wait(4000);

        result =
          await finnhubRequest(
            url,
            {
              priority,
            },
          );
      }

      if (result.status !== 200) {
        const error =
          new Error(
            `Finnhub HTTP ${result.status}`,
          );

        error.upstreamStatus =
          result.status;

        error.upstreamText =
          result.text;

        throw error;
      }

      return result;
    };

  try {
    let result;
    let cacheState = 'network';

    if (
      cacheKey &&
      cachePolicy
    ) {
      const cached =
        await marketDataCache.getOrLoad({
          key:
            `finnhub:${cacheKey}`,
          ttlMs:
            cachePolicy.fresh,
          staleTtlMs:
            cachePolicy.stale,
          loader:
            loadFromFinnhub,
          staleWhileRevalidate:
            true,
        });

      result = cached.value;
      cacheState =
        cached.cacheState;
    } else {
      result =
        await loadFromFinnhub();
    }

    res.set(
      'X-InvestMind-Cache',
      cacheState,
    );

    return res
      .status(result.status)
      .type('application/json')
      .send(result.text);
  } catch (error) {
    if (
      error.upstreamStatus &&
      error.upstreamText
    ) {
      return res
        .status(
          error.upstreamStatus,
        )
        .type('application/json')
        .send(
          error.upstreamText,
        );
    }

    throw error;
  }
}

// ------------------------------------------------------------
// Twelve Data queue
// ------------------------------------------------------------

const twelveDataQueue = [];

let twelveDataQueueRunning = false;
let lastTwelveDataRequestAt = 0;

const TWELVE_DATA_MIN_INTERVAL = 8000;

async function runTwelveDataQueue() {
  if (twelveDataQueueRunning) {
    return;
  }

  twelveDataQueueRunning = true;

  while (
    twelveDataQueue.length > 0
  ) {
    const job =
      twelveDataQueue.shift();

    try {
      const elapsed =
        Date.now() -
        lastTwelveDataRequestAt;

      const remaining =
        TWELVE_DATA_MIN_INTERVAL -
        elapsed;

      if (remaining > 0) {
        await wait(remaining);
      }

      lastTwelveDataRequestAt =
        Date.now();

      const response =
        await fetch(job.url);

      const text =
        await response.text();

      job.resolve({
        status: response.status,
        text,
      });
    } catch (error) {
      job.reject(error);
    }
  }

  twelveDataQueueRunning = false;
}

function twelveDataRequest(url) {
  return new Promise(
    (resolve, reject) => {
      twelveDataQueue.push({
        url,
        resolve,
        reject,
      });

      runTwelveDataQueue();
    },
  );
}

async function loadTwelveData(
  params,
) {
  if (!TWELVE_DATA_API_KEY) {
    const error =
      new Error(
        'Twelve Data не настроен на backend.',
      );

    error.upstreamStatus = 500;

    throw error;
  }

  const searchParams =
    new URLSearchParams({
      ...params,
      apikey:
        TWELVE_DATA_API_KEY,
    });

  const url =
    `https://api.twelvedata.com/time_series?${searchParams.toString()}`;

  let result =
    await twelveDataRequest(url);

  if (result.status === 429) {
    await wait(10000);

    result =
      await twelveDataRequest(url);
  }

  if (result.status !== 200) {
    const error =
      new Error(
        `Twelve Data HTTP ${result.status}`,
      );

    error.upstreamStatus =
      result.status;

    error.upstreamText =
      result.text;

    throw error;
  }

  const parsed =
    parseJsonText(result.text);

  if (!parsed) {
    throw new Error(
      'Twelve Data вернул некорректный JSON.',
    );
  }

  if (parsed.status === 'error') {
    const error =
      new Error(
        parsed.message ??
        'Twelve Data вернул ошибку.',
      );

    error.upstreamStatus = 502;
    error.upstreamText =
      result.text;

    throw error;
  }

  return parsed;
}

async function sendTwelveDataRequest(
  res,
  {
    symbol,
    interval,
    outputSize,
    order,
  },
) {
  try {
    const isDaily =
      interval === '1day';

    const cachePolicy =
      isDaily
        ? CACHE_TTL.dailyHistory
        : CACHE_TTL.intraday;

    // Для дневных данных 30 / 90 / 365
    // используем один общий набор до 365 дней.
    const requestedSize =
      outputSize;

    const upstreamSize =
      isDaily
        ? Math.max(
          365,
          requestedSize,
        )
        : requestedSize;

    const cacheKey =
      isDaily
        ? `twelve:daily:${symbol}:${upstreamSize}`
        : `twelve:${interval}:${symbol}:${upstreamSize}:${order}`;

    const cached =
      await marketDataCache.getOrLoad({
        key: cacheKey,
        ttlMs:
          cachePolicy.fresh,
        staleTtlMs:
          cachePolicy.stale,
        staleWhileRevalidate:
          true,
        loader: async () => {
          return loadTwelveData({
            symbol,
            interval,
            outputsize:
              String(
                upstreamSize,
              ),
            order,
          });
        },
      });

    let body =
      cached.value;

    if (
      isDaily &&
      body &&
      Array.isArray(
        body.values,
      ) &&
      body.values.length >
      requestedSize
    ) {
      const values =
        order === 'ASC'
          ? body.values.slice(
            -requestedSize,
          )
          : body.values.slice(
            0,
            requestedSize,
          );

      body = {
        ...body,
        values,
      };
    }

    res.set(
      'X-InvestMind-Cache',
      cached.cacheState,
    );

    return res
      .status(200)
      .json(body);
  } catch (error) {
    if (
      error.upstreamStatus &&
      error.upstreamText
    ) {
      return res
        .status(
          error.upstreamStatus,
        )
        .type('application/json')
        .send(
          error.upstreamText,
        );
    }

    throw error;
  }
}

// ------------------------------------------------------------
// Health
// ------------------------------------------------------------

app.get(
  '/health',
  (req, res) => {
    res.json({
      status: 'ok',
      service:
        'InvestMind Backend',
      cacheEntries:
        marketDataCache.size,
    });
  },
);

// ------------------------------------------------------------
// Finnhub proxy
// ------------------------------------------------------------

app.get(
  '/api/market/quote',
  async (req, res) => {
    try {
      const symbol =
        normalizeSymbol(
          req.query.symbol,
        );

      if (!symbol) {
        return res
          .status(400)
          .json({
            status: 'error',
            message:
              'Некорректный symbol.',
          });
      }

      return await sendFinnhubRequest(
        res,
        '/api/v1/quote',
        {
          symbol,
        },
        {
          cacheKey:
            `quote:${symbol}`,
          cachePolicy:
            CACHE_TTL.quote,
        },
      );
    } catch (error) {
      console.error(
        'Finnhub quote error:',
        error,
      );

      return res
        .status(500)
        .json({
          status: 'error',
          message:
            'Не удалось получить котировку.',
        });
    }
  },
);

app.get(
  '/api/market/profile',
  async (req, res) => {
    try {
      const symbol =
        normalizeSymbol(
          req.query.symbol,
        );

      if (!symbol) {
        return res
          .status(400)
          .json({
            status: 'error',
            message:
              'Некорректный symbol.',
          });
      }

      return await sendFinnhubRequest(
        res,
        '/api/v1/stock/profile2',
        {
          symbol,
        },
        {
          cacheKey:
            `profile:${symbol}`,
          cachePolicy:
            CACHE_TTL.profile,
        },
      );
    } catch (error) {
      console.error(
        'Finnhub profile error:',
        error,
      );

      return res
        .status(500)
        .json({
          status: 'error',
          message:
            'Не удалось получить профиль компании.',
        });
    }
  },
);

app.get(
  '/api/market/metrics',
  async (req, res) => {
    try {
      const symbol =
        normalizeSymbol(
          req.query.symbol,
        );

      if (!symbol) {
        return res
          .status(400)
          .json({
            status: 'error',
            message:
              'Некорректный symbol.',
          });
      }

      return await sendFinnhubRequest(
        res,
        '/api/v1/stock/metric',
        {
          symbol,
          metric: 'all',
        },
        {
          cacheKey:
            `metrics:${symbol}`,
          cachePolicy:
            CACHE_TTL.metrics,
        },
      );
    } catch (error) {
      console.error(
        'Finnhub metrics error:',
        error,
      );

      return res
        .status(500)
        .json({
          status: 'error',
          message:
            'Не удалось получить фундаментальные данные.',
        });
    }
  },
);

app.get(
  '/api/market/search',
  async (req, res) => {
    try {
      const query =
        String(
          req.query.q ?? '',
        ).trim();

      if (
        !query ||
        query.length > 80
      ) {
        return res
          .status(400)
          .json({
            status: 'error',
            message:
              'Некорректный поисковый запрос.',
          });
      }

      return await sendFinnhubRequest(
        res,
        '/api/v1/search',
        {
          q: query,
        },
        {
          priority: true,
          cacheKey:
            `search:${query.toLowerCase()}`,
          cachePolicy:
            CACHE_TTL.search,
        },
      );
    } catch (error) {
      console.error(
        'Finnhub search error:',
        error,
      );

      return res
        .status(500)
        .json({
          status: 'error',
          message:
            'Не удалось выполнить поиск.',
        });
    }
  },
);

// ------------------------------------------------------------
// Twelve Data proxy
// ------------------------------------------------------------

app.get(
  '/api/market/time-series',
  async (req, res) => {
    try {
      const symbol =
        normalizeSymbol(
          req.query.symbol,
        );

      if (!symbol) {
        return res
          .status(400)
          .json({
            status: 'error',
            message:
              'Некорректный symbol.',
          });
      }

      const allowedIntervals =
        new Set([
          '5min',
          '30min',
          '1day',
        ]);

      const interval =
        String(
          req.query.interval ??
          '',
        ).trim();

      if (
        !allowedIntervals.has(
          interval,
        )
      ) {
        return res
          .status(400)
          .json({
            status: 'error',
            message:
              'Некорректный interval.',
          });
      }

      const outputSize =
        Number.parseInt(
          String(
            req.query.outputsize ??
            '',
          ),
          10,
        );

      if (
        !Number.isInteger(
          outputSize,
        ) ||
        outputSize < 1 ||
        outputSize > 500
      ) {
        return res
          .status(400)
          .json({
            status: 'error',
            message:
              'Некорректный outputsize.',
          });
      }

      const order =
        req.query.order ===
          'ASC'
          ? 'ASC'
          : 'DESC';

      return await sendTwelveDataRequest(
        res,
        {
          symbol,
          interval,
          outputSize,
          order,
        },
      );
    } catch (error) {
      console.error(
        'Twelve Data time-series error:',
        error,
      );

      return res
        .status(500)
        .json({
          status: 'error',
          message:
            error?.message ??
            'Не удалось получить исторические данные.',
        });
    }
  },
);

// ------------------------------------------------------------
// Sector detection
// ------------------------------------------------------------

function resolveSectorProfile(
  industry,
) {
  const value =
    String(industry ?? '')
      .toLowerCase()
      .trim();

  if (
    value.includes(
      'semiconductor',
    ) ||
    value.includes('chip')
  ) {
    return 'semiconductors';
  }

  if (
    value.includes('bank') ||
    value.includes('banking') ||
    value.includes('financial') ||
    value.includes(
      'capital market',
    ) ||
    value.includes('insurance') ||
    value.includes(
      'credit service',
    ) ||
    value.includes(
      'asset management',
    )
  ) {
    return 'financials';
  }

  if (
    value.includes('software') ||
    value.includes(
      'information technology',
    ) ||
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
    value.includes(
      'personal product',
    ) ||
    value.includes(
      'consumer defensive',
    ) ||
    value.includes(
      'consumer staples',
    )
  ) {
    return 'consumerStaples';
  }

  if (
    value.includes('retail') ||
    value.includes('restaurant') ||
    value.includes('apparel') ||
    value.includes('leisure') ||
    value.includes('travel') ||
    value.includes(
      'consumer cyclical',
    ) ||
    value.includes(
      'consumer discretionary',
    )
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
    value.includes(
      'auto manufacturer',
    )
  ) {
    return 'automotive';
  }

  if (
    value.includes('industrial') ||
    value.includes('machinery') ||
    value.includes('aerospace') ||
    value.includes('defense') ||
    value.includes('construction') ||
    value.includes(
      'transportation',
    )
  ) {
    return 'industrials';
  }

  if (
    value.includes('utility') ||
    value.includes('utilities') ||
    value.includes('electric') ||
    value.includes(
      'water utility',
    )
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

function buildSectorGuidance(
  sectorProfile,
) {
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
- P/S имеет ограниченную аналитическую ценность.
- Основное внимание уделяй ROE, марже, EPS Growth, Revenue Growth,
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

app.post(
  '/api/analyze',
  async (req, res) => {
    try {
      const data = req.body;

      if (
        !data ||
        !data.company ||
        !data.company.symbol
      ) {
        return res
          .status(400)
          .json({
            status: 'error',
            message:
              'Не передан company.symbol',
          });
      }

      if (
        !data.investMind ||
        typeof data
          .investMind
          .confidenceScore !==
        'number'
      ) {
        return res
          .status(400)
          .json({
            status: 'error',
            message:
              'Не передан investMind.confidenceScore',
          });
      }

      const confidenceScore =
        Math.max(
          0,
          Math.min(
            100,
            Math.round(
              data.investMind
                .confidenceScore,
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

13. Не превращай отраслевую особенность
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
              type:
                'json_schema',
              name:
                'investmind_deep_analysis',
              strict: true,
              schema: {
                type:
                  'object',
                properties: {
                  summary: {
                    type:
                      'string',
                  },
                  strengths: {
                    type:
                      'array',
                    items: {
                      type:
                        'string',
                    },
                  },
                  risks: {
                    type:
                      'array',
                    items: {
                      type:
                        'string',
                    },
                  },
                  watch: {
                    type:
                      'array',
                    items: {
                      type:
                        'string',
                    },
                  },
                },
                required: [
                  'summary',
                  'strengths',
                  'risks',
                  'watch',
                ],
                additionalProperties:
                  false,
              },
            },
          },
        });

      if (
        !response.output_text ||
        response.output_text
          .trim()
          .length ===
        0
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
          parsedAnalysis
            .summary ??
          '',

        strengths:
          Array.isArray(
            parsedAnalysis
              .strengths,
          )
            ? parsedAnalysis
              .strengths
            : [],

        risks:
          Array.isArray(
            parsedAnalysis
              .risks,
          )
            ? parsedAnalysis
              .risks
            : [],

        watch:
          Array.isArray(
            parsedAnalysis
              .watch,
          )
            ? parsedAnalysis
              .watch
            : [],

        confidence:
          confidenceScore,
      };

      console.log(
        `Deep Analysis: ${data.company.symbol} | Sector: ${sectorProfile} | Confidence: ${confidenceScore} %`,
      );

      return res.json({
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

      return res
        .status(500)
        .json({
          status: 'error',
          message:
            error?.message ??
            'Не удалось выполнить Deep Analysis',
        });
    }
  },
);

// ------------------------------------------------------------
// AI Comparison — 2 to 4 companies
// ------------------------------------------------------------

app.post(
  '/api/compare',
  async (req, res) => {
    try {
      const data = req.body;

      if (
        !data ||
        !Array.isArray(
          data.companies,
        )
      ) {
        return res
          .status(400)
          .json({
            status: 'error',
            message:
              'Не передан массив companies.',
          });
      }

      if (
        data.companies.length < 2 ||
        data.companies.length > 4
      ) {
        return res
          .status(400)
          .json({
            status: 'error',
            message:
              'AI-сравнение поддерживает от 2 до 4 компаний.',
          });
      }

      for (
        const company
        of data.companies
      ) {
        if (
          !company ||
          !company.symbol ||
          typeof company
            .investMindScore !==
          'number' ||
          typeof company
            .technicalScore !==
          'number' ||
          typeof company
            .fundamentalScore !==
          'number'
        ) {
          return res
            .status(400)
            .json({
              status:
                'error',
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
              resolveSectorProfile(
                company.industry,
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

          input:
            JSON.stringify(
              {
                companies:
                  comparisonData,
              },
              null,
              2,
            ),

          text: {
            format: {
              type:
                'json_schema',

              name:
                'investmind_company_comparison',

              strict: true,

              schema: {
                type:
                  'object',

                properties: {
                  summary: {
                    type:
                      'string',
                  },

                  leader: {
                    type:
                      'string',
                  },

                  leaderReason: {
                    type:
                      'string',
                  },

                  tradeoffs: {
                    type:
                      'array',
                    items: {
                      type:
                        'string',
                    },
                  },

                  companyInsights: {
                    type:
                      'array',

                    items: {
                      type:
                        'object',

                      properties: {
                        symbol: {
                          type:
                            'string',
                        },

                        insight: {
                          type:
                            'string',
                        },
                      },

                      required: [
                        'symbol',
                        'insight',
                      ],

                      additionalProperties:
                        false,
                    },
                  },

                  watch: {
                    type:
                      'array',
                    items: {
                      type:
                        'string',
                    },
                  },
                },

                required: [
                  'summary',
                  'leader',
                  'leaderReason',
                  'tradeoffs',
                  'companyInsights',
                  'watch',
                ],

                additionalProperties:
                  false,
              },
            },
          },
        });

      if (
        !response.output_text ||
        response.output_text
          .trim()
          .length ===
        0
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
          parsedComparison
            .summary ??
          '',

        leader:
          parsedComparison
            .leader ??
          '',

        leaderReason:
          parsedComparison
            .leaderReason ??
          '',

        tradeoffs:
          Array.isArray(
            parsedComparison
              .tradeoffs,
          )
            ? parsedComparison
              .tradeoffs
            : [],

        companyInsights:
          Array.isArray(
            parsedComparison
              .companyInsights,
          )
            ? parsedComparison
              .companyInsights
            : [],

        watch:
          Array.isArray(
            parsedComparison
              .watch,
          )
            ? parsedComparison
              .watch
            : [],
      };

      console.log(
        `AI Comparison: ${comparisonData
          .map(
            (company) =>
              company.symbol,
          )
          .join(' vs ')}`,
      );

      return res.json({
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

      return res
        .status(500)
        .json({
          status: 'error',
          message:
            error?.message ??
            'Не удалось выполнить AI Comparison',
        });
    }
  },
);

// ------------------------------------------------------------
// Start server
// ------------------------------------------------------------

app.listen(
  PORT,
  () => {
    console.log(
      `InvestMind Backend запущен на порту ${PORT}`,
    );
  },
);