-- Create test database
CREATE DATABASE IF NOT EXISTS test;
USE test;

-- Create hr table with sample employee data
CREATE TABLE IF NOT EXISTS hr (
    id INT AUTO_INCREMENT PRIMARY KEY,
    employee_id VARCHAR(10) NOT NULL UNIQUE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    department VARCHAR(50) NOT NULL,
    position VARCHAR(50) NOT NULL,
    hire_date DATE NOT NULL,
    salary DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Insert sample HR data
INSERT INTO hr (employee_id, first_name, last_name, email, department, position, hire_date, salary) VALUES
('EMP001', 'John', 'Smith', 'john.smith@company.com', 'Engineering', 'Senior Software Engineer', '2022-01-15', 85000.00),
('EMP002', 'Sarah', 'Johnson', 'sarah.johnson@company.com', 'Engineering', 'DevOps Engineer', '2022-03-10', 80000.00),
('EMP003', 'Michael', 'Brown', 'michael.brown@company.com', 'Product', 'Product Manager', '2021-11-20', 95000.00),
('EMP004', 'Emily', 'Davis', 'emily.davis@company.com', 'Design', 'UI/UX Designer', '2022-05-05', 70000.00),
('EMP005', 'David', 'Wilson', 'david.wilson@company.com', 'Sales', 'Account Executive', '2021-09-12', 75000.00),
('EMP006', 'Lisa', 'Garcia', 'lisa.garcia@company.com', 'Engineering', 'Frontend Engineer', '2022-07-01', 78000.00),
('EMP007', 'Robert', 'Martinez', 'robert.martinez@company.com', 'Operations', 'Operations Manager', '2021-06-30', 88000.00),
('EMP008', 'Jennifer', 'Anderson', 'jennifer.anderson@company.com', 'HR', 'HR Specialist', '2022-02-14', 65000.00),
('EMP009', 'James', 'Taylor', 'james.taylor@company.com', 'Engineering', 'Backend Engineer', '2022-08-22', 82000.00),
('EMP010', 'Maria', 'Rodriguez', 'maria.rodriguez@company.com', 'Marketing', 'Marketing Manager', '2021-10-05', 72000.00);

-- Create indexes for better performance
CREATE INDEX idx_hr_department ON hr(department);
CREATE INDEX idx_hr_position ON hr(position);
CREATE INDEX idx_hr_hire_date ON hr(hire_date);

-- Show table structure and data
DESCRIBE hr;
SELECT COUNT(*) as total_employees FROM hr;
SELECT department, COUNT(*) as employee_count FROM hr GROUP BY department;
