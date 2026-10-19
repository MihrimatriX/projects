import { create } from "zustand";
import type { ClipSummary, TagItem } from "@/types/clip";

type Filter = "all" | "unread" | "starred";

type ClipStore = {
  clips: ClipSummary[];
  tags: (TagItem & { count: number })[];
  activeFilter: Filter;
  activeTag: string | null;
  searchQuery: string;
  selectedClipId: string | null;
  isLoading: boolean;
  setClips: (clips: ClipSummary[]) => void;
  setTags: (tags: (TagItem & { count: number })[]) => void;
  setActiveFilter: (filter: Filter) => void;
  setActiveTag: (tag: string | null) => void;
  setSearchQuery: (q: string) => void;
  setSelectedClipId: (id: string | null) => void;
  setIsLoading: (v: boolean) => void;
  updateClipLocal: (id: string, patch: Partial<ClipSummary>) => void;
};

export const useClipStore = create<ClipStore>((set) => ({
  clips: [],
  tags: [],
  activeFilter: "all",
  activeTag: null,
  searchQuery: "",
  selectedClipId: null,
  isLoading: true,
  setClips: (clips) => set({ clips }),
  setTags: (tags) => set({ tags }),
  setActiveFilter: (activeFilter) => set({ activeFilter, activeTag: null }),
  setActiveTag: (activeTag) => set({ activeTag, activeFilter: "all" }),
  setSearchQuery: (searchQuery) => set({ searchQuery }),
  setSelectedClipId: (selectedClipId) => set({ selectedClipId }),
  setIsLoading: (isLoading) => set({ isLoading }),
  updateClipLocal: (id, patch) =>
    set((s) => ({ clips: s.clips.map((c) => (c.id === id ? { ...c, ...patch } : c)) })),
}));
