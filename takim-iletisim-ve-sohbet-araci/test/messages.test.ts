import { createServer } from "http";
import { afterAll, beforeEach, describe, expect, it, vi } from "vitest";

const db = vi.hoisted(() => ({
  message: { findUnique: vi.fn(), update: vi.fn() },
  channelMember: { findUnique: vi.fn() },
}));
vi.mock("@/lib/prisma", () => ({ prisma: db }));

import { editChannelMessage } from "@/lib/messages";
import { getIO, initSocket } from "@/lib/socket-server";

const original = {
  id: "m1",
  channelId: "c1",
  authorId: "u1",
  parentId: null,
  content: "eski",
};

beforeEach(() => {
  vi.clearAllMocks();
  db.message.findUnique.mockResolvedValue(original);
  db.channelMember.findUnique.mockResolvedValue({ id: "cm1" });
  db.message.update.mockImplementation(async ({ data }) => ({ ...original, ...data }));
});

describe("editChannelMessage", () => {
  it("yalnızca yazar düzenleyebilir", async () => {
    await expect(editChannelMessage("m1", "u2", "yeni")).rejects.toThrow("Sadece kendi");
    expect(db.message.update).not.toHaveBeenCalled();
  });

  it("boş veya yalnızca zararlı içerik reddedilir", async () => {
    await expect(editChannelMessage("m1", "u1", "<script>x</script>  ")).rejects.toThrow(
      "Mesaj boş olamaz",
    );
  });

  it("kanal üyeliği gerekir", async () => {
    db.channelMember.findUnique.mockResolvedValue(null);
    await expect(editChannelMessage("m1", "u1", "yeni")).rejects.toThrow("Erişim yok");
  });

  it("içeriği günceller ve düzenlenme zamanını döner", async () => {
    const result = await editChannelMessage("m1", "u1", "  yeni içerik ");
    expect(db.message.update).toHaveBeenCalledWith({
      where: { id: "m1" },
      data: { content: "yeni içerik", editedAt: expect.any(Date) },
    });
    expect(result).toMatchObject({ id: "m1", channelId: "c1", content: "yeni içerik" });
    expect(Date.parse(result.editedAt)).not.toBeNaN();
  });
});

describe("Socket.IO örneği", () => {
  const server = createServer();
  afterAll(() => {
    getIO()?.close();
  });

  it("modülün ayrı kopyalarından da görülür (Next route'ları ayrı paket yükler)", async () => {
    await initSocket(server);
    expect(getIO()).not.toBeNull();

    vi.resetModules();
    const fresh = await import("@/lib/socket-server");
    expect(fresh.getIO()).toBe(getIO());
  });
});
