-- ============================================================
-- HRM ERP — CRM Module Migration
-- Run AFTER 001_hrm_schema.sql
-- Paste in: Supabase Dashboard → SQL Editor
-- ============================================================

-- ── CRM Leads ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS crm_leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_name TEXT NOT NULL,
  contact_name TEXT,
  email TEXT,
  phone TEXT,
  website TEXT,
  industry TEXT,
  company_size TEXT,
  deal_value NUMERIC(14, 2) DEFAULT 0,
  currency TEXT DEFAULT 'USD',
  stage TEXT NOT NULL DEFAULT 'new'
    CHECK (stage IN ('new','contacted','qualified','proposal','negotiation','won','lost')),
  source TEXT,          -- website, referral, cold_call, social, event
  priority TEXT DEFAULT 'medium' CHECK (priority IN ('low','medium','high')),
  assigned_to UUID REFERENCES employees(id),
  expected_close DATE,
  last_contacted DATE,
  notes TEXT,
  lost_reason TEXT,
  tags TEXT[],
  created_by UUID REFERENCES employees(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── CRM Lead Activities ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS crm_lead_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID NOT NULL REFERENCES crm_leads(id) ON DELETE CASCADE,
  activity_type TEXT NOT NULL CHECK (activity_type IN ('call','email','meeting','note','task','stage_change')),
  subject TEXT,
  description TEXT,
  scheduled_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  outcome TEXT,
  performed_by UUID REFERENCES employees(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── CRM Clients (converted leads / direct) ───────────────────
CREATE TABLE IF NOT EXISTS crm_clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID REFERENCES crm_leads(id),       -- link to origin lead
  company_name TEXT NOT NULL,
  contact_name TEXT,
  email TEXT,
  phone TEXT,
  website TEXT,
  industry TEXT,
  address TEXT,
  country TEXT,
  contract_value NUMERIC(14, 2) DEFAULT 0,
  contract_start DATE,
  contract_end DATE,
  status TEXT DEFAULT 'active' CHECK (status IN ('active','inactive','churned')),
  account_manager UUID REFERENCES employees(id),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── CRM Tasks ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS crm_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID REFERENCES crm_leads(id) ON DELETE CASCADE,
  client_id UUID REFERENCES crm_clients(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  due_date DATE,
  priority TEXT DEFAULT 'medium' CHECK (priority IN ('low','medium','high')),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','in_progress','done','cancelled')),
  assigned_to UUID REFERENCES employees(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── RLS ───────────────────────────────────────────────────────
ALTER TABLE crm_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm_clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm_lead_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm_tasks ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read & write (HR/Sales access)
CREATE POLICY "crm_leads_all" ON crm_leads
  FOR ALL USING (auth.uid() IS NOT NULL);

CREATE POLICY "crm_clients_all" ON crm_clients
  FOR ALL USING (auth.uid() IS NOT NULL);

CREATE POLICY "crm_activities_all" ON crm_lead_activities
  FOR ALL USING (auth.uid() IS NOT NULL);

CREATE POLICY "crm_tasks_all" ON crm_tasks
  FOR ALL USING (auth.uid() IS NOT NULL);

-- ── Triggers ─────────────────────────────────────────────────
CREATE TRIGGER trg_crm_leads_updated
  BEFORE UPDATE ON crm_leads
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_crm_clients_updated
  BEFORE UPDATE ON crm_clients
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── Auto-create client when lead is Won ──────────────────────
CREATE OR REPLACE FUNCTION auto_create_client_on_won()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.stage = 'won' AND OLD.stage != 'won' THEN
    INSERT INTO crm_clients (lead_id, company_name, contact_name, email, phone, contract_value, account_manager)
    VALUES (NEW.id, NEW.company_name, NEW.contact_name, NEW.email, NEW.phone, NEW.deal_value, NEW.assigned_to)
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_lead_won_to_client
  AFTER UPDATE ON crm_leads
  FOR EACH ROW EXECUTE FUNCTION auto_create_client_on_won();

-- ── Log stage changes automatically ──────────────────────────
CREATE OR REPLACE FUNCTION log_lead_stage_change()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.stage != OLD.stage THEN
    INSERT INTO crm_lead_activities (lead_id, activity_type, subject, description)
    VALUES (NEW.id, 'stage_change', 'Stage Updated', 'Moved from ' || OLD.stage || ' to ' || NEW.stage);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_stage_change
  AFTER UPDATE ON crm_leads
  FOR EACH ROW EXECUTE FUNCTION log_lead_stage_change();

-- ── Indexes ───────────────────────────────────────────────────
CREATE INDEX idx_crm_leads_stage ON crm_leads(stage);
CREATE INDEX idx_crm_leads_assigned ON crm_leads(assigned_to);
CREATE INDEX idx_crm_leads_created ON crm_leads(created_at DESC);
CREATE INDEX idx_crm_clients_status ON crm_clients(status);
CREATE INDEX idx_crm_tasks_due ON crm_tasks(due_date);
CREATE INDEX idx_crm_tasks_assigned ON crm_tasks(assigned_to);

-- ── Sample seed data ──────────────────────────────────────────
-- (Uncomment after adding at least one employee)
-- INSERT INTO crm_leads (company_name, contact_name, email, deal_value, stage, source) VALUES
--   ('Acme Corp', 'John Smith', 'john@acme.com', 15000, 'qualified', 'referral'),
--   ('TechStart Inc', 'Sarah Lee', 'sarah@techstart.io', 8500, 'proposal', 'website'),
--   ('Global Ventures', 'Mike Chen', 'mike@gv.com', 42000, 'negotiation', 'cold_call'),
--   ('Swift Solutions', 'Emma Brown', 'emma@swift.co', 6000, 'contacted', 'social'),
--   ('Apex Digital', 'Tom Wilson', 'tom@apex.com', 28000, 'won', 'event');

-- ============================================================
-- CRM module is ready!
-- ============================================================
