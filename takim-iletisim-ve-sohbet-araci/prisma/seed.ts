import { randomBytes, scryptSync } from "crypto";
import { prisma } from "../src/lib/prisma";

const SECRET = process.env.SESSION_SECRET || "dev-secret-change-in-production-min-32-chars";

function hashPassword(password: string): string {
  const salt = randomBytes(16).toString("hex");
  const hash = scryptSync(password, salt + SECRET, 64).toString("hex");
  return `${salt}:${hash}`;
}

async function main() {
  const workspace = await prisma.workspace.upsert({
    where: { slug: "acme" },
    update: {},
    create: { name: "Acme Takım", slug: "acme" },
  });

  const demoUsers = [
    { email: "mehmet@acme.local", name: "Mehmet", password: "demo1234" },
    { email: "ayse@acme.local", name: "Ayşe", password: "demo1234" },
    { email: "can@acme.local", name: "Can", password: "demo1234" },
  ];

  const users = [];
  for (const u of demoUsers) {
    const user = await prisma.user.upsert({
      where: { email: u.email },
      update: {},
      create: {
        email: u.email,
        name: u.name,
        passwordHash: hashPassword(u.password),
        status: "OFFLINE",
      },
    });
    users.push(user);
    await prisma.workspaceMember.upsert({
      where: { workspaceId_userId: { workspaceId: workspace.id, userId: user.id } },
      update: {},
      create: { workspaceId: workspace.id, userId: user.id, role: "member" },
    });
  }

  const channelNames = ["genel", "geliştirme", "tasarım"];
  for (const name of channelNames) {
    const channel = await prisma.channel.upsert({
      where: { workspaceId_name: { workspaceId: workspace.id, name } },
      update: {},
      create: { workspaceId: workspace.id, name, type: "PUBLIC" },
    });
    for (const user of users) {
      await prisma.channelMember.upsert({
        where: { channelId_userId: { channelId: channel.id, userId: user.id } },
        update: {},
        create: { channelId: channel.id, userId: user.id },
      });
    }
  }

  const genel = await prisma.channel.findFirst({
    where: { workspaceId: workspace.id, name: "genel" },
  });
  if (genel) {
    const existing = await prisma.message.count({ where: { channelId: genel.id } });
    if (existing === 0) {
      await prisma.message.createMany({
        data: [
          {
            channelId: genel.id,
            authorId: users[0].id,
            content: "Deploy tamam. @Ayşe kontrol eder misin?",
          },
          {
            channelId: genel.id,
            authorId: users[1].id,
            content: "Staging'de test ettim, sorun yok ✅",
          },
          {
            channelId: genel.id,
            authorId: users[0].id,
            content: "Harika! **CI** yeşil, herkes rahat olsun.",
          },
        ],
      });
    }
  }

  console.log("Seed tamamlandı. Demo: mehmet@acme.local / demo1234");
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
