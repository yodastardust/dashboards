-- Supabase Schema for Appointment Touches Tracking
-- Run this in your Supabase SQL Editor

-- Table for individual appointment touch records
CREATE TABLE IF NOT EXISTS appointment_touches (
    id BIGSERIAL PRIMARY KEY,
    contact_id TEXT NOT NULL,
    phone TEXT,
    name TEXT,
    first_name TEXT,
    last_name TEXT,
    date_added TIMESTAMPTZ,
    auction_date TEXT,
    auction_type TEXT,
    property_address TEXT,
    city TEXT,
    state TEXT,
    county TEXT,
    calls_before_appointment INTEGER DEFAULT 0,
    sms_before_appointment INTEGER DEFAULT 0,
    total_touches INTEGER DEFAULT 0,
    avg_days_before_auction INTEGER,
    call_details JSONB,
    sms_details JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table for daily summary statistics
CREATE TABLE IF NOT EXISTS daily_touch_summary (
    id BIGSERIAL PRIMARY KEY,
    date DATE NOT NULL UNIQUE,
    new_appointments INTEGER DEFAULT 0,
    total_calls INTEGER DEFAULT 0,
    total_sms INTEGER DEFAULT 0,
    total_touches INTEGER DEFAULT 0,
    avg_touches_to_convert DECIMAL(4,1),
    avg_days_before_auction INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_appointment_touches_phone ON appointment_touches(phone);
CREATE INDEX IF NOT EXISTS idx_appointment_touches_date_added ON appointment_touches(date_added);
CREATE INDEX IF NOT EXISTS idx_appointment_touches_auction_type ON appointment_touches(auction_type);
CREATE INDEX IF NOT EXISTS idx_daily_summary_date ON daily_touch_summary(date);

-- Enable Row Level Security (optional but recommended)
ALTER TABLE appointment_touches ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_touch_summary ENABLE ROW LEVEL SECURITY;

-- Create policies for authenticated access (adjust as needed)
CREATE POLICY "Allow all for authenticated users" ON appointment_touches
    FOR ALL USING (true);

CREATE POLICY "Allow all for authenticated users" ON daily_touch_summary
    FOR ALL USING (true);

-- Useful views for reporting

-- View: Touch distribution summary
CREATE OR REPLACE VIEW touch_distribution AS
SELECT
    CASE
        WHEN total_touches = 0 THEN '0'
        WHEN total_touches <= 2 THEN '1-2'
        WHEN total_touches <= 5 THEN '3-5'
        WHEN total_touches <= 10 THEN '6-10'
        ELSE '10+'
    END AS touch_bucket,
    COUNT(*) as contact_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) as percentage
FROM appointment_touches
GROUP BY 1
ORDER BY
    CASE touch_bucket
        WHEN '0' THEN 1
        WHEN '1-2' THEN 2
        WHEN '3-5' THEN 3
        WHEN '6-10' THEN 4
        ELSE 5
    END;

-- View: Performance by auction type
CREATE OR REPLACE VIEW auction_type_performance AS
SELECT
    COALESCE(auction_type, 'Unknown') as auction_type,
    COUNT(*) as contact_count,
    ROUND(AVG(total_touches), 1) as avg_touches,
    ROUND(AVG(calls_before_appointment), 1) as avg_calls,
    ROUND(AVG(sms_before_appointment), 1) as avg_sms,
    ROUND(AVG(avg_days_before_auction), 0) as avg_days_before_auction
FROM appointment_touches
GROUP BY 1
ORDER BY contact_count DESC;

-- View: Weekly trends
CREATE OR REPLACE VIEW weekly_trends AS
SELECT
    DATE_TRUNC('week', date) as week_start,
    SUM(new_appointments) as total_appointments,
    ROUND(AVG(avg_touches_to_convert), 1) as avg_touches,
    ROUND(AVG(avg_days_before_auction), 0) as avg_days_before_auction
FROM daily_touch_summary
GROUP BY 1
ORDER BY 1 DESC;

-- Sample queries for reporting:

-- Get today's summary
-- SELECT * FROM daily_touch_summary WHERE date = CURRENT_DATE;

-- Get contacts that converted with 1-2 touches (quick wins)
-- SELECT * FROM appointment_touches WHERE total_touches <= 2 ORDER BY date_added DESC;

-- Get contacts that required 10+ touches (persistence wins)
-- SELECT * FROM appointment_touches WHERE total_touches >= 10 ORDER BY date_added DESC;

-- Analyze timing patterns
-- SELECT
--     CASE
--         WHEN avg_days_before_auction >= 60 THEN '60+ days'
--         WHEN avg_days_before_auction >= 30 THEN '30-59 days'
--         WHEN avg_days_before_auction >= 14 THEN '14-29 days'
--         WHEN avg_days_before_auction >= 7 THEN '7-13 days'
--         ELSE 'Under 7 days'
--     END as timing_bucket,
--     COUNT(*) as count,
--     ROUND(AVG(total_touches), 1) as avg_touches
-- FROM appointment_touches
-- WHERE avg_days_before_auction IS NOT NULL
-- GROUP BY 1;
