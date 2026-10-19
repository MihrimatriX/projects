import path from "path";
import { createDb } from "../scripts/create-db.mjs";

export default function setup() {
  createDb(path.resolve(__dirname, "../test-results/vitest.db"));
}
