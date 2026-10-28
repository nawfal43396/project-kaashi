CREATE DATABASE kashi_bank;
USE kashi_bank;

CREATE TABLE Branch (
  BranchID INT AUTO_INCREMENT PRIMARY KEY,
  BranchName VARCHAR(50) NOT NULL,
  IFSCCode VARCHAR(11) UNIQUE NOT NULL,
  Address VARCHAR(100),
  City VARCHAR(50),
  State VARCHAR(50),
  ContactNumber VARCHAR(15)
);

CREATE TABLE Customer (
  CustomerID INT AUTO_INCREMENT PRIMARY KEY,
  FirstName VARCHAR(50) NOT NULL,
  LastName VARCHAR(50) NOT NULL,
  DateOfBirth DATE NOT NULL,
  Gender ENUM('Male','Female','Other') NOT NULL,
  Mobile VARCHAR(15) UNIQUE NOT NULL,
  Email VARCHAR(100) UNIQUE,
  Address VARCHAR(150),
  City VARCHAR(50),
  RegistrationDate DATE DEFAULT (CURRENT_DATE)
);

CREATE TABLE Employee (
  EmployeeID INT AUTO_INCREMENT PRIMARY KEY,
  EmployeeName VARCHAR(80) NOT NULL,
  Mobile VARCHAR(15),
  Email VARCHAR(100),
  Designation VARCHAR(50),
  Salary DECIMAL(10,2) CHECK (Salary > 0),
  JoiningDate DATE,
  BranchID INT NOT NULL,
  FOREIGN KEY (BranchID) REFERENCES Branch(BranchID)
);

CREATE TABLE Account (
  AccountID INT AUTO_INCREMENT PRIMARY KEY,
  AccountNumber VARCHAR(12) UNIQUE NOT NULL,
  AccountType ENUM('Saving','Current','Salary') NOT NULL,
  OpeningDate DATE NOT NULL,
  Balance DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (Balance >= 0),
  Status ENUM('Active','Inactive','Close') NOT NULL DEFAULT 'Active',
  BranchID INT NOT NULL,
  FOREIGN KEY (BranchID) REFERENCES Branch(BranchID)
);

CREATE TABLE Account_Holder (
  CustomerID INT NOT NULL,
  AccountID INT NOT NULL,
  HolderSince DATE NOT NULL,
  HolderType ENUM('Primary','Joint') NOT NULL,
  PRIMARY KEY (CustomerID, AccountID),
  FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID),
  FOREIGN KEY (AccountID) REFERENCES Account(AccountID)
);

CREATE TABLE `Transaction` (
  TransactionID INT AUTO_INCREMENT PRIMARY KEY,
  AccountID INT NOT NULL,
  TransactionType ENUM('DEPOSIT','WITHDRAWAL','TRANSFER_IN','TRANSFER_OUT') NOT NULL,
  Amount DECIMAL(12,2) NOT NULL CHECK (Amount > 0),
  TransactionDate DATETIME DEFAULT CURRENT_TIMESTAMP,
  Description VARCHAR(100),
  ReferenceNumber VARCHAR(30) UNIQUE,
  TransactionStatus ENUM('Success','Failed') DEFAULT 'Success',
  FOREIGN KEY (AccountID) REFERENCES Account(AccountID)
);

-- optional, tables only, no web pages
CREATE TABLE Loan (
  LoanID INT AUTO_INCREMENT PRIMARY KEY,
  CustomerID INT NOT NULL,
  BranchID INT NOT NULL,
  LoanType ENUM('Home Loan','Education Loan','Personal Loan','Vehicle Loan') NOT NULL,
  LoanAmount DECIMAL(12,2) NOT NULL CHECK (LoanAmount > 0),
  InterestRate DECIMAL(5,2) NOT NULL,
  StartDate DATE NOT NULL,
  TenureMonths INT NOT NULL,
  LoanStatus ENUM('Active','Closed') DEFAULT 'Active',
  FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID),
  FOREIGN KEY (BranchID) REFERENCES Branch(BranchID)
);

CREATE TABLE Loan_Payment (
  PaymentID INT AUTO_INCREMENT PRIMARY KEY,
  LoanID INT NOT NULL,
  PaymentDate DATE NOT NULL,
  Amount DECIMAL(12,2) NOT NULL CHECK (Amount > 0),
  PaymentMode VARCHAR(20),
  ReferenceNumber VARCHAR(30),
  FOREIGN KEY (LoanID) REFERENCES Loan(LoanID)
);

-- sample data
INSERT INTO Branch (BranchName,IFSCCode,Address,City,State,ContactNumber) VALUES
('Kashi Main','KASH0000001','MG Road','Varanasi','Uttar Pradesh','0542000001'),
('Kashi North','KASH0000002','Ring Road','Delhi','Delhi','0110000002');

INSERT INTO Employee (EmployeeName,Mobile,Email,Designation,Salary,JoiningDate,BranchID) VALUES
('Ravi Kumar','9000000001','ravi@kashi.com','Manager',60000,'2020-01-10',1),
('Anita Rao','9000000002','anita@kashi.com','Cashier',30000,'2022-06-01',2);






CREATE VIEW vw_account_summary AS
SELECT a.AccountNumber, a.AccountType, a.Balance, a.Status,
       b.BranchName, CONCAT(c.FirstName,' ',c.LastName) AS HolderName
FROM Account a
JOIN Branch b ON a.BranchID = b.BranchID
JOIN Account_Holder ah ON a.AccountID = ah.AccountID
JOIN Customer c ON ah.CustomerID = c.CustomerID;

DELIMITER $$

CREATE FUNCTION fn_customer_balance(p_cust INT)
RETURNS DECIMAL(14,2)
READS SQL DATA
BEGIN
  DECLARE v_total DECIMAL(14,2);
  SELECT IFNULL(SUM(a.Balance),0) INTO v_total
  FROM Account a JOIN Account_Holder ah ON a.AccountID = ah.AccountID
  WHERE ah.CustomerID = p_cust;
  RETURN v_total;
END$$

CREATE TRIGGER trg_block_inactive
BEFORE INSERT ON `Transaction`
FOR EACH ROW
BEGIN
  DECLARE v_status VARCHAR(10);
  SELECT Status INTO v_status FROM Account WHERE AccountID = NEW.AccountID;
  IF v_status <> 'Active' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account not active';
  END IF;
END$$

CREATE PROCEDURE sp_deposit(IN p_accno VARCHAR(12), IN p_amt DECIMAL(12,2))
BEGIN
  DECLARE v_id INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION;
  IF p_amt <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Amount must be positive';
  END IF;
  SELECT AccountID INTO v_id FROM Account
   WHERE AccountNumber = p_accno AND Status = 'Active' FOR UPDATE;
  IF v_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account not found or not active';
  END IF;
  UPDATE Account SET Balance = Balance + p_amt WHERE AccountID = v_id;
  INSERT INTO `Transaction` (AccountID,TransactionType,Amount,Description,ReferenceNumber)
  VALUES (v_id,'DEPOSIT',p_amt,'Cash deposit',CONCAT('DEP',UNIX_TIMESTAMP(),FLOOR(RAND()*1000)));
  COMMIT;
END$$

CREATE PROCEDURE sp_withdraw(IN p_accno VARCHAR(12), IN p_amt DECIMAL(12,2))
BEGIN
  DECLARE v_id INT;
  DECLARE v_bal DECIMAL(12,2);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION;
  IF p_amt <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Amount must be positive';
  END IF;
  SELECT AccountID, Balance INTO v_id, v_bal FROM Account
   WHERE AccountNumber = p_accno AND Status = 'Active' FOR UPDATE;
  IF v_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account not found or not active';
  END IF;
  IF v_bal < p_amt THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient balance';
  END IF;
  UPDATE Account SET Balance = Balance - p_amt WHERE AccountID = v_id;
  INSERT INTO `Transaction` (AccountID,TransactionType,Amount,Description,ReferenceNumber)
  VALUES (v_id,'WITHDRAWAL',p_amt,'Cash withdrawal',CONCAT('WDR',UNIX_TIMESTAMP(),FLOOR(RAND()*1000)));
  COMMIT;
END$$

CREATE PROCEDURE sp_transfer(IN p_from VARCHAR(12), IN p_to VARCHAR(12), IN p_amt DECIMAL(12,2))
BEGIN
  DECLARE v_from INT;
  DECLARE v_to INT;
  DECLARE v_bal DECIMAL(12,2);
  DECLARE v_ref VARCHAR(30);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION;
  IF p_amt <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Amount must be positive';
  END IF;
  IF p_from = p_to THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot transfer to same account';
  END IF;
  SELECT AccountID, Balance INTO v_from, v_bal FROM Account
   WHERE AccountNumber = p_from AND Status = 'Active' FOR UPDATE;
  SELECT AccountID INTO v_to FROM Account
   WHERE AccountNumber = p_to AND Status = 'Active' FOR UPDATE;
  IF v_from IS NULL OR v_to IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account not found or not active';
  END IF;
  IF v_bal < p_amt THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient balance';
  END IF;
  SET v_ref = CONCAT('TRF', UNIX_TIMESTAMP(), FLOOR(RAND()*1000));
  UPDATE Account SET Balance = Balance - p_amt WHERE AccountID = v_from;
  UPDATE Account SET Balance = Balance + p_amt WHERE AccountID = v_to;
  INSERT INTO `Transaction` (AccountID,TransactionType,Amount,Description,ReferenceNumber)
  VALUES (v_from,'TRANSFER_OUT',p_amt,CONCAT('Transfer to ',p_to),CONCAT(v_ref,'-O'));
  INSERT INTO `Transaction` (AccountID,TransactionType,Amount,Description,ReferenceNumber)
  VALUES (v_to,'TRANSFER_IN',p_amt,CONCAT('Transfer from ',p_from),CONCAT(v_ref,'-I'));
  COMMIT;
END$$

DELIMITER ;


CALL sp_deposit('123456789012', 500);
SELECT * FROM `Transaction`;


CREATE USER IF NOT EXISTS 'kashi'@'localhost' IDENTIFIED BY 'kashi123';
ALTER USER 'kashi'@'localhost' IDENTIFIED BY 'kashi123';
GRANT ALL PRIVILEGES ON kashi_bank.* TO 'kashi'@'localhost';
FLUSH PRIVILEGES;