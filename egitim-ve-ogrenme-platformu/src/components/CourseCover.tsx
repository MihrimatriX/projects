type Props = {
  src: string;
  alt: string;
  title?: string;
  levelLabel?: string;
  className?: string;
  overlay?: boolean;
};

export function CourseCover({ src, alt, title, levelLabel, className = "", overlay = false }: Props) {
  return (
    <div className={`relative aspect-video overflow-hidden bg-bg-muted ${className}`}>
      {/* ponytail: SVG kapaklar — next/image SVG kısıtı yok, img yeterli */}
      <img src={src} alt={alt} className="h-full w-full object-cover" loading="lazy" />
      {overlay && (title || levelLabel) && (
        <div className="absolute inset-0 flex items-end justify-between gap-3 bg-gradient-to-t from-black/55 via-black/10 to-transparent p-[18px] text-white">
          {title && <strong className="max-w-[12ch] text-lg leading-tight tracking-tight">{title}</strong>}
          {levelLabel && (
            <span className="rounded-full bg-white/88 px-2 py-1 text-[11px] font-bold uppercase tracking-[0.07em] text-bg-dark">
              {levelLabel}
            </span>
          )}
        </div>
      )}
    </div>
  );
}
