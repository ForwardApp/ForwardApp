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
          
        -- Notification system table for tracking device notifications related to bounding boxes
        CREATE TABLE IF NOT EXISTS notifications (
          id SERIAL PRIMARY KEY,
          device_location_id INTEGER REFERENCES device_locations(id) ON DELETE CASCADE,
          safe_zone_id INTEGER REFERENCES safe_zone(id) ON DELETE CASCADE,
          connected_device_id INTEGER REFERENCES connected_devices(id) ON DELETE CASCADE,
          location_name TEXT,
          status TEXT NOT NULL,
          details TEXT,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_notifications_device_location_id ON notifications(device_location_id);
        CREATE INDEX IF NOT EXISTS idx_notifications_safe_zone_id ON notifications(safe_zone_id);
        CREATE INDEX IF NOT EXISTS idx_notifications_connected_device_id ON notifications(connected_device_id);
        CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at);

        ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
        CREATE POLICY "Enable all operations for notifications" ON notifications
          FOR ALL USING (true);
          
        -- Task list table for storing user tasks
        CREATE TABLE IF NOT EXISTS task_list (
          id SERIAL PRIMARY KEY,
          task_description TEXT NOT NULL,
          task_date DATE NOT NULL,
          repeat_option TEXT NOT NULL DEFAULT 'None',
          checked BOOLEAN DEFAULT false,
          image_url TEXT,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
          updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_task_list_task_date ON task_list(task_date);
        CREATE INDEX IF NOT EXISTS idx_task_list_created_at ON task_list(created_at);

        ALTER TABLE task_list ENABLE ROW LEVEL SECURITY;
        CREATE POLICY "Enable all operations for task list" ON task_list
          FOR ALL USING (true);

        -- Task completions table for tracking recurring task completion status
        CREATE TABLE IF NOT EXISTS task_completions (
          id SERIAL PRIMARY KEY,
          original_task_id INTEGER REFERENCES task_list(id) ON DELETE CASCADE,
          completion_date DATE NOT NULL,
          completed BOOLEAN DEFAULT false,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
          updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
          UNIQUE(original_task_id, completion_date)
        );

        CREATE INDEX IF NOT EXISTS idx_task_completions_original_task_id ON task_completions(original_task_id);
        CREATE INDEX IF NOT EXISTS idx_task_completions_completion_date ON task_completions(completion_date);
        CREATE INDEX IF NOT EXISTS idx_task_completions_unique ON task_completions(original_task_id, completion_date);

        ALTER TABLE task_completions ENABLE ROW LEVEL SECURITY;
        CREATE POLICY "Enable all operations for task completions" ON task_completions
          FOR ALL USING (true);
        
        -- Add image_url column to existing task_list table if it doesn't exist
        DO $$ 
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                          WHERE table_name='task_list' AND column_name='image_url') THEN
                ALTER TABLE task_list ADD COLUMN image_url TEXT;
            END IF;
        END $$;
        
        -- Create storage bucket for task images if it doesn't exist
        INSERT INTO storage.buckets (id, name, public) 
        VALUES ('task-images', 'task-images', true)
        ON CONFLICT (id) DO NOTHING;

        -- Set up RLS policy for the bucket if it doesn't exist
        DO $$ 
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_policies 
                WHERE schemaname = 'storage' 
                AND tablename = 'objects' 
                AND policyname = 'Public Access'
            ) THEN
                CREATE POLICY "Public Access" ON storage.objects FOR ALL USING (bucket_id = 'task-images');
            END IF;
        END $$;
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
        console.log('- notifications table for tracking device notifications');
        console.log('- task_list table for storing user tasks');
        console.log('- task_completions table for tracking recurring task completion status');
        console.log('- storage bucket "task-images" for storing task images');

    } catch (error) {
        console.error('Migration failed:', error.message);
    }
}

createInitialTable();