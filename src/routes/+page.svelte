<script lang="ts">
  import { invoke } from "@tauri-apps/api/core";
  import { onMount } from "svelte";

  type ProviderId = "openai" | "claude" | "copilot";
  type HealthTone = "calm" | "watch" | "risk";
  type SyncTone = "neutral" | "calm" | "watch" | "risk";
  type OpenAiSnapshotStatus =
    | "ok"
    | "needs_auth"
    | "auth_error"
    | "request_error";

  type OpenAiLimitWindow = {
    usedPercent: number;
    limitWindowSeconds: number | null;
    resetAfterSeconds: number | null;
    resetAt: number | null;
  };

  type OpenAiRateLimitStatus = {
    allowed: boolean;
    limitReached: boolean;
    primaryWindow: OpenAiLimitWindow | null;
    secondaryWindow: OpenAiLimitWindow | null;
  };

  type OpenAiCreditStatus = {
    hasCredits: boolean;
    unlimited: boolean;
    balance: number | null;
  };

  type OpenAiTrackedSubscription = {
    plan: string;
    unit: string;
    used: number;
    limit: number;
  };

  type OpenAiSnapshot = {
    status: OpenAiSnapshotStatus;
    statusMessage: string;
    authPath: string;
    authSource: string;
    fetchedAt: string | null;
    planType: string | null;
    rateLimit: OpenAiRateLimitStatus | null;
    codeReviewRateLimit: OpenAiRateLimitStatus | null;
    credits: OpenAiCreditStatus | null;
    subscription: OpenAiTrackedSubscription | null;
  };

  type Provider = {
    id: ProviderId;
    name: string;
    plan: string;
    unit: string;
    used: number;
    limit: number;
    resetDay: number;
    accent: string;
  };

  type StoredProvider = {
    id: ProviderId;
    used: number;
    limit: number;
    resetDay: number;
  };

  type OpenAiWindowDisplay = {
    key: "primary" | "secondary";
    label: string;
    shortLabel: string;
    usedPercent: number;
    progressWidth: number;
    tone: HealthTone;
    resetAt: number | null;
    resetLabel: string | null;
  };

  const STORAGE_KEY = "usage-provider-picker:v1";
  const LEGACY_STORAGE_KEY = "usage-tracker:v1";
  const numberFormatter = new Intl.NumberFormat("en-US", {
    maximumFractionDigits: 0,
  });
  const dateFormatter = new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
  });
  const dateTimeFormatter = new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });

  const defaultProviders: Provider[] = [
    {
      id: "openai",
      name: "OpenAI",
      plan: "ChatGPT",
      unit: "%",
      used: 0,
      limit: 100,
      resetDay: 1,
      accent: "var(--dracula-green)",
    },
    {
      id: "claude",
      name: "Claude",
      plan: "Claude Pro",
      unit: "sessions",
      used: 18,
      limit: 45,
      resetDay: 4,
      accent: "var(--dracula-orange)",
    },
    {
      id: "copilot",
      name: "GitHub Copilot",
      plan: "Copilot Pro",
      unit: "premium reqs",
      used: 42,
      limit: 150,
      resetDay: 12,
      accent: "var(--dracula-purple)",
    },
  ];

  let providers = $state<Provider[]>(createDefaults());
  let openAiSnapshot = $state<OpenAiSnapshot | null>(null);
  let openAiSyncing = $state(false);
  let statusMessage = $state<string | null>(null);
  let mounted = $state(false);

  let openAiWindows = $derived.by(() => buildOpenAiWindows(openAiSnapshot));
  let rankedProviders = $derived.by(() =>
    [...providers].sort(compareProviders),
  );
  let recommendedProvider = $derived.by(() => rankedProviders[0] ?? null);
  let backupProvider = $derived.by(() => rankedProviders[1] ?? null);

  function createDefaults(): Provider[] {
    return defaultProviders.map((provider) => ({ ...provider }));
  }

  function isRecord(value: unknown): value is Record<string, unknown> {
    return typeof value === "object" && value !== null;
  }

  function isProviderId(value: unknown): value is ProviderId {
    return value === "openai" || value === "claude" || value === "copilot";
  }

  function clamp(value: number, minimum: number, maximum: number): number {
    return Math.min(Math.max(value, minimum), maximum);
  }

  function nonNegativeNumber(value: unknown): number | null {
    return typeof value === "number" && Number.isFinite(value) && value >= 0
      ? value
      : null;
  }

  function positiveNumber(value: unknown): number | null {
    return typeof value === "number" && Number.isFinite(value) && value > 0
      ? value
      : null;
  }

  function validResetDay(value: unknown): number | null {
    return typeof value === "number" &&
      Number.isInteger(value) &&
      value >= 1 &&
      value <= 31
      ? value
      : null;
  }

  function parseStoredProviders(source: string | null): {
    providers: Provider[];
    notice: string | null;
  } {
    const defaults = createDefaults();

    if (!source) {
      return { providers: defaults, notice: null };
    }

    try {
      const parsed: unknown = JSON.parse(source);

      if (!Array.isArray(parsed)) {
        throw new Error("unexpected data shape");
      }

      const parsedById = new Map<ProviderId, Record<string, unknown>>();

      for (const candidate of parsed) {
        if (!isRecord(candidate) || !isProviderId(candidate.id)) {
          continue;
        }

        parsedById.set(candidate.id, candidate);
      }

      const hydrated = defaults.map((fallback) => {
        const candidate = parsedById.get(fallback.id);

        if (!candidate) {
          return fallback;
        }

        return {
          ...fallback,
          used: nonNegativeNumber(candidate.used) ?? fallback.used,
          limit: positiveNumber(candidate.limit) ?? fallback.limit,
          resetDay: validResetDay(candidate.resetDay) ?? fallback.resetDay,
        };
      });

      return { providers: hydrated, notice: null };
    } catch {
      return {
        providers: defaults,
        notice:
          "Could not read the saved limits. Loaded the default tracker instead.",
      };
    }
  }

  function storedProvidersJson(items: Provider[]): string {
    const stored: StoredProvider[] = items.map((provider) => ({
      id: provider.id,
      used: provider.used,
      limit: provider.limit,
      resetDay: provider.resetDay,
    }));

    return JSON.stringify(stored);
  }

  function readProvider(id: ProviderId): Provider | null {
    return providers.find((provider) => provider.id === id) ?? null;
  }

  function isManualProvider(provider: Provider): boolean {
    return provider.id !== "openai";
  }

  function formatWholeNumber(value: number): string {
    return numberFormatter.format(Math.round(value));
  }

  function formatManualUsage(provider: Provider): string {
    return `${formatWholeNumber(provider.used)} / ${formatWholeNumber(provider.limit)} ${provider.unit}`;
  }

  function manualRemaining(provider: Provider): number {
    return Math.round(provider.limit - provider.used);
  }

  function manualRemainingLabel(provider: Provider): string {
    const remaining = manualRemaining(provider);
    const magnitude = formatWholeNumber(Math.abs(remaining));

    if (remaining >= 0) {
      return `${magnitude} ${provider.unit} left`;
    }

    return `${magnitude} ${provider.unit} over`;
  }

  function daysInMonth(year: number, month: number): number {
    return new Date(year, month + 1, 0).getDate();
  }

  function nextResetDate(resetDay: number): Date {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const thisMonth = new Date(
      now.getFullYear(),
      now.getMonth(),
      Math.min(resetDay, daysInMonth(now.getFullYear(), now.getMonth())),
    );

    if (thisMonth >= today) {
      return thisMonth;
    }

    const nextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);

    return new Date(
      nextMonth.getFullYear(),
      nextMonth.getMonth(),
      Math.min(
        resetDay,
        daysInMonth(nextMonth.getFullYear(), nextMonth.getMonth()),
      ),
    );
  }

  function relativeResetLabel(resetDate: Date): string {
    const difference = resetDate.getTime() - Date.now();

    if (difference <= 0) {
      return "now";
    }

    const minutes = Math.ceil(difference / 60_000);

    if (minutes < 60) {
      return `in ${minutes}m`;
    }

    const hours = Math.ceil(minutes / 60);

    if (hours < 24) {
      return `in ${hours}h`;
    }

    const days = Math.ceil(hours / 24);

    if (days === 1) {
      return "tomorrow";
    }

    return `in ${days} days`;
  }

  function formatResetDate(resetDate: Date, includeTime: boolean): string {
    const formatter = includeTime ? dateTimeFormatter : dateFormatter;
    return `${formatter.format(resetDate)} (${relativeResetLabel(resetDate)})`;
  }

  function openAiCadenceLabel(
    window: OpenAiLimitWindow | null,
    fallback: string,
  ): string {
    const seconds = window?.limitWindowSeconds;

    if (!seconds) {
      return fallback;
    }

    if (seconds % 86_400 === 0) {
      const days = seconds / 86_400;

      if (days === 7) {
        return "Weekly";
      }

      if (days === 1) {
        return "Daily";
      }

      return `${days}d`;
    }

    if (seconds % 3_600 === 0) {
      return `${seconds / 3_600}h`;
    }

    return `${Math.round((seconds / 3_600) * 10) / 10}h`;
  }

  function compactCadenceLabel(label: string): string {
    return label === "Weekly" ? "wk" : label;
  }

  function toneForPercent(percent: number): HealthTone {
    if (percent >= 95) {
      return "risk";
    }

    if (percent >= 75) {
      return "watch";
    }

    return "calm";
  }

  function openAiWindowResetLabel(
    window: OpenAiLimitWindow | null,
  ): string | null {
    if (!window || window.resetAt === null) {
      return null;
    }

    return formatResetDate(new Date(window.resetAt * 1000), true);
  }

  function createOpenAiWindow(
    key: OpenAiWindowDisplay["key"],
    window: OpenAiLimitWindow | null,
    fallback: string,
  ): OpenAiWindowDisplay | null {
    if (!window) {
      return null;
    }

    const label = openAiCadenceLabel(window, fallback);

    return {
      key,
      label,
      shortLabel: compactCadenceLabel(label),
      usedPercent: window.usedPercent,
      progressWidth: Math.min(window.usedPercent, 100),
      tone: toneForPercent(window.usedPercent),
      resetAt: window.resetAt,
      resetLabel: openAiWindowResetLabel(window),
    };
  }

  function buildOpenAiWindows(
    snapshot: OpenAiSnapshot | null,
  ): OpenAiWindowDisplay[] {
    if (snapshot?.status !== "ok") {
      return [];
    }

    return [
      createOpenAiWindow(
        "primary",
        snapshot.rateLimit?.primaryWindow ?? null,
        "Primary",
      ),
      createOpenAiWindow(
        "secondary",
        snapshot.rateLimit?.secondaryWindow ?? null,
        "Secondary",
      ),
    ].filter((window): window is OpenAiWindowDisplay => window !== null);
  }

  function tightestOpenAiWindow(): OpenAiWindowDisplay | null {
    let candidate: OpenAiWindowDisplay | null = null;

    for (const window of openAiWindows) {
      if (candidate === null || window.usedPercent > candidate.usedPercent) {
        candidate = window;
      }
    }

    return candidate;
  }

  function openAiSummaryLabel(): string | null {
    if (openAiWindows.length === 0) {
      return null;
    }

    return openAiWindows
      .map(
        (window) => `${window.shortLabel} ${Math.round(window.usedPercent)}%`,
      )
      .join(" | ");
  }

  function providerPressure(provider: Provider): number {
    if (provider.id === "openai") {
      return tightestOpenAiWindow()?.usedPercent ?? 101;
    }

    return (provider.used / provider.limit) * 100;
  }

  function providerTone(provider: Provider): HealthTone {
    return toneForPercent(providerPressure(provider));
  }

  function providerHasComparableData(provider: Provider): boolean {
    return provider.id !== "openai" || openAiWindows.length > 0;
  }

  function providerResetDate(provider: Provider): Date | null {
    if (provider.id === "openai") {
      const tightest = tightestOpenAiWindow();

      if (tightest?.resetAt !== null && tightest?.resetAt !== undefined) {
        return new Date(tightest.resetAt * 1000);
      }

      return null;
    }

    return nextResetDate(provider.resetDay);
  }

  function providerResetLabel(provider: Provider): string {
    const resetDate = providerResetDate(provider);

    if (!resetDate) {
      return "sync needed";
    }

    return formatResetDate(resetDate, provider.id === "openai");
  }

  function providerStatusLabel(provider: Provider): string {
    const pressure = providerPressure(provider);

    if (pressure >= 95) {
      return "Avoid";
    }

    if (recommendedProvider?.id === provider.id) {
      return pressure >= 75 ? "Least tight" : "Best now";
    }

    if (pressure >= 75) {
      return "Watch";
    }

    return "Backup";
  }

  function providerCopy(provider: Provider): string {
    if (provider.id === "openai") {
      const tightest = tightestOpenAiWindow();
      const weekly = openAiWindows.find((window) => window.key === "secondary");

      if (!tightest) {
        return openAiSnapshot?.statusMessage ?? "Sync OpenAI to compare it.";
      }

      if (weekly && tightest.key !== "secondary") {
        return `${tightest.label} is the tightest OpenAI window at ${Math.round(tightest.usedPercent)}%. Weekly is ${Math.round(weekly.usedPercent)}%.`;
      }

      return `${tightest.label} is the tightest OpenAI window at ${Math.round(tightest.usedPercent)}%.`;
    }

    return `${manualRemainingLabel(provider)}. Resets ${providerResetLabel(provider)}.`;
  }

  function recommendationTitle(): string {
    if (!recommendedProvider) {
      return "Sync OpenAI and update the manual providers.";
    }

    const pressure = providerPressure(recommendedProvider);

    if (pressure >= 95) {
      return `Everything is tight. ${recommendedProvider.name} is still the least constrained.`;
    }

    if (pressure >= 75) {
      return `${recommendedProvider.name} is the least tight option right now.`;
    }

    return `Use ${recommendedProvider.name} right now.`;
  }

  function recommendationCopy(): string {
    if (!recommendedProvider) {
      return "This app is only here to show which provider still has room when your limits get tight.";
    }

    const primary = providerCopy(recommendedProvider);

    if (!backupProvider) {
      return primary;
    }

    return `${primary} Backup: ${backupProvider.name}.`;
  }

  function compareProviders(left: Provider, right: Provider): number {
    const leftAvailability = providerHasComparableData(left) ? 0 : 1;
    const rightAvailability = providerHasComparableData(right) ? 0 : 1;

    if (leftAvailability !== rightAvailability) {
      return leftAvailability - rightAvailability;
    }

    const pressureDifference = providerPressure(left) - providerPressure(right);

    if (pressureDifference !== 0) {
      return pressureDifference;
    }

    const leftResetTime =
      providerResetDate(left)?.getTime() ?? Number.POSITIVE_INFINITY;
    const rightResetTime =
      providerResetDate(right)?.getTime() ?? Number.POSITIVE_INFINITY;

    return leftResetTime - rightResetTime;
  }

  function openAiSyncTone(snapshot: OpenAiSnapshot | null): SyncTone {
    if (snapshot === null) {
      return "neutral";
    }

    if (snapshot.status === "ok") {
      return "calm";
    }

    if (snapshot.status === "needs_auth") {
      return "watch";
    }

    return "risk";
  }

  function openAiSyncLabel(snapshot: OpenAiSnapshot | null): string {
    if (snapshot === null) {
      return "Idle";
    }

    if (snapshot.status === "ok") {
      return "Live";
    }

    if (snapshot.status === "needs_auth") {
      return "Setup";
    }

    if (snapshot.status === "auth_error") {
      return "Auth";
    }

    return "Error";
  }

  function updateManualNumber(
    provider: Provider,
    key: "used" | "limit" | "resetDay",
    value: string,
  ): void {
    if (!isManualProvider(provider) || value.trim() === "") {
      return;
    }

    const parsed = Number(value);

    if (!Number.isFinite(parsed)) {
      return;
    }

    if (key === "used") {
      provider.used = Math.max(0, Math.round(parsed));
      return;
    }

    if (key === "limit") {
      provider.limit = Math.max(1, Math.round(parsed));
      return;
    }

    provider.resetDay = clamp(Math.round(parsed), 1, 31);
  }

  function nudgeManualUsage(provider: Provider, delta: number): void {
    if (!isManualProvider(provider)) {
      return;
    }

    provider.used = Math.max(0, provider.used + delta);
  }

  function clearManualUsage(provider: Provider): void {
    if (!isManualProvider(provider)) {
      return;
    }

    provider.used = 0;
  }

  async function refreshOpenAiSnapshot(): Promise<void> {
    openAiSyncing = true;

    try {
      const snapshot = await invoke<OpenAiSnapshot>("fetch_openai_snapshot");
      openAiSnapshot = snapshot;

      if (snapshot.status === "ok" && snapshot.subscription) {
        const provider = readProvider("openai");

        if (provider) {
          provider.plan = snapshot.subscription.plan;
          provider.unit = snapshot.subscription.unit;
          provider.used = snapshot.subscription.used;
          provider.limit = snapshot.subscription.limit;
        }
      }
    } catch (error) {
      const message =
        typeof error === "string"
          ? error
          : error instanceof Error
            ? error.message
            : "OpenAI sync is available in the Tauri desktop shell.";

      openAiSnapshot = {
        status: "request_error",
        statusMessage: message,
        authPath: "~/.codex/auth.json",
        authSource: "codex",
        fetchedAt: null,
        planType: null,
        rateLimit: null,
        codeReviewRateLimit: null,
        credits: null,
        subscription: null,
      };
    } finally {
      openAiSyncing = false;
    }
  }

  onMount(() => {
    const source =
      localStorage.getItem(STORAGE_KEY) ??
      localStorage.getItem(LEGACY_STORAGE_KEY);
    const stored = parseStoredProviders(source);

    providers = stored.providers;
    statusMessage = stored.notice;
    mounted = true;

    void refreshOpenAiSnapshot();
  });

  $effect(() => {
    if (!mounted) {
      return;
    }

    localStorage.setItem(STORAGE_KEY, storedProvidersJson(providers));
  });
</script>

<main class="page-shell">
  <section class="hero-shell">
    <div class="hero-copy">
      <p class="eyebrow">Provider Picker</p>
      <h1>{recommendationTitle()}</h1>
      <p class="hero-text">{recommendationCopy()}</p>
    </div>

    <div class="hero-actions">
      <button
        type="button"
        class="sync-button"
        onclick={refreshOpenAiSnapshot}
        disabled={openAiSyncing}
      >
        {openAiSyncing ? "Syncing..." : "Sync OpenAI"}
      </button>
      <span class={`status-pill status-pill-${openAiSyncTone(openAiSnapshot)}`}>
        {openAiSyncLabel(openAiSnapshot)}
      </span>
    </div>
  </section>

  {#if statusMessage}
    <p class="notice-banner">{statusMessage}</p>
  {/if}

  <section class="provider-grid" aria-label="Provider comparison">
    {#each rankedProviders as provider}
      <article
        class="provider-card"
        style={`--provider-accent: ${provider.accent};`}
      >
        <div class="card-header">
          <div>
            <p class="provider-name">{provider.name}</p>
            <h2>{provider.plan}</h2>
          </div>

          <div class="card-pills">
            {#if provider.id === "openai"}
              <span
                class={`status-pill status-pill-${openAiSyncTone(openAiSnapshot)}`}
              >
                {openAiSyncLabel(openAiSnapshot)}
              </span>
            {/if}
            <span class={`status-pill status-pill-${providerTone(provider)}`}>
              {providerStatusLabel(provider)}
            </span>
          </div>
        </div>

        {#if provider.id === "openai" && openAiWindows.length > 0}
          <div class="window-list">
            {#each openAiWindows as window}
              <section class="window-card">
                <div class="meter-row">
                  <span>{window.label}</span>
                  <span>{Math.round(window.usedPercent)}% used</span>
                </div>

                <div
                  class="progress-track"
                  role="progressbar"
                  aria-valuemin={0}
                  aria-valuemax={100}
                  aria-valuenow={Math.min(window.usedPercent, 100)}
                >
                  <div
                    class={`progress-fill progress-fill-${window.tone}`}
                    style={`width: ${window.progressWidth}%; --provider-accent: ${provider.accent};`}
                  ></div>
                </div>

                {#if window.resetLabel}
                  <p class="window-copy">Resets {window.resetLabel}.</p>
                {/if}
              </section>
            {/each}
          </div>
        {:else}
          <section class="window-card">
            <div class="meter-row">
              <span
                >{provider.id === "openai"
                  ? "OpenAI usage"
                  : formatManualUsage(provider)}</span
              >
              <span>
                {provider.id === "openai" &&
                !providerHasComparableData(provider)
                  ? "sync needed"
                  : `${Math.round(providerPressure(provider))}% used`}
              </span>
            </div>

            <div
              class="progress-track"
              role="progressbar"
              aria-valuemin={0}
              aria-valuemax={provider.limit}
              aria-valuenow={Math.min(provider.used, provider.limit)}
            >
              <div
                class={`progress-fill progress-fill-${providerTone(provider)}`}
                style={`width: ${Math.min(providerPressure(provider), 100)}%; --provider-accent: ${provider.accent};`}
              ></div>
            </div>

            <p class="window-copy">
              {provider.id === "openai"
                ? (openAiSnapshot?.statusMessage ??
                  "Sync OpenAI to compare it.")
                : `Resets ${providerResetLabel(provider)}.`}
            </p>
          </section>
        {/if}

        <p class="provider-copy">{providerCopy(provider)}</p>

        {#if provider.id === "openai" && openAiSummaryLabel()}
          <p class="provider-summary">{openAiSummaryLabel()}</p>
        {/if}
      </article>
    {/each}
  </section>

  <section class="manual-shell" aria-label="Manual providers">
    <div class="section-header">
      <div>
        <p class="eyebrow">Manual Limits</p>
        <h2>Claude and Copilot only</h2>
      </div>
      <p class="section-text">Just enough to keep the recommendation honest.</p>
    </div>

    <div class="manual-list">
      {#each providers.filter(isManualProvider) as provider}
        <section
          class="manual-row"
          style={`--provider-accent: ${provider.accent};`}
        >
          <div class="manual-copy">
            <p class="provider-name">{provider.name}</p>
            <strong>{formatManualUsage(provider)}</strong>
            <small>{providerResetLabel(provider)}</small>
          </div>

          <label class="field">
            <span>Used</span>
            <input
              type="number"
              min="0"
              step="1"
              value={provider.used}
              oninput={(event: Event) =>
                updateManualNumber(
                  provider,
                  "used",
                  event.currentTarget instanceof HTMLInputElement
                    ? event.currentTarget.value
                    : "",
                )}
            />
          </label>

          <label class="field">
            <span>Limit</span>
            <input
              type="number"
              min="1"
              step="1"
              value={provider.limit}
              oninput={(event: Event) =>
                updateManualNumber(
                  provider,
                  "limit",
                  event.currentTarget instanceof HTMLInputElement
                    ? event.currentTarget.value
                    : "",
                )}
            />
          </label>

          <label class="field">
            <span>Resets</span>
            <input
              type="number"
              min="1"
              max="31"
              step="1"
              value={provider.resetDay}
              oninput={(event: Event) =>
                updateManualNumber(
                  provider,
                  "resetDay",
                  event.currentTarget instanceof HTMLInputElement
                    ? event.currentTarget.value
                    : "",
                )}
            />
          </label>

          <div class="manual-actions">
            <button
              type="button"
              class="chip-button"
              onclick={() => nudgeManualUsage(provider, -1)}
            >
              -1
            </button>
            <button
              type="button"
              class="chip-button"
              onclick={() => nudgeManualUsage(provider, 1)}
            >
              +1
            </button>
            <button
              type="button"
              class="chip-button subtle"
              onclick={() => clearManualUsage(provider)}
            >
              Clear
            </button>
          </div>
        </section>
      {/each}
    </div>
  </section>
</main>

<style>
  .page-shell {
    display: grid;
    gap: 0.9rem;
    min-height: 100vh;
    padding: 0.9rem;
    background: radial-gradient(
        circle at top right,
        rgba(139, 233, 253, 0.08),
        transparent 28%
      ),
      radial-gradient(
        circle at top left,
        rgba(189, 147, 249, 0.12),
        transparent 32%
      ),
      var(--dracula-background);
  }

  .hero-shell,
  .provider-card,
  .manual-shell,
  .manual-row,
  .window-card,
  .notice-banner {
    border: 1px solid var(--dracula-current-line);
    border-radius: 12px;
    background: color-mix(
      in srgb,
      var(--dracula-selection) 80%,
      var(--dracula-background)
    );
  }

  .hero-shell,
  .provider-card,
  .manual-shell {
    box-shadow: 0 18px 40px rgba(0, 0, 0, 0.18);
  }

  .hero-shell {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 1rem;
    padding: 1rem;
  }

  .hero-copy,
  .hero-actions,
  .manual-copy,
  .section-header {
    display: grid;
    gap: 0.35rem;
  }

  .eyebrow,
  .provider-name,
  .field span {
    margin: 0;
    color: var(--dracula-comment);
    font-size: 0.72rem;
    letter-spacing: 0.06em;
    text-transform: uppercase;
  }

  h1,
  h2,
  p,
  strong,
  small {
    margin: 0;
  }

  h1 {
    font-size: clamp(1.8rem, 5vw, 2.6rem);
    line-height: 1;
  }

  h2 {
    font-size: 1rem;
    line-height: 1.1;
  }

  .hero-text,
  .provider-copy,
  .window-copy,
  .section-text,
  .notice-banner,
  .manual-copy small {
    color: var(--dracula-comment);
    font-size: 0.82rem;
    line-height: 1.45;
  }

  .hero-actions {
    justify-items: end;
    min-width: 150px;
  }

  .sync-button,
  .chip-button,
  .status-pill,
  input {
    font: inherit;
  }

  .sync-button,
  .chip-button {
    border: 1px solid var(--dracula-current-line);
    border-radius: 999px;
    background: var(--dracula-background);
    color: var(--dracula-foreground);
    cursor: pointer;
    transition:
      background 120ms ease,
      border-color 120ms ease,
      color 120ms ease;
  }

  .sync-button {
    padding: 0.55rem 0.85rem;
  }

  .sync-button:hover,
  .chip-button:hover {
    background: var(--dracula-current-line);
  }

  .sync-button:disabled {
    cursor: not-allowed;
    opacity: 0.6;
  }

  .status-pill {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-height: 1.9rem;
    padding: 0.25rem 0.65rem;
    border: 1px solid transparent;
    border-radius: 999px;
    font-size: 0.72rem;
    white-space: nowrap;
  }

  .status-pill-neutral {
    border-color: rgba(98, 114, 164, 0.4);
    color: var(--dracula-comment);
  }

  .status-pill-calm {
    border-color: rgba(80, 250, 123, 0.35);
    color: var(--dracula-green);
  }

  .status-pill-watch {
    border-color: rgba(241, 250, 140, 0.35);
    color: var(--dracula-yellow);
  }

  .status-pill-risk {
    border-color: rgba(255, 85, 85, 0.35);
    color: var(--dracula-red);
  }

  .notice-banner {
    padding: 0.75rem 0.85rem;
  }

  .provider-grid,
  .manual-list {
    display: grid;
    gap: 0.85rem;
  }

  .provider-grid {
    grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  }

  .provider-card,
  .manual-shell {
    padding: 0.9rem;
  }

  .provider-card {
    display: grid;
    gap: 0.75rem;
    border-color: color-mix(
      in srgb,
      var(--provider-accent) 55%,
      var(--dracula-current-line)
    );
  }

  .card-header,
  .meter-row,
  .manual-row {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 0.75rem;
  }

  .card-pills,
  .manual-actions {
    display: flex;
    align-items: center;
    gap: 0.45rem;
    flex-wrap: wrap;
    justify-content: flex-end;
  }

  .window-list {
    display: grid;
    gap: 0.65rem;
  }

  .window-card {
    display: grid;
    gap: 0.45rem;
    padding: 0.75rem;
    background: color-mix(
      in srgb,
      var(--dracula-background) 74%,
      var(--dracula-selection)
    );
  }

  .meter-row {
    color: var(--dracula-comment);
    font-size: 0.82rem;
  }

  .progress-track {
    width: 100%;
    height: 0.95rem;
    overflow: hidden;
    border: 1px solid
      color-mix(
        in srgb,
        var(--provider-accent) 55%,
        var(--dracula-current-line)
      );
    border-radius: 999px;
    background: color-mix(
      in srgb,
      var(--dracula-selection) 70%,
      var(--dracula-background)
    );
  }

  .progress-fill {
    height: 100%;
    border-radius: 999px;
  }

  .progress-fill-calm {
    background: var(--dracula-green);
  }

  .progress-fill-watch {
    background: var(--dracula-yellow);
  }

  .progress-fill-risk {
    background: var(--dracula-red);
  }

  .provider-summary {
    color: var(--provider-accent);
    font-size: 0.82rem;
  }

  .manual-shell {
    display: grid;
    gap: 0.8rem;
  }

  .section-header {
    grid-template-columns: 1fr auto;
    align-items: end;
  }

  .manual-row {
    padding: 0.8rem;
    border-color: color-mix(
      in srgb,
      var(--provider-accent) 55%,
      var(--dracula-current-line)
    );
    background: color-mix(
      in srgb,
      var(--dracula-background) 74%,
      var(--dracula-selection)
    );
  }

  .manual-copy {
    min-width: 150px;
  }

  .manual-copy strong {
    font-size: 0.9rem;
  }

  .field {
    display: grid;
    gap: 0.35rem;
    min-width: 84px;
  }

  input {
    width: 100%;
    padding: 0.55rem 0.65rem;
    border: 1px solid var(--dracula-current-line);
    border-radius: 10px;
    background: var(--dracula-background);
    color: var(--dracula-foreground);
  }

  input:focus,
  .sync-button:focus,
  .chip-button:focus {
    outline: 1px solid var(--dracula-cyan);
    outline-offset: 2px;
  }

  .chip-button {
    padding: 0.45rem 0.65rem;
  }

  .chip-button.subtle {
    color: var(--dracula-comment);
  }

  @media (max-width: 820px) {
    .hero-shell,
    .manual-row,
    .section-header {
      grid-template-columns: 1fr;
      display: grid;
    }

    .hero-actions,
    .card-pills,
    .manual-actions {
      justify-items: start;
      justify-content: flex-start;
    }

    .manual-row {
      align-items: stretch;
    }
  }
</style>
