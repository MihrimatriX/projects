export type ParseStatus = "pending" | "done" | "failed";

export type TagItem = {
  id: string;
  name: string;
};

export type HighlightItem = {
  id: string;
  text: string;
  note: string | null;
  color: string;
  createdAt: string;
};

export type ClipItem = {
  id: string;
  url: string;
  title: string;
  excerpt: string | null;
  content: string | null;
  domain: string | null;
  readingMinutes: number | null;
  parseStatus: ParseStatus;
  isRead: boolean;
  isStarred: boolean;
  createdAt: string;
  tags: TagItem[];
  highlights: HighlightItem[];
};

export type ClipSummary = Omit<ClipItem, "content" | "highlights"> & {
  highlightCount: number;
};

export type FeedItem = {
  id: string;
  url: string;
  title: string | null;
  lastFetched: string | null;
  createdAt: string;
};
