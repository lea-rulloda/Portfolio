--Housing Data Cleaning Using Microsoft SQL Server

SELECT *
FROM Portfolio.dbo.Housing_Data
ORDER BY ParcelID;

--Formatting the SaleDate to get rid of the unnecessary time format
SELECT SaleDate, CONVERT(DATE, SaleDate)
FROM Portfolio.dbo.Housing_Data
ORDER BY ParcelID;

ALTER TABLE Housing_Data
ADD SaleDateFormatted DATE;

UPDATE Housing_Data
SET SaleDateFormatted = CONVERT(DATE, SaleDate);

--Populating the PropertyAddress
/*There are rows that contain NULL values of PropertyAddress.
To address this, rows with the same ParcelID is assigned the same PropertyAddress.*/

SELECT *
FROM Portfolio.dbo.Housing_Data
WHERE PropertyAddress IS NULL
ORDER BY ParcelID;

SELECT a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress, ISNULL(a.PropertyAddress,b.PropertyAddress) AS PropertyAddress
FROM Portfolio.dbo.Housing_Data a
JOIN Portfolio.dbo.Housing_Data b
	ON a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ]
WHERE a.PropertyAddress IS NULL;

UPDATE a
SET PropertyAddress = ISNULL(a.PropertyAddress,b.PropertyAddress)
FROM Portfolio.dbo.Housing_Data a
JOIN Portfolio.dbo.Housing_Data b
	ON a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ]
WHERE a.PropertyAddress IS NULL;

--Breaking down the address into separate columns each for street address and city
--PropertyAddress
--Using SUBSTRING
SELECT PropertyAddress
FROM Portfolio.dbo.Housing_Data
ORDER BY ParcelID;

SELECT
SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) -1) AS PropertyAddressStreet,
SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) +1, LEN(PropertyAddress)) AS PropertyAddressCity
FROM Portfolio.dbo.Housing_Data
ORDER BY ParcelID;

ALTER TABLE Housing_Data
ADD PropertyAddressStreet NVARCHAR(255);

UPDATE Housing_Data
SET PropertyAddressStreet = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) -1);

ALTER TABLE Housing_Data
ADD PropertyAddressCity NVARCHAR(255);

UPDATE Housing_Data
SET PropertyAddressCity = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1 , LEN(PropertyAddress));

--OwnerAddress
--Using PARSENAME
SELECT OwnerAddress
FROM Portfolio.dbo.Housing_Data
ORDER BY ParcelID;

SELECT
PARSENAME(REPLACE(OwnerAddress, ',', '.') , 3) AS OwnerAddressStreet,
PARSENAME(REPLACE(OwnerAddress, ',', '.') , 2) AS OwnerAddressCity,
PARSENAME(REPLACE(OwnerAddress, ',', '.') , 1) AS OwnerAddressState
FROM Portfolio.dbo.Housing_Data
ORDER BY ParcelID;

ALTER TABLE Housing_Data
ADD OwnerAddressStreet NVARCHAR(255);

UPDATE Housing_Data
SET OwnerAddressStreet = PARSENAME(REPLACE(OwnerAddress, ',', '.') , 3);


ALTER TABLE Housing_Data
ADD OwnerAddressCity NVARCHAR(255);

UPDATE Housing_Data
SET OwnerAddressCity = PARSENAME(REPLACE(OwnerAddress, ',', '.') , 2);


ALTER TABLE Housing_Data
ADD OwnerAddressState NVARCHAR(255);

UPDATE Housing_Data
SET OwnerAddressState = PARSENAME(REPLACE(OwnerAddress, ',', '.') , 1);

Select *
FROM Portfolio.dbo.Housing_Data
ORDER BY ParcelID;

--SoldAsVacant column has inconsistent formatting
SELECT DISTINCT SoldAsVacant, COUNT(SoldAsVacant) AS Count_SoldAsVacant
FROM Portfolio.dbo.Housing_Data
GROUP BY SoldAsVacant
ORDER BY 2 DESC;

--Replacing 'Y' and 'N' values in SoldAsVacant column to 'Yes' and 'No' respectively for uniformity
SELECT SoldAsVacant,
	CASE
		WHEN SoldAsVacant = 'Y' THEN 'Yes'
		WHEN SoldAsVacant = 'N' THEN 'No'
		ELSE SoldAsVacant
	END
FROM Portfolio.dbo.Housing_Data;

UPDATE Housing_Data
SET SoldAsVacant = CASE
		WHEN SoldAsVacant = 'Y' THEN 'Yes'
		WHEN SoldAsVacant = 'N' THEN 'No'
		ELSE SoldAsVacant
	END;

--Removing duplicate data
WITH Duplicates AS (
	SELECT *,
		ROW_NUMBER() OVER (
		PARTITION BY ParcelID,
					 PropertyAddress,
					 SalePrice,
					 SaleDate,
					 LegalReference
		ORDER BY UniqueID
		) rownum
	FROM Portfolio.dbo.Housing_Data
)
SELECT *
FROM Duplicates
WHERE rownum > 1
ORDER BY PropertyAddress;