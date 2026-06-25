-- ============================================================
-- HRM ERP Supabase Migration
-- Run this in: Supabase Dashboard → SQL Editor
-- ============================================================

-- ── Extensions ──────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── Departments ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  code TEXT UNIQUE,
  manager_id UUID,
  parent_id UUID REFERENCES departments(id),
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO departments (name, code) VALUES
  ('Human Resources', 'HR'),
  ('Engineering', 'ENG'),
  ('Finance', 'FIN'),
  ('Sales', 'SALES'),
  ('Marketing', 'MKT'),
  ('Operations', 'OPS');

-- ── Employees ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS employees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  emp_code TEXT UNIQUE NOT NULL,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  phone TEXT,
  avatar_url TEXT,
  gender TEXT CHECK (gender IN ('male', 'female', 'other')),
  date_of_birth DATE,
  national_id TEXT,
  address TEXT,
  emergency_contact TEXT,
  emergency_phone TEXT,
  department_id UUID REFERENCES departments(id),
  designation TEXT NOT NULL,
  employment_type TEXT NOT NULL DEFAULT 'full_time'
    CHECK (employment_type IN ('full_time', 'part_time', 'contract', 'intern')),
  reports_to UUID REFERENCES employees(id),
  join_date DATE NOT NULL,
  probation_end DATE,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive', 'terminated', 'on_leave')),
  bank_name TEXT,
  bank_account TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── Roles ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('admin', 'hr', 'manager', 'employee')),
  UNIQUE(user_id)
);

-- ── Employee Documents ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS employee_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
  doc_type TEXT NOT NULL,
  doc_name TEXT,
  file_url TEXT NOT NULL,
  expiry_date DATE,
  uploaded_by UUID REFERENCES employees(id),
  uploaded_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── Attendance ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES employees(id),
  date DATE NOT NULL,
  check_in TIMESTAMPTZ,
  check_out TIMESTAMPTZ,
  check_in_location JSONB,  -- {lat, lng}
  check_out_location JSONB,
  status TEXT NOT NULL DEFAULT 'absent'
    CHECK (status IN ('present', 'absent', 'late', 'half_day', 'holiday', 'weekend')),
  work_hours NUMERIC(5, 2) GENERATED ALWAYS AS (
    CASE
      WHEN check_in IS NOT NULL AND check_out IS NOT NULL
      THEN EXTRACT(EPOCH FROM (check_out - check_in)) / 3600
      ELSE NULL
    END
  ) STORED,
  overtime_hours NUMERIC(5, 2) DEFAULT 0,
  note TEXT,
  approved_by UUID REFERENCES employees(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(employee_id, date)
);

-- ── Leave Types ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS leave_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  code TEXT UNIQUE,
  max_days_per_year INTEGER DEFAULT 0,
  carry_forward_days INTEGER DEFAULT 0,
  is_paid BOOLEAN DEFAULT TRUE,
  gender_specific TEXT CHECK (gender_specific IN ('male', 'female', 'all')) DEFAULT 'all',
  description TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO leave_types (name, code, max_days_per_year, is_paid) VALUES
  ('Annual Leave', 'AL', 14, true),
  ('Sick Leave', 'SL', 10, true),
  ('Casual Leave', 'CL', 7, true),
  ('Unpaid Leave', 'UL', 30, false),
  ('Maternity Leave', 'ML', 90, true),
  ('Paternity Leave', 'PL', 14, true);

-- ── Leave Balance ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS leave_balances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES employees(id),
  leave_type_id UUID NOT NULL REFERENCES leave_types(id),
  year INTEGER NOT NULL,
  entitled_days INTEGER DEFAULT 0,
  used_days INTEGER DEFAULT 0,
  pending_days INTEGER DEFAULT 0,
  balance_days INTEGER GENERATED ALWAYS AS (entitled_days - used_days - pending_days) STORED,
  UNIQUE(employee_id, leave_type_id, year)
);

-- ── Leave Requests ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS leave_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES employees(id),
  leave_type_id UUID NOT NULL REFERENCES leave_types(id),
  from_date DATE NOT NULL,
  to_date DATE NOT NULL,
  total_days INTEGER NOT NULL,
  reason TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  approved_by UUID REFERENCES employees(id),
  approval_note TEXT,
  applied_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── Salary Structures ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS salary_structures (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES employees(id),
  basic_salary NUMERIC(12, 2) NOT NULL DEFAULT 0,
  house_allowance NUMERIC(12, 2) DEFAULT 0,
  transport_allowance NUMERIC(12, 2) DEFAULT 0,
  medical_allowance NUMERIC(12, 2) DEFAULT 0,
  meal_allowance NUMERIC(12, 2) DEFAULT 0,
  other_allowance NUMERIC(12, 2) DEFAULT 0,
  tax_deduction NUMERIC(12, 2) DEFAULT 0,
  insurance_deduction NUMERIC(12, 2) DEFAULT 0,
  provident_fund NUMERIC(12, 2) DEFAULT 0,
  other_deduction NUMERIC(12, 2) DEFAULT 0,
  effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
  is_active BOOLEAN DEFAULT TRUE,
  created_by UUID REFERENCES employees(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── Payroll Runs ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payroll_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
  year INTEGER NOT NULL CHECK (year >= 2020),
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'processing', 'approved', 'paid', 'cancelled')),
  processed_by UUID REFERENCES employees(id),
  approved_by UUID REFERENCES employees(id),
  total_gross NUMERIC(14, 2) DEFAULT 0,
  total_deductions NUMERIC(14, 2) DEFAULT 0,
  total_net NUMERIC(14, 2) DEFAULT 0,
  employee_count INTEGER DEFAULT 0,
  notes TEXT,
  processed_at TIMESTAMPTZ,
  approved_at TIMESTAMPTZ,
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(month, year)
);

-- ── Payslips ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payslips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payroll_run_id UUID NOT NULL REFERENCES payroll_runs(id),
  employee_id UUID NOT NULL REFERENCES employees(id),
  basic_salary NUMERIC(12, 2) NOT NULL DEFAULT 0,
  house_allowance NUMERIC(12, 2) DEFAULT 0,
  transport_allowance NUMERIC(12, 2) DEFAULT 0,
  medical_allowance NUMERIC(12, 2) DEFAULT 0,
  other_allowances NUMERIC(12, 2) DEFAULT 0,
  gross_salary NUMERIC(12, 2) NOT NULL DEFAULT 0,
  tax_deduction NUMERIC(12, 2) DEFAULT 0,
  insurance_deduction NUMERIC(12, 2) DEFAULT 0,
  provident_fund NUMERIC(12, 2) DEFAULT 0,
  absent_deduction NUMERIC(12, 2) DEFAULT 0,
  other_deductions NUMERIC(12, 2) DEFAULT 0,
  total_deductions NUMERIC(12, 2) NOT NULL DEFAULT 0,
  net_salary NUMERIC(12, 2) NOT NULL DEFAULT 0,
  working_days INTEGER,
  paid_days INTEGER,
  absent_days INTEGER,
  leave_days INTEGER,
  overtime_hours NUMERIC(5, 2) DEFAULT 0,
  overtime_pay NUMERIC(12, 2) DEFAULT 0,
  pdf_url TEXT,
  status TEXT NOT NULL DEFAULT 'generated'
    CHECK (status IN ('generated', 'sent', 'acknowledged')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(payroll_run_id, employee_id)
);

-- ── Holidays ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS holidays (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  date DATE NOT NULL UNIQUE,
  is_optional BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── Row Level Security ────────────────────────────────────────
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE payslips ENABLE ROW LEVEL SECURITY;
ALTER TABLE salary_structures ENABLE ROW LEVEL SECURITY;

-- HR & Admin full access helper function
CREATE OR REPLACE FUNCTION is_hr_or_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
    AND role IN ('hr', 'admin')
  )
$$ LANGUAGE sql SECURITY DEFINER;

-- Employees: HR/Admin sees all; employees see own record
CREATE POLICY "employees_select" ON employees FOR SELECT USING (
  user_id = auth.uid() OR is_hr_or_admin()
);
CREATE POLICY "employees_insert" ON employees FOR INSERT
  WITH CHECK (is_hr_or_admin());
CREATE POLICY "employees_update" ON employees FOR UPDATE
  USING (is_hr_or_admin());

-- Attendance: Own record or HR
CREATE POLICY "attendance_select" ON attendance FOR SELECT USING (
  employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
  OR is_hr_or_admin()
);
CREATE POLICY "attendance_insert" ON attendance FOR INSERT WITH CHECK (
  employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
  OR is_hr_or_admin()
);
CREATE POLICY "attendance_update" ON attendance FOR UPDATE USING (
  employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
  OR is_hr_or_admin()
);

-- Payslips: Own only or HR
CREATE POLICY "payslips_select" ON payslips FOR SELECT USING (
  employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
  OR is_hr_or_admin()
);

-- ── Triggers: updated_at ──────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_employees_updated
  BEFORE UPDATE ON employees
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_leave_updated
  BEFORE UPDATE ON leave_requests
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── Indexes ───────────────────────────────────────────────────
CREATE INDEX idx_employees_dept ON employees(department_id);
CREATE INDEX idx_employees_status ON employees(status);
CREATE INDEX idx_attendance_date ON attendance(employee_id, date);
CREATE INDEX idx_leave_requests_emp ON leave_requests(employee_id, status);
CREATE INDEX idx_payslips_run ON payslips(payroll_run_id);
CREATE INDEX idx_payslips_emp ON payslips(employee_id);

-- ============================================================
-- DONE! Your HRM ERP database is ready.
-- ============================================================
