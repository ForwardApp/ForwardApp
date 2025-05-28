const { supabaseAdmin } = require('../supabase/client');

async function createInitialTable() {
    try {
        console.log('Creating initial tables...');

        const { data, error } = await supabaseAdmin.rpc('execute_sql', {
            query: `
        CREATE TABLE IF NOT EXISTS aught_table (
          id SERIAL PRIMARY KEY,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
        );
        
        ALTER TABLE aught_table ENABLE ROW LEVEL SECURITY;
        
        CREATE POLICY "Enable all operations for authenticated users" ON aught_table
          FOR ALL USING (true);
          
        -- Route locations table for storing user routes
        CREATE TABLE IF NOT EXISTS location_list (
          id SERIAL PRIMARY KEY,
          first_location_name TEXT NOT NULL,
          first_location_address TEXT,
          second_location_name TEXT NOT NULL, 
          second_location_address TEXT,
          first_location_lat DOUBLE PRECISION,
          first_location_lng DOUBLE PRECISION,
          second_location_lat DOUBLE PRECISION,
          second_location_lng DOUBLE PRECISION,
          transport_mode TEXT,
          start_time TEXT,
          end_time TEXT,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
        );
        
        ALTER TABLE location_list ENABLE ROW LEVEL SECURITY;
        
        CREATE POLICY "Enable all operations for users" ON location_list
          FOR ALL USING (true);

        -- Safe zone table for storing safe home locations
        CREATE TABLE IF NOT EXISTS safe_zone (
          id SERIAL PRIMARY KEY,
          location_name TEXT NOT NULL,
          location_address TEXT,
          location_lat DOUBLE PRECISION,
          location_lng DOUBLE PRECISION,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
        );
        
        ALTER TABLE safe_zone ENABLE ROW LEVEL SECURITY;
        
        CREATE POLICY "Enable all operations for safe zone" ON safe_zone
          FOR ALL USING (true);

        -- Bounding box table for storing rectangular areas
        CREATE TABLE IF NOT EXISTS bounding_box (
          id SERIAL PRIMARY KEY,
          point_a_lat DOUBLE PRECISION NOT NULL,
          point_a_lng DOUBLE PRECISION NOT NULL,
          point_b_lat DOUBLE PRECISION NOT NULL,
          point_b_lng DOUBLE PRECISION NOT NULL,
          point_c_lat DOUBLE PRECISION NOT NULL,
          point_c_lng DOUBLE PRECISION NOT NULL,
          point_d_lat DOUBLE PRECISION NOT NULL,
          point_d_lng DOUBLE PRECISION NOT NULL,
          safe_zone_id INTEGER REFERENCES safe_zone(id) ON DELETE CASCADE,
          location_name TEXT,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
          updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
        );
        
        CREATE INDEX IF NOT EXISTS idx_bounding_box_safe_zone_id ON bounding_box(safe_zone_id);
        
        ALTER TABLE bounding_box ENABLE ROW LEVEL SECURITY;
        
        CREATE POLICY "Enable all operations for bounding box" ON bounding_box
          FOR ALL USING (true);
      `
        });

        if (error) {
            console.error('Error creating tables:', error);
            return;
        }

        console.log('Tables created successfully');
        console.log('- aught_table with columns: id, created_at');
        console.log('- location_list table for storing user routes');
        console.log('- safe_zone table for storing safe home locations');
        console.log('- bounding_box table for storing rectangular areas');

    } catch (error) {
        console.error('Migration failed:', error.message);
    }
}

createInitialTable();