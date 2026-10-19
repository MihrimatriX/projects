import { beforeEach, describe, expect, it, vi } from "vitest";

const db = vi.hoisted(() => ({
  webhook: { findUnique: vi.fn() },
  user: { findFirst: vi.fn(), create: vi.fn() },
  workspaceMember: { create: vi.fn() },
  channelMember: { upsert: vi.fn(), findUnique: vi.fn(), findMany: vi.fn() },
  message: { create: vi.fn() },
}));
vi.mock("@/lib/prisma", () => ({ prisma: db }));

import { postWebhookMessage } from "@/lib/messages";

const system = { id: "sys", email: "system@webhook.local", name: "Sistem" };

beforeEach(() => {
  vi.clearAllMocks();
  db.user.findFirst.mockResolvedValue(system);
  db.channelMember.findUnique.mockResolvedValue({ id: "cm" });
  db.channelMember.findMany.mockResolvedValue([]);
  db.message.create.mockImplementation(async ({ data }) => ({
    id: "m1",
    ...data,
    createdAt: new Date(),
    editedAt: null,
    author: system,
    attachments: [],
    _count: { replies: 0 },
  }));
});

describe("postWebhookMessage", () => {
  it("sistem kullanıcısı zaten varken ikinci kanala da üye yapılır (Erişim yok hatası olmaz)", async () => {
    for (const channelId of ["c1", "c2"]) {
      db.webhook.findUnique.mockResolvedValue({ name: "CI", channelId, workspaceId: "w1", channel: {} });
      const msg = await postWebhookMessage("tok", "derleme tamam");
      expect(msg.channelId).toBe(channelId);
      expect(db.channelMember.upsert).toHaveBeenLastCalledWith(
        expect.objectContaining({ create: { channelId, userId: "sys" } }),
      );
    }
    expect(db.user.create).not.toHaveBeenCalled();
  });

  it("gönderen adı ve içerik biçimlenir; geçersiz token reddedilir", async () => {
    db.webhook.findUnique.mockResolvedValue({ name: "CI", channelId: "c1", workspaceId: "w1", channel: {} });
    const msg = await postWebhookMessage("tok", "yeşil", "GitHub");
    expect(msg.content).toBe("**[GitHub]** yeşil");

    db.webhook.findUnique.mockResolvedValue(null);
    await expect(postWebhookMessage("yok", "x")).rejects.toThrow("Geçersiz webhook");
  });
});
