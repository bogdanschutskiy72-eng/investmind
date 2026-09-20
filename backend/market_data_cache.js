class MarketDataCache {
    constructor({
        maxEntries = 500,
    } = {}) {
        this.maxEntries = maxEntries;

        this.entries = new Map();
        this.inFlight = new Map();
    }

    _now() {
        return Date.now();
    }

    _normalizeKey(key) {
        return String(key ?? '')
            .trim()
            .toLowerCase();
    }

    _cleanupIfNeeded() {
        if (
            this.entries.size <=
            this.maxEntries
        ) {
            return;
        }

        const entries =
            [...this.entries.entries()]
                .sort(
                    (a, b) =>
                        a[1].savedAt -
                        b[1].savedAt,
                );

        const removeCount =
            this.entries.size -
            this.maxEntries;

        for (
            let i = 0;
            i < removeCount;
            i++
        ) {
            this.entries.delete(
                entries[i][0],
            );
        }
    }

    getState(key) {
        const normalizedKey =
            this._normalizeKey(key);

        const entry =
            this.entries.get(
                normalizedKey,
            );

        if (!entry) {
            return {
                state: 'missing',
                value: null,
                savedAt: null,
            };
        }

        const now = this._now();

        if (
            now <= entry.freshUntil
        ) {
            return {
                state: 'fresh',
                value: entry.value,
                savedAt: entry.savedAt,
            };
        }

        if (
            now <= entry.staleUntil
        ) {
            return {
                state: 'stale',
                value: entry.value,
                savedAt: entry.savedAt,
            };
        }

        return {
            state: 'expired',
            value: entry.value,
            savedAt: entry.savedAt,
        };
    }

    set(
        key,
        value,
        {
            ttlMs,
            staleTtlMs = ttlMs,
        },
    ) {
        const normalizedKey =
            this._normalizeKey(key);

        const now = this._now();

        this.entries.set(
            normalizedKey,
            {
                value,
                savedAt: now,
                freshUntil:
                    now + ttlMs,
                staleUntil:
                    now +
                    Math.max(
                        ttlMs,
                        staleTtlMs,
                    ),
            },
        );

        this._cleanupIfNeeded();

        return value;
    }

    hasInFlight(key) {
        const normalizedKey =
            this._normalizeKey(key);

        return this.inFlight.has(
            normalizedKey,
        );
    }

    async _loadAndSave({
        key,
        ttlMs,
        staleTtlMs,
        loader,
    }) {
        const normalizedKey =
            this._normalizeKey(key);

        const existingRequest =
            this.inFlight.get(
                normalizedKey,
            );

        if (existingRequest) {
            return existingRequest;
        }

        const request =
            (async () => {
                try {
                    const value =
                        await loader();

                    this.set(
                        normalizedKey,
                        value,
                        {
                            ttlMs,
                            staleTtlMs,
                        },
                    );

                    return value;
                } finally {
                    this.inFlight.delete(
                        normalizedKey,
                    );
                }
            })();

        this.inFlight.set(
            normalizedKey,
            request,
        );

        return request;
    }

    async getOrLoad({
        key,
        ttlMs,
        staleTtlMs,
        loader,
        staleWhileRevalidate = true,
    }) {
        const normalizedKey =
            this._normalizeKey(key);

        const cached =
            this.getState(
                normalizedKey,
            );

        if (
            cached.state === 'fresh'
        ) {
            return {
                value: cached.value,
                cacheState: 'fresh',
            };
        }

        if (
            cached.state === 'stale' &&
            staleWhileRevalidate
        ) {
            if (
                !this.hasInFlight(
                    normalizedKey,
                )
            ) {
                this._loadAndSave({
                    key: normalizedKey,
                    ttlMs,
                    staleTtlMs,
                    loader,
                }).catch(() => {
                    // Старые данные уже были
                    // отданы пользователю.
                    // Ошибка фонового обновления
                    // не должна ломать ответ.
                });
            }

            return {
                value: cached.value,
                cacheState: 'stale',
            };
        }

        try {
            const value =
                await this._loadAndSave({
                    key: normalizedKey,
                    ttlMs,
                    staleTtlMs,
                    loader,
                });

            return {
                value,
                cacheState: 'network',
            };
        } catch (error) {
            if (
                cached.value != null
            ) {
                return {
                    value: cached.value,
                    cacheState:
                        'expired-fallback',
                };
            }

            throw error;
        }
    }

    remove(key) {
        const normalizedKey =
            this._normalizeKey(key);

        this.entries.delete(
            normalizedKey,
        );
    }

    clear() {
        this.entries.clear();
    }

    get size() {
        return this.entries.size;
    }
}

module.exports = {
    MarketDataCache,
};