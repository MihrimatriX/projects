export const SESSION_COOKIE = "sohbet_session";
export const SESSION_DAYS = 30;
export const MAX_UPLOAD_BYTES =
  (Number(process.env.MAX_UPLOAD_MB) || 25) * 1024 * 1024;
export const UPLOAD_DIR = process.env.UPLOAD_DIR || "./uploads";
export const SESSION_SECRET =
  process.env.SESSION_SECRET || "dev-secret-change-in-production-min-32-chars";
export const REDIS_URL = process.env.REDIS_URL || "";
export const LIVEKIT_URL = process.env.LIVEKIT_URL || "";
export const LIVEKIT_API_KEY = process.env.LIVEKIT_API_KEY || "";
export const LIVEKIT_API_SECRET = process.env.LIVEKIT_API_SECRET || "";
export const S3_ENDPOINT = process.env.S3_ENDPOINT || "";
export const S3_BUCKET = process.env.S3_BUCKET || "";
export const S3_ACCESS_KEY = process.env.S3_ACCESS_KEY || "";
export const S3_SECRET_KEY = process.env.S3_SECRET_KEY || "";
export const S3_REGION = process.env.S3_REGION || "us-east-1";
export const RATE_LIMIT_LOGIN_MAX = 10;
export const RATE_LIMIT_LOGIN_WINDOW_MS = 15 * 60 * 1000;

export function isLiveKitConfigured(): boolean {
  return Boolean(LIVEKIT_URL && LIVEKIT_API_KEY && LIVEKIT_API_SECRET);
}
