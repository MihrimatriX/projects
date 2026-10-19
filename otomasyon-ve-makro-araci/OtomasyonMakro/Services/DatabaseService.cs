using System;
using System.Collections.Generic;
using System.IO;
using Microsoft.Data.Sqlite;
using OtomasyonMakro.Models;

namespace OtomasyonMakro.Services
{
    public class DatabaseService
    {
        private readonly string _dbFolder;
        private readonly string _dbPath;
        private readonly string _connectionString;

        public const string DataDirEnvVar = "OTOMASYONMAKRO_DATA_DIR";

        public DatabaseService() : this(ResolveDataFolder()) { }

        public DatabaseService(string dataFolder)
        {
            _dbFolder = dataFolder;
            _dbPath = Path.Combine(_dbFolder, "macros.db");
            _connectionString = $"Data Source={_dbPath}";

            Directory.CreateDirectory(_dbFolder);
            InitializeDatabase();
        }

        public string DataFolder => _dbFolder;

        /// <summary>%LOCALAPPDATA%\OtomasyonMakro (kurulum klasörü yazılabilir olmayabilir); ortam değişkeniyle değiştirilebilir.</summary>
        public static string ResolveDataFolder()
        {
            var overrideDir = Environment.GetEnvironmentVariable(DataDirEnvVar);
            if (!string.IsNullOrWhiteSpace(overrideDir)) return overrideDir;

            var folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "OtomasyonMakro");
            MigrateLegacyData(Path.Combine(AppContext.BaseDirectory, "data"), folder);
            return folder;
        }

        // Eski sürümler macros.db'yi exe yanındaki data\ altında tutuyordu; yeni konumda yoksa bir kez kopyalanır.
        internal static void MigrateLegacyData(string legacyFolder, string targetFolder)
        {
            var src = Path.Combine(legacyFolder, "macros.db");
            var dst = Path.Combine(targetFolder, "macros.db");
            if (!File.Exists(src) || File.Exists(dst)) return;
            try
            {
                Directory.CreateDirectory(targetFolder);
                File.Copy(src, dst);
            }
            catch (IOException) { /* kopyalanamazsa yeni veritabanıyla devam */ }
        }

        private void InitializeDatabase()
        {
            using (var conn = new SqliteConnection(_connectionString))
            {
                conn.Open();

                using (var pragmaCmd = new SqliteCommand("PRAGMA foreign_keys = ON;", conn))
                {
                    pragmaCmd.ExecuteNonQuery();
                }

                string createProfilesQuery = @"
                    CREATE TABLE IF NOT EXISTS Profiles (
                        Id INTEGER PRIMARY KEY AUTOINCREMENT,
                        Name TEXT NOT NULL,
                        Description TEXT,
                        Hotkey TEXT,
                        TargetProcessName TEXT
                    );";
                using (var cmd = new SqliteCommand(createProfilesQuery, conn))
                {
                    cmd.ExecuteNonQuery();
                }

                string createStepsQuery = @"
                    CREATE TABLE IF NOT EXISTS MacroSteps (
                        ProfileId INTEGER NOT NULL,
                        Sequence INTEGER NOT NULL,
                        ActionType INTEGER NOT NULL,
                        MouseX INTEGER,
                        MouseY INTEGER,
                        Text TEXT,
                        DelayMs INTEGER,
                        PRIMARY KEY (ProfileId, Sequence),
                        FOREIGN KEY (ProfileId) REFERENCES Profiles(Id) ON DELETE CASCADE
                    );";
                using (var cmd = new SqliteCommand(createStepsQuery, conn))
                {
                    cmd.ExecuteNonQuery();
                }

                MigrateSchema(conn);
                SeedDefaultData(conn);
            }
        }

        private static void MigrateSchema(SqliteConnection conn)
        {
            AddColumnIfNotExists(conn, "Profiles", "SchemaVersion", "INTEGER DEFAULT 2");
            AddColumnIfNotExists(conn, "Profiles", "ScheduleEnabled", "INTEGER DEFAULT 0");
            AddColumnIfNotExists(conn, "Profiles", "ScheduleTime", "TEXT DEFAULT '09:00'");
            AddColumnIfNotExists(conn, "Profiles", "ScheduleDays", "TEXT DEFAULT '1,2,3,4,5'");
            AddColumnIfNotExists(conn, "MacroSteps", "UiElementName", "TEXT");
            AddColumnIfNotExists(conn, "MacroSteps", "UiAutomationId", "TEXT");
            AddColumnIfNotExists(conn, "MacroSteps", "UiClassName", "TEXT");
            AddColumnIfNotExists(conn, "MacroSteps", "JumpToSequence", "INTEGER DEFAULT 0");
            AddColumnIfNotExists(conn, "Profiles", "RepeatCount", "INTEGER DEFAULT 1");
        }

        private static void AddColumnIfNotExists(SqliteConnection conn, string table, string column, string definition)
        {
            bool exists = false;
            using (var cmd = new SqliteCommand($"PRAGMA table_info({table});", conn))
            using (var reader = cmd.ExecuteReader())
            {
                while (reader.Read())
                {
                    if (reader.GetString(1).Equals(column, StringComparison.OrdinalIgnoreCase))
                    {
                        exists = true;
                        break;
                    }
                }
            }

            if (!exists)
            {
                using var alter = new SqliteCommand($"ALTER TABLE {table} ADD COLUMN {column} {definition};", conn);
                alter.ExecuteNonQuery();
            }
        }

        private void SeedDefaultData(SqliteConnection conn)
        {
            string checkQuery = "SELECT COUNT(*) FROM Profiles;";
            long count;
            using (var cmd = new SqliteCommand(checkQuery, conn))
            {
                count = Convert.ToInt64(cmd.ExecuteScalar());
            }

            if (count > 0) return;

            string insertProfile1 = @"
                INSERT INTO Profiles (Name, Description, Hotkey, TargetProcessName, SchemaVersion) 
                VALUES ('Hızlı Metin Yapıştır & Enter', 'Odaktaki metin alanına otomatik yazı yazar ve ardından Enter tuşuna basar.', 'Ctrl+Alt+F1', 'notepad', 2);
                SELECT last_insert_rowid();";

            long id1;
            using (var cmd = new SqliteCommand(insertProfile1, conn))
            {
                id1 = Convert.ToInt64(cmd.ExecuteScalar());
            }

            string insertSteps1 = @"
                INSERT INTO MacroSteps (ProfileId, Sequence, ActionType, MouseX, MouseY, Text, DelayMs, JumpToSequence) VALUES
                (@PId, 1, 3, 0, 0, 'Merhaba {{user}}! Otomasyon v{{env:USERNAME}}', 0, 0),
                (@PId, 2, 2, 0, 0, NULL, 200, 0),
                (@PId, 3, 1, 0, 0, 'RETURN', 0, 0);";

            using (var cmd = new SqliteCommand(insertSteps1, conn))
            {
                cmd.Parameters.AddWithValue("@PId", id1);
                cmd.ExecuteNonQuery();
            }

            string insertProfile2 = @"
                INSERT INTO Profiles (Name, Description, Hotkey, TargetProcessName, SchemaVersion) 
                VALUES ('Koşullu Not Defteri Kontrolü', 'Not Defteri odaktaysa metin yazar; değilse adım 4''e atlar.', 'Ctrl+Alt+F2', 'notepad', 2);
                SELECT last_insert_rowid();";

            long id2;
            using (var cmd = new SqliteCommand(insertProfile2, conn))
            {
                id2 = Convert.ToInt64(cmd.ExecuteScalar());
            }

            string insertSteps2 = @"
                INSERT INTO MacroSteps (ProfileId, Sequence, ActionType, MouseX, MouseY, Text, DelayMs, JumpToSequence) VALUES
                (@PId, 1, 5, 0, 0, 'Not Defteri', 0, 4),
                (@PId, 2, 3, 0, 0, 'Koşul sağlandı — yazıldı.', 0, 0),
                (@PId, 3, 1, 0, 0, 'RETURN', 0, 0),
                (@PId, 4, 3, 0, 0, 'Not Defteri odakta değildi.', 0, 0);";

            using (var cmd = new SqliteCommand(insertSteps2, conn))
            {
                cmd.Parameters.AddWithValue("@PId", id2);
                cmd.ExecuteNonQuery();
            }
        }

        public List<MacroProfile> GetProfiles()
        {
            var profiles = new List<MacroProfile>();
            using (var conn = new SqliteConnection(_connectionString))
            {
                conn.Open();

                string fetchProfiles = @"
                    SELECT Id, Name, Description, Hotkey, TargetProcessName,
                           SchemaVersion, ScheduleEnabled, ScheduleTime, ScheduleDays, RepeatCount
                    FROM Profiles ORDER BY Id ASC;";
                using (var cmd = new SqliteCommand(fetchProfiles, conn))
                using (var reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        profiles.Add(new MacroProfile
                        {
                            Id = reader.GetInt32(0),
                            Name = reader.GetString(1),
                            Description = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                            Hotkey = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
                            TargetProcessName = reader.IsDBNull(4) ? string.Empty : reader.GetString(4),
                            SchemaVersion = reader.IsDBNull(5) ? 2 : reader.GetInt32(5),
                            ScheduleEnabled = !reader.IsDBNull(6) && reader.GetInt32(6) == 1,
                            ScheduleTime = reader.IsDBNull(7) ? "09:00" : reader.GetString(7),
                            ScheduleDays = reader.IsDBNull(8) ? "1,2,3,4,5" : reader.GetString(8),
                            RepeatCount = reader.IsDBNull(9) ? 1 : reader.GetInt32(9)
                        });
                    }
                }

                foreach (var profile in profiles)
                {
                    string fetchSteps = @"
                        SELECT Sequence, ActionType, MouseX, MouseY, Text, DelayMs,
                               UiElementName, UiAutomationId, UiClassName, JumpToSequence
                        FROM MacroSteps 
                        WHERE ProfileId = @PId 
                        ORDER BY Sequence ASC;";
                    using (var cmd = new SqliteCommand(fetchSteps, conn))
                    {
                        cmd.Parameters.AddWithValue("@PId", profile.Id);
                        using (var reader = cmd.ExecuteReader())
                        {
                            while (reader.Read())
                            {
                                profile.Steps.Add(ReadStep(reader));
                            }
                        }
                    }
                }
            }

            return profiles;
        }

        private static MacroStep ReadStep(SqliteDataReader reader)
        {
            return new MacroStep
            {
                Sequence = reader.GetInt32(0),
                ActionType = (MacroActionType)reader.GetInt32(1),
                MouseX = reader.IsDBNull(2) ? 0 : reader.GetInt32(2),
                MouseY = reader.IsDBNull(3) ? 0 : reader.GetInt32(3),
                Text = reader.IsDBNull(4) ? null : reader.GetString(4),
                DelayMs = reader.IsDBNull(5) ? 0 : reader.GetInt32(5),
                UiElementName = reader.IsDBNull(6) ? null : reader.GetString(6),
                UiAutomationId = reader.IsDBNull(7) ? null : reader.GetString(7),
                UiClassName = reader.IsDBNull(8) ? null : reader.GetString(8),
                JumpToSequence = reader.IsDBNull(9) ? 0 : reader.GetInt32(9)
            };
        }

        public void SaveProfile(MacroProfile profile)
        {
            profile.SchemaVersion = 2;
            profile.RenumberSteps(); // atlama hedefleri sıra numarasıyla birlikte güncellenir

            using (var conn = new SqliteConnection(_connectionString))
            {
                conn.Open();
                using (var transaction = conn.BeginTransaction())
                {
                    try
                    {
                        if (profile.Id == 0)
                        {
                            string insertProfile = @"
                                INSERT INTO Profiles (Name, Description, Hotkey, TargetProcessName,
                                    SchemaVersion, ScheduleEnabled, ScheduleTime, ScheduleDays, RepeatCount) 
                                VALUES (@Name, @Description, @Hotkey, @TargetProcessName,
                                    @SchemaVersion, @ScheduleEnabled, @ScheduleTime, @ScheduleDays, @RepeatCount);
                                SELECT last_insert_rowid();";
                            using (var cmd = new SqliteCommand(insertProfile, conn, transaction))
                            {
                                BindProfileParams(cmd, profile);
                                profile.Id = (int)Convert.ToInt64(cmd.ExecuteScalar());
                            }
                        }
                        else
                        {
                            string updateProfile = @"
                                UPDATE Profiles 
                                SET Name = @Name, Description = @Description, Hotkey = @Hotkey,
                                    TargetProcessName = @TargetProcessName, SchemaVersion = @SchemaVersion,
                                    ScheduleEnabled = @ScheduleEnabled, ScheduleTime = @ScheduleTime,
                                    ScheduleDays = @ScheduleDays, RepeatCount = @RepeatCount
                                WHERE Id = @Id;";
                            using (var cmd = new SqliteCommand(updateProfile, conn, transaction))
                            {
                                BindProfileParams(cmd, profile);
                                cmd.Parameters.AddWithValue("@Id", profile.Id);
                                cmd.ExecuteNonQuery();
                            }
                        }

                        string deleteSteps = "DELETE FROM MacroSteps WHERE ProfileId = @PId;";
                        using (var cmd = new SqliteCommand(deleteSteps, conn, transaction))
                        {
                            cmd.Parameters.AddWithValue("@PId", profile.Id);
                            cmd.ExecuteNonQuery();
                        }

                        foreach (var step in profile.Steps)
                        {
                            string insertStep = @"
                                INSERT INTO MacroSteps (ProfileId, Sequence, ActionType, MouseX, MouseY, Text, DelayMs,
                                    UiElementName, UiAutomationId, UiClassName, JumpToSequence) 
                                VALUES (@PId, @Seq, @ActionType, @MouseX, @MouseY, @Text, @DelayMs,
                                    @UiElementName, @UiAutomationId, @UiClassName, @JumpToSequence);";
                            using (var cmd = new SqliteCommand(insertStep, conn, transaction))
                            {
                                cmd.Parameters.AddWithValue("@PId", profile.Id);
                                cmd.Parameters.AddWithValue("@Seq", step.Sequence);
                                cmd.Parameters.AddWithValue("@ActionType", (int)step.ActionType);
                                cmd.Parameters.AddWithValue("@MouseX", step.MouseX);
                                cmd.Parameters.AddWithValue("@MouseY", step.MouseY);
                                cmd.Parameters.AddWithValue("@Text", (object?)step.Text ?? DBNull.Value);
                                cmd.Parameters.AddWithValue("@DelayMs", step.DelayMs);
                                cmd.Parameters.AddWithValue("@UiElementName", (object?)step.UiElementName ?? DBNull.Value);
                                cmd.Parameters.AddWithValue("@UiAutomationId", (object?)step.UiAutomationId ?? DBNull.Value);
                                cmd.Parameters.AddWithValue("@UiClassName", (object?)step.UiClassName ?? DBNull.Value);
                                cmd.Parameters.AddWithValue("@JumpToSequence", step.JumpToSequence);
                                cmd.ExecuteNonQuery();
                            }
                        }

                        transaction.Commit();
                    }
                    catch
                    {
                        transaction.Rollback();
                        throw;
                    }
                }
            }
        }

        private static void BindProfileParams(SqliteCommand cmd, MacroProfile profile)
        {
            cmd.Parameters.AddWithValue("@Name", profile.Name);
            cmd.Parameters.AddWithValue("@Description", profile.Description);
            cmd.Parameters.AddWithValue("@Hotkey", profile.Hotkey);
            cmd.Parameters.AddWithValue("@TargetProcessName", profile.TargetProcessName);
            cmd.Parameters.AddWithValue("@SchemaVersion", profile.SchemaVersion);
            cmd.Parameters.AddWithValue("@ScheduleEnabled", profile.ScheduleEnabled ? 1 : 0);
            cmd.Parameters.AddWithValue("@ScheduleTime", profile.ScheduleTime);
            cmd.Parameters.AddWithValue("@ScheduleDays", profile.ScheduleDays);
            cmd.Parameters.AddWithValue("@RepeatCount", Math.Max(0, profile.RepeatCount));
        }

        public void DeleteProfile(int id)
        {
            using (var conn = new SqliteConnection(_connectionString))
            {
                conn.Open();

                using (var cmd = new SqliteCommand("DELETE FROM MacroSteps WHERE ProfileId = @PId;", conn))
                {
                    cmd.Parameters.AddWithValue("@PId", id);
                    cmd.ExecuteNonQuery();
                }

                using (var cmd = new SqliteCommand("DELETE FROM Profiles WHERE Id = @Id;", conn))
                {
                    cmd.Parameters.AddWithValue("@Id", id);
                    cmd.ExecuteNonQuery();
                }
            }
        }
    }
}
