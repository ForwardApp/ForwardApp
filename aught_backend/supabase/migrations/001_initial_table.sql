
CREATE TABLE IF NOT EXISTS aught_table (
  id SERIAL PRIMARY KEY,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE aught_table ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable all operations for authenticated users" ON aught_table
  FOR ALL USING (true);


GRANT ALL ON aught_table TO anon;
GRANT ALL ON aught_table TO authenticated;
GRANT ALL ON aught_table TO service_role;


-- Add new columns to aught_table
ALTER TABLE aught_table 
ADD COLUMN first_location_name TEXT,
ADD COLUMN first_location_address TEXT,
ADD COLUMN second_location_name TEXT,
ADD COLUMN second_location_address TEXT;