import { create } from "zustand";

export interface FeedItem {
  id: string;
  url: string;
  title: string;
  siteUrl: string | null;
  folder: string;
  lastFetchedAt: string | Date;
  lastError?: string | null;
  _count?: { articles: number };
}

export interface ArticleItem {
  id: string;
  feedId: string;
  title: string;
  link: string;
  author: string | null;
  content: string | null;
  snippet: string | null;
  publishedAt: string | Date;
  isRead: boolean;
  isStarred: boolean;
  feed?: { title: string; folder: string };
}

export type FilterType = {
  feedId?: string;
  folder?: string;
  status?: "all" | "unread" | "starred";
};

export type MobilePanel = "feeds" | "list" | "reader";
export type LayoutMode = "three-col" | "mobile";

interface FeedState {
  feeds: FeedItem[];
  articles: ArticleItem[];
  selectedArticle: ArticleItem | null;
  activeFilter: FilterType;
  isLoading: boolean;
  isRefreshing: boolean;
  searchTerm: string;
  mobilePanel: MobilePanel;
  layout: LayoutMode;
  kbdHidden: boolean;
  toast: string | null;
  feedModalOpen: boolean;
  folderOpen: Record<string, boolean>;

  setFeeds: (feeds: FeedItem[]) => void;
  setArticles: (articles: ArticleItem[]) => void;
  setSelectedArticle: (article: ArticleItem | null) => void;
  setActiveFilter: (filter: FilterType) => void;
  setIsLoading: (v: boolean) => void;
  setIsRefreshing: (v: boolean) => void;
  setSearchTerm: (term: string) => void;
  setMobilePanel: (panel: MobilePanel) => void;
  setLayout: (layout: LayoutMode) => void;
  setKbdHidden: (hidden: boolean) => void;
  showToast: (msg: string) => void;
  clearToast: () => void;
  setFeedModalOpen: (open: boolean) => void;
  toggleFolder: (folder: string) => void;

  toggleReadLocal: (articleId: string) => void;
  toggleStarLocal: (articleId: string) => void;
}

export const useFeedStore = create<FeedState>((set, get) => ({
  feeds: [],
  articles: [],
  selectedArticle: null,
  activeFilter: { status: "unread" },
  isLoading: false,
  isRefreshing: false,
  searchTerm: "",
  mobilePanel: "list",
  layout: "three-col",
  kbdHidden: false,
  toast: null,
  feedModalOpen: false,
  folderOpen: {},

  setFeeds: (feeds) => set({ feeds }),
  setArticles: (articles) => set({ articles }),
  setSelectedArticle: (selectedArticle) => set({ selectedArticle }),
  setActiveFilter: (activeFilter) =>
    set({ activeFilter, selectedArticle: null, searchTerm: "" }),
  setIsLoading: (isLoading) => set({ isLoading }),
  setIsRefreshing: (isRefreshing) => set({ isRefreshing }),
  setSearchTerm: (searchTerm) => set({ searchTerm }),
  setMobilePanel: (mobilePanel) => set({ mobilePanel }),
  setLayout: (layout: LayoutMode) => set({ layout }),
  setKbdHidden: (kbdHidden) => set({ kbdHidden }),
  showToast: (msg) => {
    set({ toast: msg });
    setTimeout(() => {
      if (get().toast === msg) set({ toast: null });
    }, 2200);
  },
  clearToast: () => set({ toast: null }),
  setFeedModalOpen: (feedModalOpen) => set({ feedModalOpen }),
  toggleFolder: (folder) =>
    set((s) => ({
      folderOpen: { ...s.folderOpen, [folder]: !s.folderOpen[folder] },
    })),

  toggleReadLocal: (articleId) =>
    set((state) => {
      const article = state.articles.find((a) => a.id === articleId);
      if (!article) return state;

      const wasRead = article.isRead;
      const nextArticles = state.articles.map((a) =>
        a.id === articleId ? { ...a, isRead: !a.isRead } : a
      );
      const nextSelected =
        state.selectedArticle?.id === articleId
          ? { ...state.selectedArticle, isRead: !state.selectedArticle.isRead }
          : state.selectedArticle;

      const nextFeeds = state.feeds.map((feed) => {
        if (feed.id !== article.feedId) return feed;
        const n = feed._count?.articles ?? 0;
        return {
          ...feed,
          _count: { articles: Math.max(0, wasRead ? n + 1 : n - 1) },
        };
      });

      return { articles: nextArticles, selectedArticle: nextSelected, feeds: nextFeeds };
    }),

  toggleStarLocal: (articleId) =>
    set((state) => ({
      articles: state.articles.map((a) =>
        a.id === articleId ? { ...a, isStarred: !a.isStarred } : a
      ),
      selectedArticle:
        state.selectedArticle?.id === articleId
          ? { ...state.selectedArticle, isStarred: !state.selectedArticle.isStarred }
          : state.selectedArticle,
    })),
}));
