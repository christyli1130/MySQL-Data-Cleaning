create database housing_data_cleaning;
use housing_data_cleaning;
set sql_safe_updates =0;  

-- --------------------------------------------------------------------------

-- 1. Standardize data format

-- CONVERT function (does not work)
select SaleDate,convert(SaleDate,Date)
	from HousingData
    ;
    
-- STR_TO_DATE function (work)
select SaleDate,str_to_date(SaleDate,'%M %e, %Y')
	from HousingData
    ;
  
update HousingData 
	set SaleDate=str_to_date(SaleDate,'%M %e, %Y')
    ;

-- --------------------------------------------------------------------------

-- 2. Populate Property Address Data

-- Each ParcelID paris with an address
select *
	from HousingData
	-- where PropertyAddress = ''
    order by ParcelID
    ;
    
-- Self join the table to look up the corresponding propert address of the ParcelID
select a.ParcelID, a.PropertyAddress,b.ParcelID,b.PropertyAddress
	,case when a.PropertyAddress ='' then b.PropertyAddress
    end FillinPropertyAddress
	from HousingData a
    join HousingData b
    on a.ParcelID=b.ParcelID
    and a.UniqueID <> b.UniqueID
    where a.PropertyAddress = ''
    ;

-- Use UPDATE function with JOIN
Update HousingData a 
	join HousingData b
    on a.ParcelID=b.ParcelID
    and a.UniqueID <> b.UniqueID
    set a.PropertyAddress = b.PropertyAddress
    where a.PropertyAddress = ''
    ;
    
-- --------------------------------------------------------------------------

-- 3. Breaking out property address into individual columns (Address, City)
Select PropertyAddress
from HousingData
;

-- Use SUBSTRING, POSITION, LENGTH function
Select PropertyAddress
	,substring(PropertyAddress,1,position(',' in PropertyAddress)-1)
    ,substring(PropertyAddress,position(',' in PropertyAddress)+2,length(PropertyAddress))
	from HousingData
    ;

-- add new columns to the table

alter table HousingData
	add PropertySplitAddress nvarchar(255)
    ;

Update HousingData
	set PropertySplitAddress = substring(PropertyAddress,1,position(',' in PropertyAddress)-1)
    ;

alter table HousingData
	add PropertySplitCity nvarchar(255)
    ;	

Update HousingData
	set PropertySplitCity= substring(PropertyAddress,position(',' in PropertyAddress)+2,length(PropertyAddress))
    ;

-- --------------------------------------------------------------------------

-- 4. Breaking out owner address into individual columns (Address, City, State)

-- use SUBSTRING_INDEX function
select OwnerAddress, substring_index(OwnerAddress,',',1) as OwnerSplitAddress
,substring_index(substring_index(OwnerAddress,',',2),',',-1) as OwnerSplitCity
,substring_index(OwnerAddress,',',-1) as OwnerSplitState
from HousingData
;

-- add new columns to the table
alter table HousingData
add OwnerSplitAddress varchar(255)
;

update HousingData
	set OwnerSplitAddress=substring_index(OwnerAddress,',',1)
    ;

alter table HousingData
add OwnerSplitCity varchar(255)
;

update HousingData
	set OwnerSplitCity=substring_index(substring_index(OwnerAddress,',',2),',',-1) 
    ;

alter table HousingData
add OwnerSplitState varchar(255)
;

update HousingData
	set OwnerSplitState=substring_index(OwnerAddress,',',-1) 
    ;
    
-- Removing additional spacing in OwnerSplitCity and OwnerSplitState

select OwnerSplitCity
	,substring(OwnerSplitCity,2,length(OwnerSplitCity)) as nospacing
    ,OwnerSplitState
    ,substring(OwnerSplitState,2,length(OwnerSplitState)) as nospacingstate
    from HousingData
    ;

update HousingData
	set OwnerSplitCity=substring(OwnerSplitCity,2,length(OwnerSplitCity))
    ;

update HousingData
	set OwnerSplitState=substring(OwnerSplitState,2,length(OwnerSplitState))
    ;

-- --------------------------------------------------------------------------

-- 5. Change 'Y' and 'N' to 'Yes' and 'No' in "Sold as Vacant" column

select distinct SoldAsVacant, count(SoldAsVacant) 
from HousingData
group by SoldAsVacant
order by 2
;

-- Use CASE statement
select SoldAsVacant
	,case when SoldAsVacant='Y' then 'Yes'
		when SoldAsVacant='N' then 'No'
        else SoldAsVacant
		end
	from HousingData
    where SoldAsVacant in ('Y','N')
    ;

update HousingData
	set SoldAsVacant =case when SoldAsVacant='Y' then 'Yes'
		when SoldAsVacant='N' then 'No'
        else SoldAsVacant
		end
        ;
	
-- --------------------------------------------------------------------------

-- 6. Find duplicates

-- Use ROW_NUMBER function
-- Create CTE (cannot delete rows in CTE) 
With CTE_rownum as(
select *
	,row_number() over (
    partition by ParcelID,
    PropertyAddress,
    SalePrice,
    SaleDate,
    LegalReference
    order by
    UniqueID
    ) as row_num
from HousingData)
select * 
from CTE_rownum
	where row_num >1
;

-- --------------------------------------------------------------------------

-- 7. Remove duplicates from temporary table

create temporary table temp_rownum 
	select *
	,row_number() over (
    partition by ParcelID,
    PropertyAddress,
    SalePrice,
    SaleDate,
    LegalReference
    order by
    UniqueID
    ) as row_num
    from HousingData
    ;

Delete from temp_rownum
where row_num>1;

-- --------------------------------------------------------------------------

-- 8.Delete unused columns from temporary table

alter table temp_rownum
	drop column PropertyAddress;

alter table temp_rownum
	drop column OwnerAddress;

alter table temp_rownum
	drop column row_num;

-- --------------------------------------------------------------------------	

set sql_safe_updates = 1;