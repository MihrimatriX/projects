import {
  S3_ENDPOINT,
  S3_BUCKET,
  S3_ACCESS_KEY,
  S3_SECRET_KEY,
  S3_REGION,
  UPLOAD_DIR,
} from "@/lib/config";
import { mkdir, readFile, writeFile } from "fs/promises";
import path from "path";

export type StorageBackend = "local" | "s3";

export function isS3Configured(): boolean {
  return Boolean(S3_ENDPOINT && S3_BUCKET && S3_ACCESS_KEY && S3_SECRET_KEY);
}

export function defaultStorageBackend(): StorageBackend {
  return isS3Configured() ? "s3" : "local";
}

async function getS3Client() {
  const { S3Client, PutObjectCommand, GetObjectCommand } = await import(
    "@aws-sdk/client-s3"
  );
  const client = new S3Client({
    endpoint: S3_ENDPOINT,
    region: S3_REGION || "us-east-1",
    credentials: {
      accessKeyId: S3_ACCESS_KEY,
      secretAccessKey: S3_SECRET_KEY,
    },
    forcePathStyle: true,
  });
  return { client, PutObjectCommand, GetObjectCommand };
}

export async function saveFile(
  buffer: Buffer,
  key: string,
  mimeType: string,
  backend: StorageBackend = defaultStorageBackend(),
): Promise<{ key: string; backend: StorageBackend }> {
  if (backend === "s3" && isS3Configured()) {
    const { client, PutObjectCommand } = await getS3Client();
    await client.send(
      new PutObjectCommand({
        Bucket: S3_BUCKET,
        Key: key,
        Body: buffer,
        ContentType: mimeType,
      }),
    );
    return { key, backend: "s3" };
  }

  await mkdir(UPLOAD_DIR, { recursive: true });
  await writeFile(path.join(UPLOAD_DIR, key), buffer);
  return { key, backend: "local" };
}

export async function loadFile(
  key: string,
  backend: StorageBackend = "local",
): Promise<Buffer> {
  if (backend === "s3" && isS3Configured()) {
    const { client, GetObjectCommand } = await getS3Client();
    const res = await client.send(
      new GetObjectCommand({ Bucket: S3_BUCKET, Key: key }),
    );
    const bytes = await res.Body?.transformToByteArray();
    if (!bytes) throw new Error("Dosya okunamadı");
    return Buffer.from(bytes);
  }

  return readFile(path.join(UPLOAD_DIR, key));
}
