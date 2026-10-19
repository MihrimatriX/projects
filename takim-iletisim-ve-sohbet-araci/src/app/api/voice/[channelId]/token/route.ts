import { NextResponse } from "next/server";
import { requireUser } from "@/lib/auth";
import { assertChannelAccess } from "@/lib/channels";
import {
  isLiveKitConfigured,
  LIVEKIT_API_KEY,
  LIVEKIT_API_SECRET,
  LIVEKIT_URL,
} from "@/lib/config";

type RouteContext = { params: Promise<{ channelId: string }> };

export async function POST(_request: Request, context: RouteContext) {
  try {
    if (!isLiveKitConfigured()) {
      return NextResponse.json(
        { error: "LiveKit yapılandırılmamış. LIVEKIT_* env değişkenlerini ayarlayın." },
        { status: 503 },
      );
    }

    const user = await requireUser();
    const { channelId } = await context.params;
    await assertChannelAccess(channelId, user.id);

    const { AccessToken } = await import("livekit-server-sdk");
    const roomName = `channel-${channelId}`;
    const token = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
      identity: user.id,
      name: user.name,
      ttl: "1h",
    });
    token.addGrant({
      roomJoin: true,
      room: roomName,
      canPublish: true,
      canSubscribe: true,
    });

    const jwt = await token.toJwt();
    return NextResponse.json({
      token: jwt,
      url: LIVEKIT_URL,
      room: roomName,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Token alınamadı";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
