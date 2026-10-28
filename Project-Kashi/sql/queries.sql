-- 1. total balance per branch
SELECT b.BranchName, SUM(a.Balance) AS TotalBalance
FROM Branch b JOIN Account a ON b.BranchID = a.BranchID GROUP BY b.BranchName;

-- 2. customers with more than one account
SELECT c.CustomerID, c.FirstName, COUNT(*) AS Accounts
FROM Customer c JOIN Account_Holder ah ON c.CustomerID = ah.CustomerID
GROUP BY c.CustomerID, c.FirstName HAVING COUNT(*) > 1;

-- 3. top 5 accounts by balance
SELECT AccountNumber, Balance FROM Account ORDER BY Balance DESC LIMIT 5;

-- 4. transactions in last 30 days
SELECT * FROM `Transaction` WHERE TransactionDate >= NOW() - INTERVAL 30 DAY;

-- 5. total deposit and withdrawal per account
SELECT a.AccountNumber,
  SUM(CASE WHEN t.TransactionType='DEPOSIT' THEN t.Amount ELSE 0 END) AS Deposits,
  SUM(CASE WHEN t.TransactionType='WITHDRAWAL' THEN t.Amount ELSE 0 END) AS Withdrawals
FROM Account a LEFT JOIN `Transaction` t ON a.AccountID = t.AccountID
GROUP BY a.AccountNumber;

-- 6. accounts with zero balance
SELECT AccountNumber FROM Account WHERE Balance = 0;

-- 7. customers registered this month
SELECT * FROM Customer
WHERE MONTH(RegistrationDate)=MONTH(CURDATE()) AND YEAR(RegistrationDate)=YEAR(CURDATE());

-- 8. employee count and average salary per branch
SELECT b.BranchName, COUNT(e.EmployeeID) AS Employees, AVG(e.Salary) AS AvgSalary
FROM Branch b LEFT JOIN Employee e ON b.BranchID = e.BranchID GROUP BY b.BranchName;

-- 9. largest transaction per account type
SELECT a.AccountType, MAX(t.Amount) AS MaxAmount
FROM Account a JOIN `Transaction` t ON a.AccountID = t.AccountID GROUP BY a.AccountType;

-- 10. total money across all accounts of one customer (stored function)
SELECT fn_customer_balance(1);

CREATE USER 'kashi'@'localhost' IDENTIFIED BY 'kashi123';
GRANT ALL PRIVILEGES ON kashi_bank.* TO 'kashi'@'localhost';
FLUSH PRIVILEGES;

show databases;

GRANT ALL PRIVILEGES ON kashi_bank.* TO 'kashi'@'localhost';
FLUSH PRIVILEGES;
USE kashi_bank;
SHOW TABLES;
SELECT * FROM Customer;



USE kashi_bank;
SHOW TABLES;
SHOW PROCEDURE STATUS WHERE Db = 'kashi_bank';



SELECT * FROM Customer;
SELECT * FROM Account;
SELECT * FROM Account_Holder;

DELETE FROM Employee WHERE EmployeeID > 2;

SELECT * FROM Branch;
SELECT * FROM Employee;


INSERT INTO Branch (BranchName,IFSCCode,Address,City,State,ContactNumber) VALUES
('Kashi Main','KASH0000001','MG Road','Varanasi','Uttar Pradesh','0542000001'),
('Kashi North','KASH0000002','Ring Road','Delhi','Delhi','0110000002');

INSERT INTO Employee (EmployeeName,Mobile,Email,Designation,Salary,JoiningDate,BranchID) VALUES
('Ravi Kumar','9000000001','ravi@kashi.com','Manager',60000,'2020-01-10',1),
('Anita Rao','9000000002','anita@kashi.com','Cashier',30000,'2022-06-01',2);

SELECT user, host FROM mysql.user;