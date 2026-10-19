-- Ekran Zamanı — ortak SQLite şema (WPF + WinUI Core)
-- Uygulama ilk açılışta DatabaseService ile oluşturur/günceller.

CREATE TABLE IF NOT EXISTS WindowUsage (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    ProcessName TEXT NOT NULL,
    WindowTitle TEXT,
    StartTime TEXT NOT NULL,
    EndTime TEXT NOT NULL,
    DurationSeconds INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS WebDomainUsage (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    Domain TEXT NOT NULL,
    StartTime TEXT NOT NULL,
    EndTime TEXT NOT NULL,
    DurationSeconds INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS CategoryRules (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    Pattern TEXT NOT NULL,
    Category TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS FocusGoals (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    Name TEXT NOT NULL,
    MatchPattern TEXT NOT NULL,
    TargetMinutes INTEGER NOT NULL,
    RequiredCategory TEXT,
    IsActive INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_windowusage_start ON WindowUsage(StartTime);
CREATE INDEX IF NOT EXISTS idx_webdomain_start ON WebDomainUsage(StartTime);
