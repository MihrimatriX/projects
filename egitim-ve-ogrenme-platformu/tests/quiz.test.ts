import { describe, expect, it } from "vitest";
import { parseQuizQuestions, percent, scoreQuiz, validateAnswers } from "@/lib/quiz";

const questions = [
  { question: "A?", options: ["x", "y"], correctIndex: 1 },
  { question: "B?", options: ["x", "y", "z"], correctIndex: 2 },
];

describe("quiz", () => {
  it("bozuk ya da eksik JSON'dan bos/filtrelenmis liste doner", () => {
    expect(parseQuizQuestions("{bozuk")).toEqual([]);
    expect(parseQuizQuestions('{"a":1}')).toEqual([]);
    expect(parseQuizQuestions(JSON.stringify([...questions, { question: "eksik" }]))).toEqual(questions);
  });

  it("dogru cevaplari sayar", () => {
    expect(scoreQuiz(questions, [1, 2])).toEqual({ score: 2, total: 2 });
    expect(scoreQuiz(questions, [0, 2])).toEqual({ score: 1, total: 2 });
  });

  it("eksik, fazla ya da aralik disi cevaplari reddeder", () => {
    expect(validateAnswers(questions, [1, 2])).toBeNull();
    expect(validateAnswers(questions, [1])).toMatch(/Tüm soruları/);
    expect(validateAnswers(questions, [1, 2, 0])).toMatch(/Tüm soruları/);
    expect(validateAnswers(questions, "1,2")).toMatch(/Tüm soruları/);
    expect(validateAnswers(questions, [1, 3])).toMatch(/Geçersiz/);
    expect(validateAnswers(questions, [-1, 0])).toMatch(/Geçersiz/);
    expect(validateAnswers(questions, [0.5, 0])).toMatch(/Geçersiz/);
  });

  it("yuzde hesaplar, 0 soruda 0 doner", () => {
    expect(percent(2, 3)).toBe(67);
    expect(percent(0, 0)).toBe(0);
  });
});
