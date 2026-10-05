"use client";

import { useCallback, useEffect, useState } from "react";
import Sidebar from "@/components/Sidebar";
import ArticleList from "@/components/ArticleList";
import ArticleReader from "@/components/ArticleReader";
import KeyboardManager from "@/components/KeyboardManager";
import FeedModal from "@/components/FeedModal";
import { useFeedStore } from "@/lib/store";
import { getFeeds, getArticles, refreshFeeds, seedDefaultFeeds } from "@/app/actions";
import { getFetchIntervalMinutes, fetchIntervalMs } from "@/lib/fetch-interval";
import { useResponsiveLayout } from "@/lib/layout-hooks";
import { syncMessage } from "@/lib/format";

export default function Home() {
  const {
    setFeeds,
    setArticles,
    activeFilter,
    setIsLoading,
    setIsRefreshing,
    layout,
    mobilePanel,
    setMobilePanel,
    kbdHidden,
    toast,
  } = useFeedStore();

  const [tick, setTick] = useState(0);
  const mounted = useResponsiveLayout();

  const loadArticles = useCallback(async () => {
    setIsLoading(true);
    const articlesData = await getArticles(activeFilter);
    setArticles(articlesData);
    setIsLoading(false);
  }, [activeFilter, setArticles, setIsLoading]);

  const loadAll = useCallback(async () => {
    const [feedsData, articlesData] = await Promise.all([
      getFeeds(),
      getArticles(activeFilter),
    ]);
    setFeeds(feedsData);
    setArticles(articlesData);
  }, [activeFilter, setFeeds, setArticles]);

  // ponytail: seed bir kez, sonra feeds+articles yükle
  useEffect(() => {
    let cancelled = false;
    (async () => {
      setIsLoading(true);
      await seedDefaultFeeds();
      if (!cancelled) await loadAll();
      if (!cancelled) setIsLoading(false);
    })();
    return () => {
      cancelled = true;
    };
  }, [tick, loadAll, setIsLoading]);

  useEffect(() => {
    loadArticles();
  }, [activeFilter, loadArticles]);

  // Arka plan senkronu: ayarlardaki aralıkla refreshFeeds çalışır; aralık değişince olay ile yeniden kurulur
  useEffect(() => {
    let timer: ReturnType<typeof setInterval>;
    const runSync = async () => {
      await refreshFeeds();
      setTick((p) => p + 1);
    };
    const start = () => {
      clearInterval(timer);
      timer = setInterval(runSync, fetchIntervalMs(getFetchIntervalMinutes()));
    };
    start();
    window.addEventListener("rss-fetch-interval-changed", start);
    return () => {
      clearInterval(timer);
      window.removeEventListener("rss-fetch-interval-changed", start);
    };
  }, []);

  const handleRefresh = async () => {
    setIsRefreshing(true);
    try {
      const res = await refreshFeeds();
      await loadAll();
      useFeedStore.getState().showToast(syncMessage(res));
    } finally {
      setIsRefreshing(false);
    }
  };

  const shellAttrs = mounted
    ? ({
        className: "app-shell",
        "data-layout": layout,
        "data-mobile-panel": mobilePanel,
      } as const)
    : ({ className: "app-shell app-shell--boot" } as const);

  return (
    <>
      <a href="#reader-content" className="skip-link">
        Ana içeriğe atla
      </a>
      <KeyboardManager onRefresh={handleRefresh} />
      <FeedModal onAdded={() => setTick((p) => p + 1)} />

      <div {...shellAttrs}>
        <Sidebar onRefresh={() => setTick((p) => p + 1)} />
        <ArticleList onRefresh={handleRefresh} onReload={() => setTick((p) => p + 1)} />
        <ArticleReader />

        <nav className="mobile-tabs" aria-label="Mobil gezinme">
          {(
            [
              { id: "feeds" as const, label: "Feedler" },
              { id: "list" as const, label: "Liste" },
              { id: "reader" as const, label: "Oku" },
            ] as const
          ).map(({ id, label }) => (
            <button
              key={id}
              type="button"
              className={`mobile-tab${mobilePanel === id ? " active" : ""}`}
              aria-current={mobilePanel === id ? "page" : undefined}
              onClick={() => setMobilePanel(id)}
            >
              {label}
            </button>
          ))}
        </nav>

        <div className={`kbd-bar${mounted && kbdHidden ? " is-hidden" : ""}`}>
          <span>
            <kbd>J</kbd>
            <kbd>K</kbd> gezin
          </span>
          <span>
            <kbd>M</kbd> okundu
          </span>
          <span>
            <kbd>S</kbd> yıldız
          </span>
          <span>
            <kbd>O</kbd> orijinal
          </span>
          <span>
            <kbd>R</kbd> yenile
          </span>
          <span>
            <kbd>/</kbd> ara
          </span>
          <span>
            <kbd>?</kbd> ipuçları
          </span>
        </div>
      </div>

      <div className={`toast${toast ? " show" : ""}`} role="status" aria-live="polite">
        {toast}
      </div>
    </>
  );
}
