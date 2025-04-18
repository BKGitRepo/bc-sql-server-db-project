
DECLARE @device_directory NVARCHAR(520)
SELECT @device_directory = SUBSTRING(filename, 1, CHARINDEX(N'master.mdf', LOWER(filename)) - 1)
FROM master.dbo.sysaltfiles WHERE dbid = 1 AND fileid = 1

EXECUTE (N'CREATE DATABASE DrJKnoetze
  ON PRIMARY (NAME = N''DrJKnoetze'', FILENAME = N''' + @device_directory + N'DrJKnoetze.mdf'')
  LOG ON (NAME = N''DrJKnoetze_log'',  FILENAME = N''' + @device_directory + N'DrJKnoetze.ldf'')')
GO
USE "DrJKnoetze"
GO
 
-- Check if the Doctor schema exists and create if not
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Doctor')
BEGIN
    EXEC('CREATE SCHEMA Doctor');
END
GO

-- Check if the Receptionist schema exists and create if not
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Receptionist')
BEGIN
    EXEC('CREATE SCHEMA Receptionist');
END
GO

BEGIN TRANSACTION;
BEGIN TRY

-- Create Practitioner table
CREATE TABLE Doctor.Practitioner (
    PractitionerID INT PRIMARY KEY IDENTITY,
    Name NVARCHAR(30) NOT NULL,
    Surname NVARCHAR(30) NOT NULL
);
 
-- Create Qualification table
CREATE TABLE Doctor.Qualification (
    QualificationID INT PRIMARY KEY IDENTITY,
    Name NVARCHAR(255) NOT NULL,
    NQFLevel INT NOT NULL CONSTRAINT CHK_Qualification_NQFLevel CHECK (NQFLevel BETWEEN 1 AND 10)
);
 
-- Create PractitionerQualification table
CREATE TABLE Doctor.PractitionerQualification (
    PractitionerID INT FOREIGN KEY REFERENCES Doctor.Practitioner(PractitionerID),
    QualificationID INT FOREIGN KEY REFERENCES Doctor.Qualification(QualificationID),
	Institution  NVARCHAR(130) NOT NULL,
	Description NVARCHAR(255),
	YearObtained SMALLINT NOT NULL,
    PRIMARY KEY (PractitionerID, QualificationID)
);
 -- Create MedicalAid table
CREATE TABLE MedicalAid (
	MedicalAidID INT PRIMARY KEY IDENTITY,
    MedicalAidNum NVARCHAR(100) NOT NULL,
    MedicalAidName NVARCHAR(150) NOT NULL
);

-- Create Client table
CREATE TABLE Receptionist.Client (
    ClientID INT PRIMARY KEY IDENTITY,
    IDNum VARCHAR(13) NOT NULL, CONSTRAINT CHK_SA_ID_Length CHECK (LEN(IDNum) = 13),
    Name NVARCHAR(30) NOT NULL,
    Surname NVARCHAR(30) NOT NULL,
    DateOfBirth DATE NOT NULL CONSTRAINT CHK_Client_DateOfBirth_Reasonable CHECK (DateOfBirth <= GETDATE() AND DateOfBirth > '1900-01-01'),
    Phone NVARCHAR(20) CONSTRAINT CHK_Client_Phone_Format CHECK (LEN(Phone) BETWEEN 10 AND 20),
    WhatsAppNumber  NVARCHAR(20) CONSTRAINT CHK_Client_WhatsAppNumber_Format CHECK (LEN(WhatsAppNumber) BETWEEN 10 AND 20),
	PostalAddress NVARCHAR(255),
    Email NVARCHAR(80)    
);
 
 CREATE TABLE MedicalAidClient(
MedicalAidID INT FOREIGN KEY REFERENCES MedicalAid(MedicalAidID),
ClientID INT FOREIGN KEY REFERENCES Receptionist.Client(ClientID),
DepNum INT NOT NULL
);

-- Create VisitReason table
CREATE TABLE VisitReason (
    ReasonID INT PRIMARY KEY IDENTITY,
    ReasonWhy NVARCHAR(255) NOT NULL,
    BackgroundInfo NVARCHAR(1000)
);

-- Create RelationshipStatus table
CREATE TABLE RelationshipStatus (
    RelationshipStatusID INT PRIMARY KEY IDENTITY,
    Description NVARCHAR(50) NOT NULL
);
 
-- Create Adult table
CREATE TABLE Receptionist.Adult (
    AdultID INT PRIMARY KEY IDENTITY,
    ClientID INT NOT NULL FOREIGN KEY REFERENCES Receptionist.Client(ClientID),
    ContactPersonID INT NOT NULL FOREIGN KEY REFERENCES Receptionist.Client(ClientID),
    Occupation NVARCHAR(255) NOT NULL CONSTRAINT CHK_Adult_Occupation_Length CHECK (LEN(Occupation) <= 255),
    RelationshipStatus  INT NOT NULL FOREIGN KEY REFERENCES RelationshipStatus(RelationshipStatusID),
    VisitReasonID INT FOREIGN KEY REFERENCES VisitReason(ReasonID),
);
 
-- Create Child table
CREATE TABLE Receptionist.Child (
    ChildID INT PRIMARY KEY IDENTITY,
    ClientID INT NOT NULL FOREIGN KEY REFERENCES Receptionist.Client(ClientID),
	ContactPersonID INT NOT NULL FOREIGN KEY REFERENCES Receptionist.Client(ClientID),
	School NVARCHAR(100) CONSTRAINT CHK_Child_School_Length CHECK (LEN(School) <= 100),
	VisitReasonID INT FOREIGN KEY REFERENCES VisitReason(ReasonID),
	ReportRequired BIT NOT NULL,
	Grade INT NOT NULL
);
 
 
-- Create Guardian table
CREATE TABLE Receptionist.Guardian (
    GuardianID INT PRIMARY KEY IDENTITY,
    ClientID INT NOT NULL FOREIGN KEY REFERENCES Receptionist.Client(ClientID),
    RelationshipStatusID INT NOT NULL FOREIGN KEY REFERENCES RelationshipStatus(RelationshipStatusID), 
    Occupation NVARCHAR(150)
);
 
-- Create GuardianRelationType table
CREATE TABLE GuardianRelationType (
    RelationshipTypeID INT PRIMARY KEY IDENTITY,
    Description NVARCHAR(50) NOT NULL
);
 
-- Create ChildGuardian table
CREATE TABLE ChildGuardian (
    ChildID INT FOREIGN KEY REFERENCES Receptionist.Child(ChildID),
    GuardianID INT FOREIGN KEY REFERENCES Receptionist.Guardian(GuardianID),
    GuardianRelationType INT NOT NULL FOREIGN KEY REFERENCES GuardianRelationType(RelationshipTypeID),
    PRIMARY KEY (ChildID, GuardianID)
);
 
-- Create ReportTypes table
CREATE TABLE ReportTypes (
    ReportTypeID INT PRIMARY KEY IDENTITY,
    Type NVARCHAR(255) NOT NULL,
    Description NVARCHAR(1000),
    Cost MONEY NOT NULL CONSTRAINT CHK_ReportTypes_Cost_NonNegative CHECK (Cost >= 0)
);
 
-- Create ReportStatus table
CREATE TABLE ReportStatus (
    ReportStatusID INT PRIMARY KEY IDENTITY,
    Description NVARCHAR(50) NOT NULL
);
 
-- Create Report table
CREATE TABLE Doctor.Report (
    ClientID INT FOREIGN KEY REFERENCES Receptionist.Client(ClientID),
    ReportTypeID INT FOREIGN KEY REFERENCES ReportTypes(ReportTypeID),
    ReportStatusID INT NOT NULL FOREIGN KEY REFERENCES ReportStatus(ReportStatusID),
    Notes NVARCHAR(MAX),
	PRIMARY KEY (ClientID,ReportTypeID)
);
 
-- Create AccountStatus table
CREATE TABLE AccountStatus (
    AccountStatusID INT PRIMARY KEY IDENTITY,
    Description NVARCHAR(50) NOT NULL
);
 
-- Create Accounts table
CREATE TABLE Receptionist.Accounts (
    AccountID INT PRIMARY KEY IDENTITY,
    ClientID INT NOT NULL FOREIGN KEY REFERENCES Receptionist.Client(ClientID),
    PersonRFP INT NOT NULL FOREIGN KEY REFERENCES Receptionist.Client(ClientID),
    AccountStatusID INT FOREIGN KEY REFERENCES AccountStatus(AccountStatusID),
    AmountOutStanding MONEY
);
 
-- Create AccountDiscount table
CREATE TABLE Receptionist.AccountDiscount (
    DiscountID INT PRIMARY KEY IDENTITY,
    AccountID INT NOT NULL FOREIGN KEY REFERENCES Receptionist.Accounts(AccountID),
    Amount MONEY CONSTRAINT CHK_AccountDiscount_Amount_NonNegative CHECK (Amount >= 0),
    Date DATE,
    Reason NVARCHAR(255)
);
 
-- Create Service table
CREATE TABLE ServiceType (
    ServiceTypeID INT PRIMARY KEY IDENTITY,
    ServiceType NVARCHAR(80) NOT NULL,
	Description NVARCHAR(150),
    ICD10 NVARCHAR(30) NOT NULL,
	Cost MONEY  NOT NULL CONSTRAINT CHK_Service_Cost_NonNegative CHECK (Cost >= 0)
);
 
-- Create ClientAppointment table
CREATE TABLE Receptionist.ClientAppointment  (
	AppointmentID INT PRIMARY KEY IDENTITY,
    ClientID INT  NOT NULL FOREIGN KEY REFERENCES Receptionist.Client(ClientID),
    AppointmentType INT  NOT NULL FOREIGN KEY REFERENCES ServiceType(ServiceTypeID),
    AppointmentDate  DateTime  NOT NULL,
	PractitionerID INT  NOT NULL FOREIGN KEY REFERENCES Doctor.Practitioner(PractitionerID)	
);

-- Create Invoice table
CREATE TABLE Receptionist.Invoice (
    InvoiceID INT PRIMARY KEY IDENTITY,
    AccountID INT NOT NULL FOREIGN KEY REFERENCES Receptionist.Accounts(AccountID),
    InvoiceNum NVARCHAR(80) NOT NULL,
    InvoiceDate DATE  NOT NULL,
    InvoiceTotal MONEY  NOT NULL,
	DiscountID INT FOREIGN KEY REFERENCES Receptionist.AccountDiscount(DiscountID),
    AppointmentID INT  NOT NULL FOREIGN KEY REFERENCES Receptionist.ClientAppointment(AppointmentID)
);
 
-- Create InvoicePayments table
CREATE TABLE Receptionist.InvoicePayments (
    PaymentID INT PRIMARY KEY IDENTITY,
    InvoiceID INT  NOT NULL FOREIGN KEY REFERENCES Receptionist.Invoice(InvoiceID),
    Amount MONEY CONSTRAINT CHK_InvoicePayments_Amount_NonNegative CHECK (Amount >= 0),
    Date DATE
);
CREATE TABLE AccountAudit (
    AccountAuditID INT PRIMARY KEY IDENTITY,
    AccountID INT NOT NULL FOREIGN KEY REFERENCES Receptionist.Accounts(AccountID),
    Operation NVARCHAR(20),
    ChangeDate DATETIME
);

    COMMIT TRANSACTION; -- If everything is successful, commit the transaction
END TRY
BEGIN CATCH
    -- If there's an error, roll back the transaction
    ROLLBACK TRANSACTION;

    -- Error handling: capture and rethrow the error
    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrorState INT = ERROR_STATE();
    RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
END CATCH

--sample data
USE DrJKnoetze;
GO

--IF Used for initial setup
DBCC CHECKIDENT ('MedicalAid', RESEED, 0);
GO
DBCC CHECKIDENT ('Doctor.Practitioner', RESEED, 0);
GO
DBCC CHECKIDENT ('Doctor.Qualification', RESEED, 0);
GO
DBCC CHECKIDENT ('Receptionist.Client', RESEED, 0);
GO
DBCC CHECKIDENT ('VisitReason', RESEED, 0);
GO
DBCC CHECKIDENT ('Receptionist.Child', RESEED, 0);
GO
DBCC CHECKIDENT ('Receptionist.Guardian', RESEED, 0);
GO
DBCC CHECKIDENT ('GuardianRelationType', RESEED, 0);
GO
DBCC CHECKIDENT ('RelationshipStatus', RESEED, 0);
GO
DBCC CHECKIDENT ('Receptionist.Adult', RESEED, 0);
GO
DBCC CHECKIDENT ('Receptionist.Accounts', RESEED, 0);
GO
DBCC CHECKIDENT ('ServiceType', RESEED, 0);
GO
DBCC CHECKIDENT ('AccountStatus', RESEED, 0);
GO
DBCC CHECKIDENT ('Receptionist.AccountDiscount', RESEED, 0);
GO
DBCC CHECKIDENT ('Receptionist.ClientAppointment', RESEED, 0);
GO
DBCC CHECKIDENT ('Receptionist.Invoice', RESEED, 0);
GO
DBCC CHECKIDENT ('Receptionist.InvoicePayments', RESEED, 0);
GO
DBCC CHECKIDENT ('ReportTypes', RESEED, 0);
GO
DBCC CHECKIDENT ('ReportStatus', RESEED, 0);
GO

--Insert Demo Data 
BEGIN TRANSACTION;
BEGIN TRY
	INSERT INTO Doctor.Practitioner(Name, Surname) VALUES
	('John', 'Doe'),
	('Jane', 'Smith'),
	('Michael', 'Johnson'),
	('Emily', 'Brown'),
	('David', 'Williams'),
	('Sarah', 'Jones'),
	('Daniel', 'Martinez'),
	('Jessica', 'Garcia'),
	('Matthew', 'Hernandez'),
	('Amanda', 'Lopez'),
	('Christopher', 'Young'),
	('Ashley', 'King'),
	('Joshua', 'Lee'),
	('Megan', 'Scott'),
	('Ryan', 'Green'),
	('Lauren', 'Evans'),
	('Justin', 'Hall'),
	('Stephanie', 'Adams'),
	('Brandon', 'Morris'),
	('Elizabeth', 'Nelson');
	-- Add more rows as needed


	INSERT INTO Doctor.Qualification (Name, NQFLevel) VALUES
	('Bachelor of Medicine', 8),
	('Doctor of Medicine', 10),
	('Bachelor of Nursing', 7),
	('Master of Nursing', 9),
	('Bachelor of Psychology', 7),
	('Master of Psychology', 9),
	('Bachelor of Pharmacy', 8),
	('Master of Pharmacy', 9),
	('Bachelor of Dentistry', 8),
	('Master of Dentistry', 9),
	('Bachelor of Occupational Therapy', 7),
	('Master of Occupational Therapy', 9),
	('Bachelor of Physiotherapy', 7),
	('Master of Physiotherapy', 9),
	('Bachelor of Optometry', 7),
	('Master of Optometry', 9),
	('Bachelor of Social Work', 7),
	('Master of Social Work', 9),
	('Bachelor of Chiropractic', 7),
	('Master of Chiropractic', 9);
	-- Add more rows as needed



	INSERT INTO Doctor.PractitionerQualification (PractitionerID, QualificationID, Institution, Description, YearObtained) VALUES
	(1, 1, 'Harvard Medical School', 'Completed medical degree', 2010),
	(2, 2, 'Johns Hopkins University School of Medicine', 'Specialized in cardiology', 2013),
	(1, 3, 'Yale School of Nursing', 'Completed nursing degree', 2008),
	(4, 4, 'University of Pennsylvania School of Nursing', 'Specialized in pediatrics', 2011),
	(5, 5, 'Stanford University Department of Psychology', 'Completed psychology degree', 2009),
	(3, 6, 'Columbia University Department of Psychology', 'Specialized in clinical psychology', 2012),
	(5, 7, 'University of California, San Francisco School of Pharmacy', 'Completed pharmacy degree', 2010),
	(8, 8, 'University of Michigan College of Pharmacy', 'Specialized in pharmacotherapy', 2013),
	(9, 9, 'University of Maryland School of Dentistry', 'Completed dentistry degree', 2008),
	(2, 10, 'University of North Carolina at Chapel Hill School of Dentistry', 'Specialized in orthodontics', 2011),
	(6, 11, 'Boston University College of Health and Rehabilitation Sciences: Sargent College', 'Completed occupational therapy degree', 2009),
	(4, 12, 'University of Southern California Division of Biokinesiology and Physical Therapy', 'Specialized in pediatric occupational therapy', 2012),
	(5, 13, 'University of Pittsburgh School of Health and Rehabilitation Sciences', 'Completed physiotherapy degree', 2010),
	(6, 14, 'Ohio State University School of Health and Rehabilitation Sciences', 'Specialized in sports physiotherapy', 2013),
	(4, 15, 'University of Houston College of Optometry', 'Completed optometry degree', 2008),
	(3, 16, 'Indiana University School of Optometry', 'Specialized in pediatric optometry', 2011),
	(2, 17, 'University of Chicago School of Social Service Administration', 'Completed social work degree', 2009),
	(3, 18, 'University of Washington School of Social Work', 'Specialized in family therapy', 2012),
	(1, 19, 'Life University College of Chiropractic', 'Completed chiropractic degree', 2010),
	(2, 20, 'Palmer College of Chiropractic', 'Specialized in sports chiropractic', 2013);


	INSERT INTO MedicalAid (MedicalAidNum, MedicalAidName) VALUES
	('MA001', 'HealthCarePlus'),
	('MA002', 'WellnessFirst'),
	('MA003', 'MediCareGuard'),
	('MA004', 'FamilyCare'),
	('MA005', 'HealthShield'),
	('MA006', 'MediHelp'),
	('MA007', 'GuardianCare'),
	('MA008', 'LifeSaver'),
	('MA009', 'CareFirst'),
	('MA010', 'GuardianPlus'),
	('MA011', 'FamilyGuard'),
	('MA012', 'HealthWise'),
	('MA013', 'CareZone'),
	('MA014', 'MediPlan'),
	('MA015', 'LifeCare'),
	('MA016', 'FamilyFirst'),
	('MA017', 'WellBeing'),
	('MA018', 'MediCover'),
	('MA019', 'HealthSure'),
	('MA020', 'CareZone');

	-- Sample data for Client table
	INSERT INTO Receptionist.Client(IDNum, Name, Surname, DateOfBirth, Phone, WhatsAppNumber, PostalAddress, Email)
	VALUES
	('9304011234567', 'John', 'Doe', '2005-04-01','+27831234567', '+27831234567', '123 Main St, City', 'john.doe@example.com'),
	('8506029876543', 'Jane', 'Smith', '2002-06-02','+27839876543', '+27839876543', '456 Elm St, Town', 'jane.smith@example.com'),
	('8807158765432', 'Michael', 'Johnson', '2012-07-15', '+27835555555', '+27835555555', '789 Oak St, Village', 'michael.johnson@example.com'),
	('9003207654321', 'Emily', 'Brown', '2003-03-20','+27838888888', '+27838888888', '101 Pine St, County', 'emily.brown@example.com'),
	('9505106543210', 'David', 'Martinez', '2018-05-10', '+27834444444', '+27834444444', '202 Cedar St, Township', 'david.martinez@example.com'),
	('9107155432109', 'Sarah', 'Taylor', '2009-07-15', '+27836666666', '+27836666666', '303 Maple St, Hamlet', 'sarah.taylor@example.com'),
	('9205244321098', 'Christopher', 'Anderson', '2008-05-24', '+27837777777', '+27837777777', '404 Birch St, Borough', 'christopher.anderson@example.com'),
	('8708133210987', 'Amanda', 'Wilson', '2010-08-13', '+27839999999', '+27839999999', '505 Walnut St, Municipality', 'amanda.wilson@example.com'),
	('8902092109876', 'James', 'Garcia', '2015-02-09', '+27832222222', '+27832222222', '606 Spruce St, District', 'james.garcia@example.com'),
	('8406301098765', 'Jessica', 'Lopez', '2009-06-30', '+27833333333', '+27833333333', '707 Pineapple St, Precinct', 'jessica.lopez@example.com'),
	('9601020987654', 'Matthew', 'Hernandez', '2011-01-02', '+27831111111', '+27831111111', '808 Strawberry St, Sector', 'matthew.hernandez@example.com'),
	('9305239876543', 'Lauren', 'Young', '2006-05-23', '+27835555555', '+27835555555', '909 Cherry St, Block', 'lauren.young@example.com'),
	('8504088765432', 'Ryan', 'Miller', '2014-04-08', '+27834444444', '+27834444444', '1010 Grape St, Tract', 'ryan.miller@example.com'),
	('8807197654321', 'Ashley', 'King', '2017-07-19', '+27838888888', '+27838888888', '1111 Orange St, Division', 'ashley.king@example.com'),
	('9006276543210', 'Daniel', 'Lee', '2019-06-27', '+27839999999', '+27839999999', '1212 Pear St, Lot', 'daniel.lee@example.com'),
	('9508065432109', 'Megan', 'Gonzalez', '2020-08-06', '+27832222222', '+27832222222', '1313 Lemon St, Unit', 'megan.gonzalez@example.com'),
	('9102044321098', 'Kevin', 'White', '2014-02-04', '+27833333333', '+27833333333', '1414 Banana St, Assembly', 'kevin.white@example.com'),
	('9204233210987', 'Rachel', 'Martinez', '2009-04-23', '+27834444444', '+27834444444', '1515 Kiwi St, Cluster', 'rachel.martinez@example.com'),
	('8706222109876', 'Justin', 'Davis', '2018-06-22', '+27835555555', '+27835555555', '1616 Mango St, Neighborhood', 'justin.davis@example.com'),
	('8908021098765', 'Brittany', 'Hernandez', '2019-08-02', '+27836666666', '+27836666666', '1717 Lime St, Suburb', 'brittany.hernandez@example.com'),
	('9412021234570', 'Alice', 'Brown', '2005-12-02', '+27731234701', '+27731234701', '19 Rose St, City', 'alice.brown21@example.com'),
	('8611039876550', 'Bob', 'Johnson', '2019-11-03', '+27839876702', '+27839876702', '58 Oak St, Town', 'bob.johnson22@example.com'),
	('8812048765430', 'Carlos', 'Lee', '2018-12-04', '+27735555703', '+27735555703', '790 Pine St, Village', 'carlos.lee23@example.com'),
	('9203057654320', 'Diana', 'Martinez', '2017-03-05', '+27836666804', '+27836666804', '1012 Maple St, Hamlet', 'diana.martinez24@example.com'),
	('9504066543210', 'Evan', 'Davis', '2016-04-06', '+27837777905', '+27837777905', '1214 Birch St, Borough', 'evan.davis25@example.com'),
	('9705075432101', 'Fiona', 'Garcia', '2013-05-07', '+27738888006', '+27738888006', '1316 Walnut St, Municipality', 'fiona.garcia26@example.com'),
	('9806084321092', 'George', 'Hill', '2007-06-08', '+27839999107', '+27839999107', '1418 Spruce St, District', 'george.hill27@example.com'),
	('9907093210983', 'Hannah', 'Adams', '2008-07-09', '+27731110208', '+27731110208', '1520 Pineapple St, Precinct', 'hannah.adams28@example.com'),
	('0008102109874', 'Ian', 'Baker', '2015-08-10', '+27832221309', '+27832221309', '1622 Strawberry St, Sector', 'ian.baker29@example.com'),
	('0109111098765', 'Julia', 'Clark', '2019-09-11', '+27733332410', '+27733332410', '1724 Cherry St, Block', 'julia.clark30@example.com'),
	('9412021234570', 'Alice', 'Brown', '2020-12-02', '+27731234701', '+27731234701', '19 Rose St, City', 'alice.brown21@example.com'),
	('8611039876550', 'Bob', 'Pietersen', '2018-11-03', '+27839876702', '+27839876702', '58 Oak St, Town', 'bob.johnson22@example.com'),
	('8812048765430', 'Carlos', 'Lee', '2016-12-04', '+27735555703', '+27735555703', '790 Pine St, Village', 'carlos.lee23@example.com'),
	('9203057654320', 'Diana', 'Martinez', '2013-03-05', '+27836666804', '+27836666804', '1012 Maple St, Hamlet', 'diana.martinez24@example.com'),
	('9504066543210', 'Evan', 'Davis', '2018-04-06', '+27837777905', '+27837777905', '1214 Birch St, Borough', 'evan.davis25@example.com'),
	('9412021234567', 'Alice', 'Wong', '1994-12-02', '+27731234621', '+27731234621', '18 Rose St, City', 'alice.wong21@example.com'),
	('8611039876543', 'Bob', 'Marley', '1986-11-03', '+27839876643', '+27839876643', '57 Oak St, Town', 'bob.marley22@example.com'),
	('8812048765432', 'Carlos', 'Santana', '1988-12-04', '+27735555623', '+27735555623', '789 Pine St, Village', 'carlos.santana23@example.com'),
	('9304011234567', 'John', 'Doe', '1993-04-01', '+27731234567', '+27731234567', '123 Main St, City', 'john.doe1@example.com'),
	('8506029876543', 'Jane', 'Smith', '1985-06-02', '+27839876543', '+27839876543', '456 Elm St, Town', 'jane.smith2@example.com'),
	('9501014800086', 'Liam', 'Smith', '1995-01-01', '+27720000001', '+27720000001', '1 Elm Street, Suburb', 'liam.smith@example.com'),
	('9402024800087', 'Emma', 'Johnson', '1994-02-02', '+27720000002', '+27720000002', '2 Pine Street, Suburb', 'emma.johnson@example.com'),
	('9303034800088', 'Noah', 'Williams', '1993-03-03', '+27720000003', '+27720000003', '3 Oak Street, Suburb', 'noah.williams@example.com'),
	('9204044800089', 'Olivia', 'Brown', '1992-04-04', '+27720000004', '+27720000004', '4 Maple Street, Suburb', 'olivia.brown@example.com'),
	('9105054800090', 'Ava', 'Jones', '1991-05-05', '+27720000005', '+27720000005', '5 Cedar Street, Suburb', 'ava.jones@example.com'),
	('9006064800091', 'William', 'Garcia', '1990-06-06', '+27720000006', '+27720000006', '6 Birch Street, Suburb', 'william.garcia@example.com'),
	('8907074800092', 'Sophia', 'Miller', '1989-07-07', '+27720000007', '+27720000007', '7 Walnut Street, Suburb', 'sophia.miller@example.com'),
	('8808084800093', 'James', 'Davis', '1988-08-08', '+27720000008', '+27720000008', '8 Chestnut Street, Suburb', 'james.davis@example.com'),
	('8709094800094', 'Isabella', 'Rodriguez', '1987-09-09', '+27720000009', '+27720000009', '9 Ash Street, Suburb', 'isabella.rodriguez@example.com'),
	('8610104800095', 'Benjamin', 'Martinez', '1986-10-10', '+27720000010', '+27720000010', '10 Cherry Street, Suburb', 'benjamin.martinez@example.com'),
	('8511114800096', 'Mia', 'Hernandez', '1985-11-11', '+27720000011', '+27720000011', '11 Elm Street, Suburb', 'mia.hernandez@example.com'),
	('8412124800097', 'Mason', 'Moore', '1984-12-12', '+27720000012', '+27720000012', '12 Pine Street, Suburb', 'mason.moore@example.com'),
	('8301014800098', 'Harper', 'Taylor', '1983-01-01', '+27720000013', '+27720000013', '13 Oak Street, Suburb', 'harper.taylor@example.com'),
	('8202024800099', 'Ethan', 'Anderson', '1982-02-02', '+27720000014', '+27720000014', '14 Maple Street, Suburb', 'ethan.anderson@example.com'),
	('8103034800010', 'Ella', 'Thomas', '1981-03-03', '+27720000015', '+27720000015', '15 Cedar Street, Suburb', 'ella.thomas@example.com'),
	('8004044800011', 'Alexander', 'Jackson', '1980-04-04', '+27720000016', '+27720000016', '16 Birch Street, Suburb', 'alexander.jackson@example.com'),
	('7905054800012', 'Amelia', 'White', '1979-05-05', '+27720000017', '+27720000017', '17 Walnut Street, Suburb', 'amelia.white@example.com'),
	('7806064800013', 'Michael', 'Harris', '1978-06-06', '+27720000018', '+27720000018', '18 Chestnut Street, Suburb', 'michael.harris@example.com'),
	('7707074800014', 'Charlotte', 'Clark', '1977-07-07', '+27720000019', '+27720000019', '19 Ash Street, Suburb', 'charlotte.clark@example.com'),
	('7608084800015', 'Elijah', 'Lewis', '1976-08-08', '+27720000020', '+27720000020', '20 Cherry Street, Suburb', 'elijah.lewis@example.com'),
	('7509094800016', 'Sofia', 'Robinson', '1975-09-09', '+27720000021', '+27720000021', '21 Elm Street, Suburb', 'sofia.robinson@example.com'),
	('7410104800017', 'Logan', 'Walker', '1974-10-10', '+27720000022', '+27720000022', '22 Pine Street, Suburb', 'logan.walker@example.com'),
	('7311114800018', 'Avery', 'Perez', '1973-11-11', '+27720000023', '+27720000023', '23 Oak Street, Suburb', 'avery.perez@example.com'),
	('7212124800019', 'Jackson', 'Young', '1972-12-12', '+27720000024', '+27720000024', '24 Maple Street, Suburb', 'jackson.young@example.com'),
	('7101014800020', 'Scarlett', 'Hernandez', '1971-01-01', '+27720000025', '+27720000025', '25 Cedar Street, Suburb', 'scarlett.hernandez@example.com'),
	('7002024800021', 'Grace', 'King', '1970-02-02', '+27720000026', '+27720000026', '26 Birch Street, Suburb', 'grace.king@example.com'),
	('6903034800022', 'Lucas', 'Wright', '1969-03-03', '+27720000027', '+27720000027', '27 Walnut Street, Suburb', 'lucas.wright@example.com'),
	('6804044800023', 'Lily', 'Scott', '1968-04-04', '+27720000028', '+27720000028', '28 Chestnut Street, Suburb', 'lily.scott@example.com'),
	('6705054800024', 'Oliver', 'Torres', '1967-05-05', '+27720000029', '+27720000029', '29 Ash Street, Suburb', 'oliver.torres@example.com'),
	('6606064800025', 'Madison', 'Nguyen', '1966-06-06', '+27720000030', '+27720000030', '30 Cherry Street, Suburb', 'madison.nguyen@example.com');


	-- Sample data for MedicalAidClient table
	INSERT INTO MedicalAidClient (MedicalAidID, ClientID, DepNum) VALUES
    (4, 1, 2),
    (1, 2, 1),
    (2, 3, 3),
    (3, 4, 2),
    (4, 5, 1),
    (5, 6, 2),
    (6, 7, 1),
    (7, 8, 3),
    (8, 9, 2),
    (9, 10, 1),
    (10, 11, 2),
    (11, 12, 3),
    (12, 13, 1),
    (13, 14, 2),
    (14, 15, 1),
    (15, 16, 3),
    (16, 17, 2),
    (17, 18, 1),
    (18, 19, 2),
    (19, 20, 3);


	INSERT INTO VisitReason (ReasonWhy, BackgroundInfo)
	VALUES
	('Seeking help for anxiety', 'Patient has been experiencing severe anxiety and panic attacks, impacting daily routines.'),
	('Depression', 'Exhibiting symptoms of depression including prolonged sadness, withdrawal from social activities, and changes in sleep patterns.'),
	('Work-related stress', 'Patient reports high levels of stress and burnout from work, affecting mental and physical health.'),
	('Marital problems', 'Seeking counseling for ongoing marital conflicts and communication issues.'),
	('PTSD symptoms', 'Patient experiencing symptoms of post-traumatic stress disorder following a recent traumatic event.'),
	('ADHD management', 'Looking for strategies to manage ADHD symptoms affecting work and personal life.'),
	('Eating disorder concerns', 'Patient expresses concerns over eating habits and body image, suspecting an eating disorder.'),
	('Insomnia', 'Difficulty falling and staying asleep, leading to chronic fatigue and decreased quality of life.'),
	('Substance dependence', 'Seeking help for dependence on substances as a coping mechanism for stress.'),
	('Grief counseling', 'Patient needs support in dealing with the grief of losing a family member.'),
	('Chronic pain management', 'Looking for psychological support to manage chronic pain and its impact on lifestyle.'),
	('Self-esteem issues', 'Patient struggles with low self-esteem and is seeking ways to build confidence.'),
	('Anger management issues', 'Reports of uncontrollable anger affecting relationships and employment.'),
	('Life transition challenges', 'Struggling to adjust to significant life changes, such as retirement or a new baby.'),
	('Obsessive-compulsive behavior', 'Seeking help for obsessive-compulsive behaviors that are interfering with daily life.'),
	('Social anxiety', 'Patient wants to address social anxiety that inhibits participation in social and professional situations.'),
	('Parenting challenges', 'Seeking guidance on dealing with parenting challenges and child behavior management.'),
	('Bipolar disorder management', 'Patient with diagnosed bipolar disorder seeking assistance in managing mood swings.'),
	('Stress from chronic illness', 'Looking for support in coping with the stress of living with a chronic illness.'),
	('Trauma recovery', 'Patient seeking help in recovering from physical and emotional trauma experienced from an accident.');

	INSERT INTO ServiceType (ServiceType, Description, ICD10, Cost)
	VALUES
	('Psychotherapy', 'Psychotherapy session', 'F43.10', 150.00),
	('Counseling', 'Counseling session', 'Z71.9', 120.00),
	('Psychiatric Evaluation', 'Psychiatric evaluation session', 'F31.9', 200.00),
	('Medication Management', 'Medication management session', 'Z51.81', 180.00),
	('Behavioral Therapy', 'Behavioral therapy session', 'F90.0', 170.00),
	('Family Therapy', 'Family therapy session', 'Z63.0', 160.00),
	('Group Therapy', 'Group therapy session', 'F43.8', 140.00),
	('Substance Abuse Counseling', 'Substance abuse counseling session', 'F10.20', 130.00),
	('Anger Management', 'Anger management session', 'F43.8', 110.00),
	('Art Therapy', 'Art therapy session', 'Z73.1', 100.00),
	('Play Therapy', 'Play therapy session', 'Z76.5', 90.00),
	('Occupational Therapy', 'Occupational therapy session', 'Z75.89', 180.00),
	('Physical Therapy', 'Physical therapy session', 'Z47.1', 170.00),
	('Speech Therapy', 'Speech therapy session', 'Z47.8', 160.00),
	('Nutritional Counseling', 'Nutritional counseling session', 'Z71.3', 150.00),
	('Social Skills Training', 'Social skills training session', 'F80.9', 140.00),
	('Parent Training', 'Parent training session', 'Z76.2', 130.00),
	('Life Skills Training', 'Life skills training session', 'Z73.89', 120.00),
	('Stress Management', 'Stress management session', 'Z73.3', 110.00),
	('Relaxation Techniques', 'Relaxation techniques session', 'Z73.89', 100.00);

	INSERT INTO Receptionist.Child (ClientID, ContactPersonID, School, VisitReasonID, ReportRequired, Grade)
	VALUES
	(31, 41, 'Bright Beginnings Elementary School', 1, 1, 5),
	(16, 36, 'Maplewood Middle School', 2, 0, 8),
	(22, 42, 'Sunset High School', 3, 1, 10),
	(30, 39, 'Pinecrest Academy', 4, 0, 6),
	(20, 43, 'Riverfront School', 5, 1, 4),
	(15, 44, 'Oakridge Middle School', 6, 0, 9),
	(23, 45, 'Hilltop Elementary School', 7, 1, 7),
	(32, 46, 'Valleyview Elementary School', 8, 0, 3),
	(19, 47, 'Greenwood Middle School', 9, 1, 6),
	(5, 38, 'Springfield Elementary School', 10, 0, 8),
	(35, 48, 'Willow Creek Elementary School', 11, 1, 5),
	(14, 49, 'Lakeside Middle School', 12, 0, 7),
	(24, 37, 'Highland High School', 13, 1, 4),
	(33, 50, 'Sunrise Academy', 14, 0, 9),
	(25, 51, 'Meadowbrook School', 15, 1, 6),
	(29, 40, 'Brookside High School', 16, 0, 8),
	(9, 52, 'Seaview Middle School', 17, 1, 7),
	(13, 53, 'Mountainview Elementary School', 18, 0, 5),
	(17, 54, 'Westwood High School', 19, 1, 6),
	(26, 55, 'Cedar Creek Elementary School', 12, 0, 4),
	(34, 56, 'Bright Beginnings Elementary School', 1, 1, 5),
	(3, 57, 'Maplewood Middle School', 2, 0, 8),
	(11, 58, 'Sunset High School', 3, 1, 10),
	(8, 59, 'Pinecrest Academy', 4, 0, 6),
	(6, 60, 'Riverfront School', 5, 1, 4),
	(10, 61, 'Oakridge Middle School', 6, 0, 9),
	(18, 62, 'Hilltop Elementary School', 7, 1, 7),
	(28, 63, 'Valleyview Elementary School', 8, 0, 3),
	(7, 64, 'Greenwood Middle School', 9, 1, 6),
	(27, 65, 'Springfield Elementary School', 10, 0, 8),
	(12, 66, 'Willow Creek Elementary School', 11, 1, 5),
	(21, 64, 'Lakeside Middle School', 12, 0, 7),
	(1, 66, 'Highland High School', 13, 1, 4),
	(4, 66, 'Sunrise Academy', 14, 0, 9),
	(2, 62, 'Meadowbrook School', 15, 1, 6);

	INSERT INTO RelationshipStatus (Description)
	VALUES
	('Married'),
	('Single'),
	('Divorced'),
	('Widowed'),
	('Engaged'),
	('Separated'),
	('In a Relationship'),
	('Complicated'),
	('Open Relationship'),
	('Civil Union'),
	('Domestic Partnership'),
	('Other');

	INSERT INTO Receptionist.Guardian (ClientID, RelationshipStatusID, Occupation)
	VALUES
	(41, 1, 'Engineer'),
	(36, 1, 'Teacher'),
	(42, 1, 'Nurse'),
	(39, 1, 'Graphic Designer'),
	(43, 5, 'Architect'),
	(44, 2, 'Software Developer'),
	(45, 4, 'Accountant'),
	(46, 3, 'Doctor'),
	(47, 4, 'Marketing Specialist'),
	(38, 2, 'Sales Manager'),
	(48, 1, 'Human Resources Manager'),
	(49, 1, 'Construction Worker'),
	(37, 1, 'Pharmacist'),
	(50, 6, 'Chef'),
	(51, 7, 'Electrician'),
	(40, 4, 'Mechanic'),
	(52, 2, 'Artist'),
	(53, 3, 'Entrepreneur'),
	(54, 1, 'Consultant'),
	(55, 1, 'Journalist'),
	(56, 1, 'Physiotherapist'),
	(57, 1, 'Dentist'),
	(58, 9, 'Biologist'),
	(59, 3, 'Economist'),
	(60, 2, 'Veterinarian'),
	(61, 2, 'Civil Engineer'),
	(62, 1, 'Data Analyst'),
	(63, 1, 'Social Worker'),
	(64, 2, 'Copywriter'),
	(65, 3, 'Interior Designer'),
	(66, 1, 'Pilot'),
	(41, 1, 'Engineer'),
	(36, 1, 'Teacher'),
	(42, 1, 'Nurse'),
	(39, 1, 'Graphic Designer'),
	(43, 4, 'Architect'),
	(44, 2, 'Software Developer'),
	(45, 4, 'Accountant'),
	(46, 3, 'Doctor'),
	(47, 4, 'Marketing Specialist'),
	(38, 2, 'Sales Manager'),
	(48, 1, 'Human Resources Manager'),
	(49, 1, 'Construction Worker'),
	(37, 1, 'Pharmacist'),
	(50, 5, 'Chef'),
	(51, 4, 'Electrician'),
	(40, 3, 'Mechanic'),
	(52, 5, 'Artist'),
	(53, 2, 'Entrepreneur'),
	(54, 1, 'Consultant'),
	(55, 1, 'Journalist'),
	(56, 1, 'Physiotherapist'),
	(57, 1, 'Dentist'),
	(58, 4, 'Biologist'),
	(59, 2, 'Economist'),
	(60, 4, 'Veterinarian'),
	(61, 1, 'Civil Engineer'),
	(62, 3, 'Data Analyst'),
	(63, 4, 'Social Worker'),
	(64, 1, 'Copywriter'),
	(65, 1, 'Interior Designer'),
	(66, 2, 'Pilot');

	-- Sample data for GuardianRelationType table
	INSERT INTO GuardianRelationType (Description)
	VALUES
	('Parent'),
	('Legal Guardian'),
	('Step Parent'),
	('Grandparent'),
	('Sibling'),
	('Aunt/Uncle'),
	('Cousin'),
	('Other Relative'),
	('Family Friend'),
	('Foster Parent'),
	('Neighbor'),
	('Teacher'),
	('Caretaker'),
	('Social Worker'),
	('Legal Representative'),
	('No Relation');


	INSERT INTO ChildGuardian (ChildID,GuardianID,GuardianRelationType)
	VALUES
	(31, 1, 1),
	(16, 2, 3),
	(22, 3, 4),
	(30, 4, 2),
	(20, 5,4),
	(15, 6, 9),
	(23, 7, 7),
	(32, 8,3),
	(19, 9,6),
	(5, 10,8),
	(35, 11,5),
	(14, 12,1),
	(24, 13,1),
	(33, 14,1),
	(25, 15,2),
	(29, 16,1),
	(9, 17,7),
	(13, 18,2),
	(17, 19,3),
	(26, 20,4),
	(34, 21,2),
	(3, 22,1),
	(11, 23,1),
	(8, 24,1),
	(6, 25,2),
	(10, 26,1),
	(18, 27,3),
	(28, 28,2),
	(7, 29,1),
	(27, 30,4),
	(12, 31,2),
	(21, 32,3),
	(1, 33,4),
	(4, 34,5),
	(2, 35,6);

	INSERT INTO Receptionist.Adult (ClientID, ContactPersonID, Occupation, RelationshipStatus, VisitReasonID)
	VALUES
	(67, 67, 'Doctor', 1, 1),
	(68, 36, 'Engineer', 2, 2),
	(69, 69, 'Teacher', 3, 2),
	(70, 70, 'Nurse', 4, 4),
	(54, 54, 'Accountant', 1, 5),
	(60, 60, 'Lawyer', 2, 6),
	(40, 40, 'Artist', 3, 7),
	(46, 46, 'Manager', 6, 8),
	(59, 59, 'Entrepreneur', 1, 9),
	(62, 62, 'Psychologist', 2, 10);
		-- Sample data for AccountStatus table
	INSERT INTO AccountStatus (Description)
	VALUES
	('Settled'),
	('Overdue');

	INSERT INTO Receptionist.Accounts (ClientID, PersonRFP, AccountStatusID, AmountOutStanding)
	VALUES
	(31, 41, 1, 500.00),
	(16, 36, 1, 750.00),
	(22, 42, 1, 600.00),
	(30, 39, 1, 900.00),
	(20, 43, 1, 450.00),
	(15, 44, 1, 700.00),
	(23, 55, 1, 550.00),
	(32, 60, 1, 800.00),
	(19, 63, 1, 650.00),
	(5, 50, 1, 850.00),
	(35, 66, 1, 750.00),
	(14, 37, 1, 700.00),
	(24, 58, 1, 600.00),
	(33, 49, 1, 500.00),
	(25, 53, 1, 450.00),
	(29, 60, 1, 550.00),
	(9, 62, 1, 800.00),
	(13, 64, 1, 700.00),
	(68, 48, 1, 650.00),
	(70, 43, 1, 850.00);

	INSERT INTO Receptionist.AccountDiscount (AccountID, Amount, Date, Reason)
	VALUES
	(1, 50.00, '2023-05-15', 'Early payment discount'),
	(2, 25.00, '2023-06-20', 'Referral discount'),
	(3, 60.00, '2023-07-10', 'Seasonal promotion discount'),
	(4, 75.00, '2023-08-05', 'Customer loyalty discount'),
	(5, 40.00, '2023-09-12', 'Bulk purchase discount'),
	(6, 65.00, '2023-10-18', 'Special event discount'),
	(7, 30.00, '2023-11-25', 'Holiday discount'),
	(8, 70.00, '2023-12-30', 'End-of-year clearance discount'),
	(9, 55.00, '2024-01-05', 'New year promotion discount'),
	(10, 80.00, '2024-02-14', 'Valentine''s Day discount'),
	(11, 70.00, '2024-03-20', 'Spring sale discount'),
	(12, 60.00, '2024-04-25', 'Anniversary discount'),
	(13, 50.00, '2024-05-30', 'Memorial Day discount'),
	(14, 40.00, '2024-06-15', 'Father Day discount'),
	(15, 30.00, '2024-07-20', 'Summer sale discount'),
	(16, 20.00, '2024-08-25', 'Back-to-school discount'),
	(17, 10.00, '2024-09-30', 'Labor Day discount'),
	(18, 45.00, '2024-10-05', 'Mid-autumn Festival discount'),
	(19, 35.00, '2024-11-10', 'Veterans Day discount'),
	(20, 15.00, '2024-12-15', 'Holiday season discount');

	-- Sample data for ClientAppointment table
	INSERT INTO Receptionist.ClientAppointment (ClientID, AppointmentType, AppointmentDate, PractitionerID)
	VALUES
	(31, 1, '2024-04-01 09:00:00', 1),
	(16, 2, '2024-04-02 10:00:00', 2),
	(32, 3, '2024-04-03 11:00:00', 3),
	(25, 4, '2024-04-04 12:00:00', 4),
	(17, 5, '2024-04-05 13:00:00', 5),
	(33, 6, '2024-04-06 14:00:00', 6),
	(26, 7, '2024-04-07 15:00:00', 1),
	(29, 8, '2024-04-08 16:00:00', 8),
	(33, 9, '2024-04-09 17:00:00', 2),
	(20, 10, '2024-04-10 18:00:00', 5),
	(14, 11, '2024-04-11 09:00:00', 6),
	(24, 12, '2024-04-12 10:00:00', 7),
	(33, 13, '2024-04-13 11:00:00', 6),
	(25, 14, '2024-04-14 12:00:00', 2),
	(29, 15, '2024-04-15 13:00:00', 1),
	(9, 16, '2024-04-16 14:00:00', 9),
	(13, 17, '2024-04-17 15:00:00', 4),
	(68, 18, '2024-04-18 16:00:00', 3),
	(70, 19, '2024-04-19 17:00:00', 2),
	(32, 20, '2024-04-20 18:00:00', 8);

	-- Sample data for Invoice table
	INSERT INTO Receptionist.Invoice (AccountID, InvoiceNum, InvoiceDate, InvoiceTotal, AppointmentID)
	VALUES
	(1, 'INV001', '2024-04-01', 150.00, 1),
	(2, 'INV002', '2024-04-02', 120.00, 2),
	(3, 'INV003', '2024-04-03', 200.00, 3),
	(4, 'INV004', '2024-04-04', 180.00, 4),
	(5, 'INV005', '2024-04-05', 300.00, 5),
	(6, 'INV006', '2024-04-06', 160.00, 6),
	(7, 'INV007', '2024-04-07', 140.00, 7),
	(8, 'INV008', '2024-04-08', 130.00, 8),
	(9, 'INV009', '2024-04-09', 150.00, 9),
	(10, 'INV010', '2024-04-10', 140.00, 10),
	(1, 'INV011', '2024-04-11', 130.00, 11),
	(12, 'INV012', '2024-04-12', 120.00, 12),
	(13, 'INV013', '2024-04-13', 180.00, 13),
	(14, 'INV014', '2024-04-14', 170.00, 14),
	(15, 'INV015', '2024-04-15', 160.00, 15),
	(16, 'INV016', '2024-04-16', 150.00, 16),
	(17, 'INV017', '2024-04-17', 140.00, 17),
	(18, 'INV018', '2024-04-18', 130.00, 18),
	(19, 'INV019', '2024-04-19', 120.00, 19),
	(20, 'INV020', '2024-04-20', 180.00, 8);

	-- Sample data for InvoicePayments table
	INSERT INTO Receptionist.InvoicePayments (InvoiceID, Amount, Date)
	VALUES
	(1, 150.00, '2024-04-01'),
	(2, 120.00, '2024-04-02'),
	(3, 200.00, '2024-04-03'),
	(4, 180.00, '2024-04-04'),
	(5, 170.00, '2024-04-05'),
	(6, 160.00, '2024-04-06'),
	(7, 140.00, '2024-04-07'),
	(8, 130.00, '2024-04-08'),
	(9, 150.00, '2024-04-09'),
	(10, 140.00, '2024-04-10'),
	(11, 130.00, '2024-04-11'),
	(12, 120.00, '2024-04-12'),
	(13, 180.00, '2024-04-13'),
	(14, 170.00, '2024-04-14'),
	(15, 160.00, '2024-04-15'),
	(16, 150.00, '2024-04-16'),
	(17, 140.00, '2024-04-17'),
	(18, 130.00, '2024-04-18'),
	(19, 120.00, '2024-04-19'),
	(5, 80.00, '2024-04-20');

	-- Sample data for ReportTypes table
	INSERT INTO ReportTypes (Type, Description, Cost)
	VALUES
	('Initial Assessment', 'Initial assessment report', 100),
	('Progress Report', 'Progress report on client', 80),
	('Treatment Plan', 'Treatment plan report', 120),
	('Final Evaluation', 'Final evaluation report', 150),
	('Follow-up Report', 'Follow-up report on client', 90),
	('Specialized Assessment', 'Specialized assessment report', 130),
	('Behavioral Analysis', 'Behavioral analysis report', 110),
	('Intervention Summary', 'Intervention summary report', 140),
	('Diagnostic Report', 'Diagnostic report on client', 160),
	('Therapeutic Program', 'Therapeutic program report', 170),
	('Evaluation Report', 'Evaluation report on client', 180),
	('Case Management Plan', 'Case management plan report', 190),
	('Psychological Assessment', 'Psychological assessment report', 200),
	('Educational Report', 'Educational report on client', 210),
	('Cognitive Evaluation', 'Cognitive evaluation report', 220),
	('Social Skills Assessment', 'Social skills assessment report', 230),
	('Behavioral Intervention Plan', 'Behavioral intervention plan report', 240),
	('Functional Behavior Assessment', 'Functional behavior assessment report', 250),
	('Language Evaluation', 'Language evaluation report', 260),
	('Occupational Therapy Report', 'Occupational therapy report on client', 270);

	-- Sample data for ReportStatus table
	INSERT INTO ReportStatus (Description)
	VALUES
	('Pending'),
	('In Progress'),
	('Completed'),
	('On Hold'),
	('Cancelled');

	-- Sample data for Report table
	-- Assuming each client has at least one report entry
	INSERT INTO Doctor.Report (ClientID, ReportTypeID, ReportStatusID, Notes)
	VALUES
	(31, 1, 1, 'Initial assessment report for John Doe'),
	(16, 2, 3, 'Progress report for Jane Smith'),
	(22, 3, 2, 'Treatment plan for Michael Johnson'),
	(30, 4, 2, 'Final evaluation report for Emily Brown'),
	(20, 5, 1, 'Follow-up report for David Martinez'),
	(15, 6, 1, 'Specialized assessment report for Sarah Taylor'),
	(23, 7, 2, 'Behavioral analysis report for Christopher Anderson'),
	(32, 8, 3, 'Intervention summary report for Amanda Wilson'),
	(19, 9, 2, 'Diagnostic report for James Garcia'),
	(5, 10, 1, 'Therapeutic program report for Jessica Lopez'),
	(35, 11, 3, 'Evaluation report for Matthew Hernandez'),
	(14, 12, 1, 'Case management plan report for Lauren Young'),
	(24, 13, 3, 'Psychological assessment report for Ryan Miller'),
	(33, 14, 2, 'Educational report for Ashley King'),
	(25, 15, 1, 'Cognitive evaluation report for Daniel Lee'),
	(29, 16, 2, 'Social skills assessment report for Megan Gonzalez'),
	(9, 17, 1, 'Behavioral intervention plan report for Kevin White'),
	(13, 18, 3, 'Functional behavior assessment report for Rachel Martinez'),
	(68, 19, 2, 'Language evaluation report for Justin Davis'),
	(70, 14, 3, 'Occupational therapy report for Brittany Hernandez');

-- Sample data for Accounts table
    COMMIT TRANSACTION; -- If everything is successful, commit the transaction
END TRY
BEGIN CATCH
    -- If there's an error, roll back the transaction
    ROLLBACK TRANSACTION;

    -- Error handling: capture and rethrow the error
    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrorState INT = ERROR_STATE();
    RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
END CATCH
GO
--data queries
SELECT 
    c.ClientID,
    c.Name,
    c.Surname,
    ISNULL(SUM(a.AmountOutstanding), 0) AS TotalOutstandingAmount
FROM 
    Client c
LEFT JOIN 
    Receptionist.Accounts a ON c.ClientID = a.ClientID
GROUP BY 
    c.ClientID, c.Name, c.Surname;

SELECT 
    ca.AppointmentID,
    c.Name AS ClientName,
    c.Surname AS ClientSurname,
    s.ServiceType AS AppointmentType,
    ca.AppointmentDate,
    p.Name AS PractitionerName,
    p.Surname AS PractitionerSurname
FROM 
    Receptionist.ClientAppointment ca
JOIN 
    Client c ON ca.ClientID = c.ClientID
JOIN 
    ServiceType s ON ca.AppointmentType = s.ServiceTypeID
JOIN 
    Doctor.Practitioner p ON ca.PractitionerID = p.PractitionerID
ORDER BY AppointmentDate ASC;

SELECT
    p.PractitionerID,
    p.Name + ' ' + p.Surname AS PractitionerName,
    COUNT(ca.AppointmentID) AS NumberOfAppointments
FROM
    Doctor.Practitioner p
INNER JOIN
    Receptionist.ClientAppointment ca ON p.PractitionerID = ca.PractitionerID
GROUP BY
    p.PractitionerID,
    p.Name,
    p.Surname
HAVING
    COUNT(ca.AppointmentID) > 0
ORDER BY
    NumberOfAppointments DESC;

SELECT
    ch.ChildID,
    cli.Name AS ChildName,
    cli.Surname AS ChildSurname,
    cli2.Name AS GuardianName,
    cli2.Surname AS GuardianSurname,
 
    grt.Description AS GuardianRelationshipType
FROM 
    Receptionist.Child ch
INNER JOIN 
    Client cli ON ch.ClientID = cli.ClientID
INNER JOIN 
    ChildGuardian cg ON ch.ChildID = cg.ChildID
INNER JOIN 
    Receptionist.Guardian gu ON cg.GuardianID = gu.GuardianID
INNER JOIN 
    Client cli2 ON gu.ClientID = cli2.ClientID
INNER JOIN 
    GuardianRelationType grt ON cg.GuardianRelationType = grt.RelationshipTypeID
ORDER BY 
    ch.ChildID, gu.GuardianID;


SELECT 
    i.InvoiceID,
    c.Name AS ClientName,
    c.Surname AS ClientSurname,
    i.InvoiceNum,
    i.InvoiceDate,
    i.InvoiceTotal,
    ISNULL(SUM(ip.Amount), 0) AS TotalPayments
FROM 
    Receptionist.Invoice i
JOIN 
    Receptionist.Accounts a ON i.AccountID = a.AccountID
JOIN 
    Client c ON a.ClientID = c.ClientID
LEFT JOIN 
    Receptionist.InvoicePayments ip ON i.InvoiceID = ip.InvoiceID
GROUP BY 
    i.InvoiceID, c.Name, c.Surname, i.InvoiceNum, i.InvoiceDate, i.InvoiceTotal;
	--Views
	CREATE VIEW InvoiceDetailsView AS
SELECT 
    i.InvoiceID,
    c.Name AS ClientName,
    c.Surname AS ClientSurname,
    i.InvoiceNum,
    i.InvoiceDate,
    i.InvoiceTotal,
    ISNULL(SUM(ip.Amount), 0) AS TotalPayments
FROM 
    Receptionist.Invoice i
JOIN 
    Receptionist.Accounts a ON i.AccountID = a.AccountID
JOIN 
    Receptionist.Client c ON a.ClientID = c.ClientID
LEFT JOIN 
    Receptionist.InvoicePayments ip ON i.InvoiceID = ip.InvoiceID
GROUP BY 
    i.InvoiceID, c.Name, c.Surname, i.InvoiceNum, i.InvoiceDate, i.InvoiceTotal;
GO

CREATE OR ALTER VIEW Receptionist.ClientWithGuardiansView AS
SELECT 
    c.Name AS ChildtName,
    c.Surname AS ChildSurname,
    cli.Name AS GuardianName,
    cli.Surname AS GuardianSurname,
    grt.Description AS GuardianRelationship
FROM 
    Receptionist.Client c
JOIN 
    ChildGuardian cg ON c.ClientID = cg.ChildID
JOIN 
    Receptionist.Guardian g ON cg.GuardianID = g.GuardianID
JOIN
    Receptionist.Client cli ON g.ClientID = cli.ClientID
JOIN 
    RelationshipStatus rs ON g.RelationshipStatusID = rs.RelationshipStatusID
JOIN
    GuardianRelationType grt ON cg.GuardianRelationType = grt.RelationshipTypeID;
GO

CREATE VIEW ClientAccountSummaryView AS
SELECT 
    c.ClientID,
    c.Name,
    c.Surname,
    ISNULL(SUM(a.AmountOutstanding), 0) AS TotalOutstandingAmount
FROM 
    Receptionist.Client c
LEFT JOIN 
    Receptionist.Accounts a ON c.ClientID = a.ClientID
GROUP BY 
    c.ClientID, c.Name, c.Surname;
GO
--stored procedures
CREATE OR ALTER PROCEDURE UpdateClientPhoneNumber
    @ClientID INT,
    @NewPhoneNumber NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SQL NVARCHAR(MAX);

    SET @SQL = '
        UPDATE Receptionist.Client
        SET Phone = @NewPhoneNumber
        WHERE ClientID = @ClientID;
    ';

    EXEC sp_executesql @SQL, N'
        @ClientID INT,
        @NewPhoneNumber NVARCHAR(20)',
        @ClientID, @NewPhoneNumber;
END;
GO


CREATE OR ALTER PROCEDURE GenerateClientReport
    @ClientID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SQL NVARCHAR(MAX);

    -- Modified the WHERE clause to include a check for positive outstanding amounts.
    SET @SQL = N'
        SELECT 
            c.Name AS ClientName,
            c.Surname AS ClientSurname,   
            i.InvoiceDate AS InvoiceDate,
            i.InvoiceTotal AS InvoiceTotal
        FROM 
            Receptionist.Client c
        INNER JOIN
            Receptionist.Accounts a ON c.ClientID = a.ClientID AND a.AmountOutStanding > 0
        LEFT JOIN
            Receptionist.Invoice i ON a.AccountID = i.AccountID
        WHERE
            c.ClientID = @ClientID
            AND EXISTS ( -- Added to ensure only clients with at least one outstanding invoice are included
                SELECT 1
                FROM Receptionist.Invoice iv
                WHERE iv.AccountID = a.AccountID
                AND iv.InvoiceTotal > 0 -- Assumes InvoiceTotal > 0 indicates outstanding
            );
    ';

    EXEC sp_executesql @SQL, N'@ClientID INT', @ClientID;
END;
GO


CREATE OR ALTER PROCEDURE AddServiceType
    @ServiceName NVARCHAR(80),
    @Description NVARCHAR(150),
    @ICD10 NVARCHAR(30),
    @Cost MONEY
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SQL NVARCHAR(MAX);

    SET @SQL = '
        INSERT INTO ServiceType (ServiceType, Description, ICD10, Cost)
        VALUES (@ServiceName, @Description, @ICD10, @Cost);';

    EXEC sp_executesql @SQL, N'
        @ServiceName NVARCHAR(80),
        @Description NVARCHAR(150),
        @ICD10 NVARCHAR(30),
        @Cost MONEY',
        @ServiceName, @Description, @ICD10, @Cost;
END;
GO
--Triggers
CREATE TRIGGER TrackAccountChanges
ON Receptionist.Accounts
AFTER UPDATE, DELETE
AS
BEGIN
    IF EXISTS (SELECT * FROM deleted)
    BEGIN
        INSERT INTO AccountAudit(AccountID, Operation, ChangeDate)
        SELECT AccountID, 'Deleted', GETDATE() FROM deleted;
    END;

    IF EXISTS (SELECT * FROM inserted)
    BEGIN
        INSERT INTO AccountAudit (AccountID, Operation, ChangeDate)
        SELECT AccountID, 'Updated', GETDATE() FROM inserted;
    END;
END;
Go

CREATE TRIGGER PreventClientDeletion
ON Receptionist.Client
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT * FROM Child WHERE ClientID IN (SELECT ClientID FROM deleted))
    BEGIN
        IF NOT EXISTS (SELECT * FROM Adult WHERE ClientID IN (SELECT ClientID FROM deleted))
        BEGIN
            IF NOT EXISTS (SELECT * FROM Guardian WHERE ClientID IN (SELECT ClientID FROM deleted))
            BEGIN
                DELETE FROM Client WHERE ClientID IN (SELECT ClientID FROM deleted);
            END;
            ELSE
            BEGIN
                RAISERROR ('Cannot delete client: associated guardians exist.', 16, 1);
            END;
        END;
        ELSE
        BEGIN
            RAISERROR ('Cannot delete client: associated adults exist.', 16, 1);
        END;
    END;
    ELSE
    BEGIN
        RAISERROR ('Cannot delete client: associated children exist.', 16, 1);
    END;
END;
GO

CREATE TRIGGER AutoGenerateReport
ON Receptionist.ClientAppointment
AFTER INSERT
AS
BEGIN
    -- Temp table to hold ServiceTypeIDs for Pediatric and General Checkups
    DECLARE @PediatricCheckupServiceTypeID INT, @GeneralCheckupServiceTypeID INT;
    SELECT @PediatricCheckupServiceTypeID = ServiceTypeID FROM ServiceType WHERE ServiceType = 'Pediatric Checkup';
    SELECT @GeneralCheckupServiceTypeID = ServiceTypeID FROM ServiceType WHERE ServiceType = 'General Checkup';

    -- Insert Pediatric Checkup Reports
    INSERT INTO Doctor.Report(ClientID, ReportTypeID, ReportStatusID, Notes)
    SELECT i.ClientID, 1, 1, 'Pediatric checkup report auto-generated.'
    FROM inserted i
    INNER JOIN Client c ON i.ClientID = c.ClientID
    WHERE DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) < 18
    AND i.AppointmentType = @PediatricCheckupServiceTypeID;

    -- Insert General Checkup Reports
    INSERT INTO Doctor.Report (ClientID, ReportTypeID, ReportStatusID, Notes)
    SELECT i.ClientID, 2, 1, 'General checkup report auto-generated.'
    FROM inserted i
    INNER JOIN Client c ON i.ClientID = c.ClientID
    WHERE DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) >= 18
    AND i.AppointmentType = @GeneralCheckupServiceTypeID;
END;
GO
--User Logins
USE DrJKnoetze;
GO

BEGIN TRANSACTION;
BEGIN TRY
    -- Check and create roles if they do not exist
    IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'Doctor')
        CREATE ROLE Doctor;
        
    IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'Receptionist')
        CREATE ROLE Receptionist;
        
    -- Check and create logins if they do not exist
    IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = N'DoctorLogin')
    BEGIN
        CREATE LOGIN DoctorLogin WITH PASSWORD = 'P@ssw0rd1';
        CREATE USER DoctorUser FOR LOGIN DoctorLogin;
        ALTER ROLE Doctor ADD MEMBER DoctorUser;
    END

    IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = N'ReceptionistLogin')
    BEGIN
        CREATE LOGIN ReceptionistLogin WITH PASSWORD = 'P@ssw0rd2';
        CREATE USER ReceptionistUser FOR LOGIN ReceptionistLogin;
        ALTER ROLE Receptionist ADD MEMBER ReceptionistUser;
    END

	GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Doctor TO Doctor;

	GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Receptionist TO Receptionist;

    COMMIT TRANSACTION; -- If everything is successful, commit the transaction
END TRY
BEGIN CATCH
    -- If there's an error, roll back the transaction
    ROLLBACK TRANSACTION;

    -- Error handling: capture and rethrow the error
    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrorState INT = ERROR_STATE();
    RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
END CATCH
--Cursors
DECLARE @ClientID INT;
DECLARE @ClientName NVARCHAR(60);

-- Adjust the cursor to only select clients with outstanding invoices.
DECLARE ReportCursor CURSOR FOR
    SELECT DISTINCT c.ClientID, c.Name + ' ' + c.Surname
    FROM Receptionist.Client c
    JOIN Receptionist.Accounts a ON c.ClientID = a.ClientID
    WHERE EXISTS (
        SELECT 1
        FROM Receptionist.Invoice i
        WHERE i.AccountID = a.AccountID
          AND i.InvoiceTotal > 0 -- Assumes InvoiceTotal > 0 indicates an outstanding invoice
          AND a.AmountOutStanding > 0 -- Ensures there's an outstanding amount in the account
    );

OPEN ReportCursor;

FETCH NEXT FROM ReportCursor INTO @ClientID, @ClientName;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- This PRINT statement will now only include clients with outstanding invoices.
    PRINT 'Generating report for Client: ' + @ClientName;

    -- Execute the stored procedure for the current client.
    EXEC GenerateClientReport @ClientID;

    FETCH NEXT FROM ReportCursor INTO @ClientID, @ClientName;
END

CLOSE ReportCursor;
DEALLOCATE ReportCursor;
GO
DECLARE @ClientID INT, @ClientName NVARCHAR(255), @TotalOutstanding MONEY;

-- Modified cursor to include a join and SUM directly in the cursor's SELECT statement,
-- filtering clients with a positive total outstanding amount.
DECLARE ClientCursor CURSOR FOR
    SELECT a.ClientID, c.Name, SUM(a.AmountOutStanding) AS TotalOutstanding
    FROM Receptionist.Accounts a
    JOIN Client c ON a.ClientID = c.ClientID
    GROUP BY a.ClientID, c.Name
    HAVING SUM(a.AmountOutStanding) > 0;

OPEN ClientCursor;

FETCH NEXT FROM ClientCursor INTO @ClientID, @ClientName, @TotalOutstanding;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT 'Client: ' + CAST(@ClientID AS NVARCHAR(10)) + ' | ' + @ClientName + ', Total Outstanding: ' + CAST(@TotalOutstanding AS NVARCHAR(20));

    FETCH NEXT FROM ClientCursor INTO @ClientID, @ClientName, @TotalOutstanding;
END

CLOSE ClientCursor;
DEALLOCATE ClientCursor;
DECLARE @PractitionerID INT;
DECLARE @PractitionerName NVARCHAR(60);
DECLARE @ClientName NVARCHAR(60);
DECLARE @AppointmentDate DATETIME; -- Declare variable for AppointmentDate

-- Cursor to iterate through each practitioner that has appointments
DECLARE PractitionerCursor CURSOR FOR
    SELECT DISTINCT p.PractitionerID, p.Name + ' ' + p.Surname
    FROM Doctor.Practitioner p
    JOIN Receptionist.ClientAppointment ca ON p.PractitionerID = ca.PractitionerID;

OPEN PractitionerCursor;
FETCH NEXT FROM PractitionerCursor INTO @PractitionerID, @PractitionerName;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT 'Practitioner: ' + @PractitionerName; -- Print the practitioner's name once

    -- Sub-cursor to fetch and print names of clients and their appointment dates for the current practitioner
    DECLARE ClientCursor CURSOR FOR
        SELECT c.Name + ' ' + c.Surname AS ClientName, ca.AppointmentDate
        FROM Receptionist.ClientAppointment ca
        INNER JOIN Client c ON ca.ClientID = c.ClientID
        WHERE ca.PractitionerID = @PractitionerID
        ORDER BY ca.AppointmentDate; -- Added ordering to sort appointments chronologically

    OPEN ClientCursor;
    FETCH NEXT FROM ClientCursor INTO @ClientName, @AppointmentDate;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Print each client's name along with the appointment date
        PRINT ' - Client: ' + @ClientName + ', Appointment Date: ' + CONVERT(NVARCHAR, @AppointmentDate, 120);
        FETCH NEXT FROM ClientCursor INTO @ClientName, @AppointmentDate;
    END

    CLOSE ClientCursor;
    DEALLOCATE ClientCursor;

    FETCH NEXT FROM PractitionerCursor INTO @PractitionerID, @PractitionerName;
	PRINT ' ';
END

CLOSE PractitionerCursor;
DEALLOCATE PractitionerCursor;

USE DrJKnoetze
GO

DECLARE @PractitionerID INT;
DECLARE @PractitionerName NVARCHAR(60);

-- Outer Cursor: Iterate over each Practitioner
DECLARE PractitionerCursor CURSOR FOR
    SELECT PractitionerID, Name
    FROM Doctor.Practitioner;

OPEN PractitionerCursor;
FETCH NEXT FROM PractitionerCursor INTO @PractitionerID, @PractitionerName;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT 'Practitioner : '+ @PractitionerName;
    PRINT 'Qualifications: ';

    DECLARE @Name NVARCHAR(30), @Institution NVARCHAR(80), @YearObtained SMALLINT;

    -- Inner Cursor: Iterate over Qualifications for the current Practitioner
    DECLARE QualificationCursor CURSOR FOR
        SELECT Name, pq.Institution, pq.YearObtained
        FROM Doctor.Qualification q
        INNER JOIN Doctor.PractitionerQualification pq ON q.QualificationID = pq.QualificationID
        WHERE pq.PractitionerID = @PractitionerID
        ORDER BY pq.YearObtained;

    OPEN QualificationCursor;
    FETCH NEXT FROM QualificationCursor INTO @Name, @Institution, @YearObtained;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT '- '+ @Name + '| ' + @Institution + ' | ' + CAST(@YearObtained AS NVARCHAR(5));
        FETCH NEXT FROM QualificationCursor INTO @Name, @Institution, @YearObtained;
    END

    CLOSE QualificationCursor;
    DEALLOCATE QualificationCursor;

    FETCH NEXT FROM PractitionerCursor INTO @PractitionerID, @PractitionerName;
	PRINT ' ';
END

CLOSE PractitionerCursor;
DEALLOCATE PractitionerCursor;

