-- FOMRA HRMS Database Schema
-- Run: psql -U postgres -c "CREATE DATABASE fomra_hrms;" then psql -U postgres -d fomra_hrms -f schema.sql

-- Users (authentication)
CREATE TABLE IF NOT EXISTS users (
  id           SERIAL PRIMARY KEY,
  name         VARCHAR(255)        NOT NULL,
  email        VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255)       NOT NULL,
  role         VARCHAR(50)         NOT NULL DEFAULT 'employee',
  department   VARCHAR(100),
  created_at   TIMESTAMP DEFAULT NOW()
);

-- Employees
CREATE TABLE IF NOT EXISTS employees (
  id               SERIAL PRIMARY KEY,
  employee_id      VARCHAR(50) UNIQUE NOT NULL,
  name             VARCHAR(255)       NOT NULL,
  email            VARCHAR(255),
  mobile           VARCHAR(20),
  department       VARCHAR(100),
  designation      VARCHAR(100),
  manager          VARCHAR(255),
  joining_date     DATE,
  salary           NUMERIC(12,2),
  address          TEXT,
  blood_group      VARCHAR(10),
  bank_account     VARCHAR(50),
  ifsc             VARCHAR(20),
  emergency_name   VARCHAR(255),
  emergency_phone  VARCHAR(20),
  documents        TEXT,
  created_at       TIMESTAMP DEFAULT NOW()
);

-- Leave applications
CREATE TABLE IF NOT EXISTS leave_applications (
  id              SERIAL PRIMARY KEY,
  leave_id        VARCHAR(20) UNIQUE NOT NULL,
  employee_name   VARCHAR(255)       NOT NULL,
  employee_id     INT REFERENCES employees(id) ON DELETE SET NULL,
  department      VARCHAR(100),
  leave_type      VARCHAR(100)       NOT NULL,
  from_date       DATE               NOT NULL,
  to_date         DATE               NOT NULL,
  days            INT                NOT NULL,
  reason          TEXT,
  applied_on      TIMESTAMP DEFAULT NOW(),
  manager_status  VARCHAR(20)        NOT NULL DEFAULT 'pending',
  hr_status       VARCHAR(20)        NOT NULL DEFAULT 'pending',
  CONSTRAINT chk_manager_status CHECK (manager_status IN ('pending','approved','denied')),
  CONSTRAINT chk_hr_status      CHECK (hr_status      IN ('pending','approved','denied'))
);

-- Tasks
CREATE TABLE IF NOT EXISTS tasks (
  id                SERIAL PRIMARY KEY,
  task_id           VARCHAR(20) UNIQUE NOT NULL,
  name              VARCHAR(255)       NOT NULL,
  description       TEXT,
  priority          VARCHAR(20)        NOT NULL DEFAULT 'medium',
  start_date        DATE               NOT NULL,
  due_date          DATE               NOT NULL,
  weightage         INT                DEFAULT 0,
  status            VARCHAR(20)        NOT NULL DEFAULT 'assigned',
  assigned_employee VARCHAR(255),
  team_members      TEXT[],
  department        VARCHAR(100),
  attachment        VARCHAR(500),
  created_at        TIMESTAMP DEFAULT NOW(),
  CONSTRAINT chk_priority CHECK (priority IN ('low','medium','high','critical')),
  CONSTRAINT chk_status   CHECK (status   IN ('assigned','pending','inProgress','completed','delayed','rejected'))
);

-- Attendance records
CREATE TABLE IF NOT EXISTS attendance_records (
  id              SERIAL PRIMARY KEY,
  employee_name   VARCHAR(255),
  date            DATE      NOT NULL,
  check_in_time   VARCHAR(20),
  check_out_time  VARCHAR(20),
  location        VARCHAR(500),
  status          VARCHAR(50),
  created_at      TIMESTAMP DEFAULT NOW()
);

-- Default HR seed user (password: Admin@123)
INSERT INTO users (name, email, password_hash, role)
VALUES (
  'HR Admin',
  'hr@fomrahousing.in',
  '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
  'hr'
) ON CONFLICT (email) DO NOTHING;
