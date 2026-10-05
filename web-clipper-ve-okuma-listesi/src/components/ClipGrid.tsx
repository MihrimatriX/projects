import ClipCard from "@/components/ClipCard";
import type { ClipSummary } from "@/types/clip";

type Props = {
  clips: ClipSummary[];
  selectedId?: string | null;
};

export default function ClipGrid({ clips, selectedId }: Props) {
  return (
    <div className="article-grid">
      {clips.map((clip) => (
        <ClipCard key={clip.id} clip={clip} selected={selectedId === clip.id} />
      ))}
    </div>
  );
}
