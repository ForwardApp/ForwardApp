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

        -- Device locations table for tracking multiple devices
        CREATE TABLE IF NOT EXISTS device_locations (
          id SERIAL PRIMARY KEY,
          device_id TEXT NOT NULL,
          device_name TEXT,
          generated_id TEXT NOT NULL,
          tracking_active BOOLEAN DEFAULT true,
          latitude DOUBLE PRECISION NOT NULL,
          longitude DOUBLE PRECISION NOT NULL,
          timestamp TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_device_locations_device_id ON device_locations(device_id);
        CREATE INDEX IF NOT EXISTS idx_device_locations_generated_id ON device_locations(generated_id);
        CREATE INDEX IF NOT EXISTS idx_device_locations_timestamp ON device_locations(timestamp);

        ALTER TABLE device_locations ENABLE ROW LEVEL SECURITY;
        CREATE POLICY "Enable all operations for device_locations" ON device_locations
          FOR ALL USING (true);
          
        -- Connected devices table for tracking connections between devices
        CREATE TABLE IF NOT EXISTS connected_devices (
          id SERIAL PRIMARY KEY,
          device_location_id INTEGER REFERENCES device_locations(id) ON DELETE CASCADE,
          generated_id TEXT NOT NULL,
          connected_device_id INTEGER REFERENCES device_locations(id) ON DELETE CASCADE,
          connection_name TEXT,
          trusted BOOLEAN DEFAULT false,
          last_connected TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_connected_devices_device_location_id ON connected_devices(device_location_id);
        CREATE INDEX IF NOT EXISTS idx_connected_devices_generated_id ON connected_devices(generated_id);
        CREATE INDEX IF NOT EXISTS idx_connected_devices_connected_device_id ON connected_devices(connected_device_id);

        ALTER TABLE connected_devices ENABLE ROW LEVEL SECURITY;
        CREATE POLICY "Enable all operations for connected_devices" ON connected_devices
          FOR ALL USING (true);

        -- Add a unique constraint to prevent duplicate connections
        ALTER TABLE connected_devices ADD CONSTRAINT unique_device_connection 
          UNIQUE (device_location_id, generated_id);
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
        console.log('- device_locations table for tracking multiple devices');

    } catch (error) {
        console.error('Migration failed:', error.message);
    }
}

createInitialTable();