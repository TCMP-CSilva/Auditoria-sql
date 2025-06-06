USE Kustom
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_WARNINGS ON
GO
PRINT 'INI-CATALOGA SP: Kustom.dbo.PRC_DRV_CARTERA_SWP'
GO
IF  EXISTS (SELECT * FROM sysobjects WHERE id = OBJECT_ID(N'dbo.PRC_DRV_CARTERA_SWP') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
	DROP PROCEDURE dbo.PRC_DRV_CARTERA_SWP
    PRINT 'INI CREATE SP'
GO


CREATE PROCEDURE [dbo].[PRC_DRV_CARTERA_SWP] (	@FECHAEJECUCION			DATETIME = NULL 	)
AS
BEGIN
/*
Descripcion	: Open Report K+, informe contable cartera vigente de SWAP  
Autor		: Cristian Silva
Fecha		: 2019-07
Empresa		: TCM Partners
Ejecucion	: EXEC Kustom.dbo.PRC_DRV_CARTERA_SWP '20210804'
			  EXEC Kustom.dbo.PRC_OR_DRV_CARTERA_SWP '20210803'

Ejemplo		: 
Nota		: Se excluyen los acentos dentro de este documento.
******************************************************************************************************
Descripcion	: Modificacion Fecha Ejecucion a t-1
Autor		: Felipe Cabrera
Fecha		: 22-10-2019
Empresa		: TCM Partners
****************************************************************************************************** 
Descripcion	: Se agrega campo Variacion_anual_Rdo_MTM y se edita forma de obtener cuentas CC_Resultado y CC_MTM_Neto
Autor		: Felipe Cabrera
Fecha		: 27-05-2021
Empresa		: TCM Partners
******************************************************************************************************
Descripcion	: Se elimina los registros que correspondan a la fecha de proceso que ya esten cargados en la tabla 
Autor		: APS
Fecha		: 2022-11-12
Empresa		: SKB TI
******************************************************************************************************
Descripcion	: Se agrega TNA y TRA para Ejecucion del dia
Autor		: Jesus Espejo
Fecha		: 2022-11-17
Empresa		: TCM Partners
******************************************************************************************************
Descripcion	: Se incluyen los codigos para la reclasificacion contable de la cuenta del PNL, cuando un derivado pasa de ganancia a perdida y viceversa.
Autor		: TCM PARTNERS
Fecha		: 2022-08
Empresa		: TCM Partners
*/

/*Verificacion de fecha de ejecucion*/
SELECT @FECHAEJECUCION = isnull(@FECHAEJECUCION,Kustom.dbo.FUNC_GETDATE((SELECT Kustom.dbo.FUNC_UTIL_GETVALPARLOC('Chile','Regions_ShortName',0,null,'VCHAR1'))))
/* Verificacion de fecha de ejecucion FCABRERA 2019-10-22*/
SELECT @FECHAEJECUCION =  CONVERT(DATETIME,(SELECT Kustom.dbo.FUNC_UTIL_Get_DiaHabil (-1, 1, 'SAN', (SELECT CONVERT(VARCHAR(8),ISNULL(@FECHAEJECUCION,Kustom.dbo.FUNC_GETDATE((SELECT Kustom.dbo.FUNC_UTIL_GETVALPARLOC('Chile','Regions_ShortName',0,null,'VCHAR1')))) ,112)))))

DECLARE @FechaEjecucionAnt 	DATETIME,
		@CLP				INT,
		@FechaUltDiaAnoAnt	DATETIME

SELECT 	@FechaEjecucionAnt	= CONVERT(DATETIME,( SELECT Kustom.dbo.FUNC_UTIL_Get_DiaHabil (-1, 1,  'SAN', (SELECT CONVERT(VARCHAR(8),@FECHAEJECUCION,112))))),
		@CLP 				= (SELECT Currencies_Id from KplusLocal..Currencies where Currencies_ShortName = 'CLP'),
		@FechaUltDiaAnoAnt	=	Kustom.dbo.FUNC_UTIL_Get_DiaHabil (-1, 1, 'SAN', CONVERT(VARCHAR,CONVERT(DATE,CONCAT(YEAR(@FECHAEJECUCION)-1,12,31)),112))	

DECLARE @FECHAEJECUCION_HOY DATETIME
SELECT @FECHAEJECUCION_HOY = Kustom.dbo.FUNC_GETDATE((SELECT Kustom.dbo.FUNC_UTIL_GETVALPARLOC('Chile','Regions_ShortName',0,null,'VCHAR1')))

-- Obtenemos fecha ultimo RTK ano anterior
DECLARE @FECHA_ANTERIOR		DATETIME
SELECT	@FECHA_ANTERIOR	=	(SELECT MAX(Fecha) FROM Kustom.dbo.TBL_DRV_RPT_RTK_SW_PROD_HIST WHERE DATEDIFF(YEAR,DATEADD(YEAR,-1,@FECHAEJECUCION),Fecha) = 0)
-- Obtenemos ID moneda CLP
DECLARE @CLP_ID INT
SELECT @CLP_ID = Currencies_Id FROM KplusLocal..Currencies WHERE Currencies_ShortName='CLP'



/* Elimina los posibles registros que sean del mismo dia */
DELETE FROM Kustom.dbo.TBL_SWAP_CARTERA WHERE Fecha_Reporte = @FECHAEJECUCION

DECLARE @CARTERA TABLE (
Tipo_Ope						VARCHAR(30),
Tipo_Cartera					VARCHAR(30),
Oficina							VARCHAR(30),
Num_Ope							INT,
Relacionado						VARCHAR(10),
Rut								VARCHAR(15),
Nombre_Cliente					VARCHAR(100),
Fecha_Inicio_R1					VARCHAR(10),
Fecha_Vto_R1					VARCHAR(10),
Fecha_Inicio_R2					VARCHAR(10),
Fecha_Vto_R2					VARCHAR(10),
Tipo_Tasa_R						VARCHAR(30),
Tasa_R							FLOAT,
Dias_Dev_R						INT,
Moneda_R						VARCHAR(3),
Nominal_R						FLOAT,
Nominal_R_CLP					FLOAT,
Fecha_Inicio_P					VARCHAR(10),
Fecha_Vto_P						VARCHAR(10),
Tipo_Tasa_P						VARCHAR(30),
Tasa_P							FLOAT,
Dias_Dev_P						INT,
Moneda_P						VARCHAR(3),
Nominal_P						FLOAT,
Nominal_P_CLP					FLOAT,
Valor_Mercado_Activo			FLOAT,
Valor_Mercado_Activo_CLP		FLOAT,
Interes_Activo					FLOAT,
Interes_Activo_CLP				FLOAT,	
Valor_Mercado_Pasivo			FLOAT,
Valor_Mercado_Pasivo_CLP		FLOAT,
Interes_Pasivo					FLOAT,
Interes_Pasivo_CLP				FLOAT,
Valor_Mercado_Neto_Dia			FLOAT,
Valor_Mercado_Dia_Anterior		FLOAT,
Variacion_anual_Rdo_MTM			FLOAT, 
Ajuste_Mercado					FLOAT,
CC_Nocionales_Activo			VARCHAR(16),
CC_Nocionales_Pasivo			VARCHAR(16),
CC_MTM_Neto						VARCHAR(16),
CC_Resultado					VARCHAR(16),
CC_MTM_Activo					VARCHAR(16),
CC_Interes_Activo				VARCHAR(16),	
CC_MTM_Pasivo					VARCHAR(16),
CC_Interes_Pasivo				VARCHAR(16),
CC_Int_Result_Activo			VARCHAR(16),
CC_Int_Result_Pasivo			VARCHAR(16),
TypeOfInstr_ShortName			VARCHAR(16),
FloatingRates_Id_D				INT,
FloatingRates_Id_L				INT,
Folders_Id_Captured				INT,
Cpty_Id							INT,
FUNC_DRV_SWAP_Delivery_Mode		VARCHAR(1), 
Ccy_L							INT,
Ccy_D							INT,
MTM_Neto_HOY					FLOAT,
MTM_Neto_AYER					FLOAT,
TNA_L							FLOAT,
TRA_L							FLOAT,
TNA_D							FLOAT,
TRA_D							FLOAT
);

DECLARE @CPTY_OP_INTER TABLE(
Cpty_Id						INT,
CptyGrp_Id					INT,
CptyGrp_ShortName			VARCHAR(20),
CptyGrp_Name				VARCHAR(30));

DECLARE @MTM_SWP_HOY TABLE(
Deal_Id						INT,
MTM_L						FLOAT,
MTM_L_CLP					FLOAT,
MTM_D						FLOAT,
MTM_D_CLP					FLOAT,
MTM_CLP						FLOAT
);

DECLARE @MTM_SWP_AYER_NETO TABLE(
Deal_Id						INT,
NPV_Local_Cur				FLOAT);

DECLARE @INT_SWP TABLE(
SwapDeals_Id			INT,
Accrued					FLOAT,
Accrued_CLP				FLOAT,
ScheduleLeg				CHAR(1),
AccruedDays				INT,
TNA						FLOAT,
TRA						FLOAT);

DECLARE @INT_SWP_Neto	TABLE(
SwapDeals_Id			INT,
Accrued					FLOAT);

DECLARE   @CF  table (
SwapDeals_Id 	int, 
SwapLeg 		char(1),
StartDate		datetime,
EndDate			datetime
)

insert into @CF (SwapDeals_Id, SwapLeg, EndDate) --flujos Depo

select  SS.SwapDeals_Id, 
		SS.ScheduleLeg, 
		(select	min(EndDate) from KplusLocal..SwapSchedule SS1 where SS1.SwapDeals_Id = SS.SwapDeals_Id 
					and SS1.ScheduleLeg = 'D' and SS1.PeriodType ='P' and SS1.CashFlowType = 'I' 
					and SS1.EndDate > @FECHAEJECUCION)
from KplusLocal..SwapSchedule SS
inner join KplusLocal..SwapLeg SL on SL.SwapDeals_Id = SS.SwapDeals_Id and SL.LegType = SS.ScheduleLeg and SL.MaturityDate > @FECHAEJECUCION 
and SL.StartDate <= @FECHAEJECUCION
inner join KplusLocal..SwapDeals SD on SD.SwapDeals_Id = SL.SwapDeals_Id and SD.TypeOfEvent not in ('M', 'L')
where SS.CashFlowType = ('I') and SS.ScheduleLeg = 'D' --and SS.PeriodType = 'P'
and SS.EndDate > @FECHAEJECUCION and SS.StartDate <= @FECHAEJECUCION
and SS.SwapDeals_Id > 0 

insert into @CF (SwapDeals_Id, SwapLeg, EndDate) --Flujos Loan

select 	SS.SwapDeals_Id, 
		SS.ScheduleLeg, 
		(select	min(EndDate) from KplusLocal..SwapSchedule SS1 where SS1.SwapDeals_Id = SS.SwapDeals_Id 
					and SS1.ScheduleLeg = 'L' and SS1.PeriodType ='P' and SS1.CashFlowType = 'I' 
					and SS1.EndDate > @FECHAEJECUCION)
from KplusLocal..SwapSchedule SS
inner join KplusLocal..SwapLeg SL on SL.SwapDeals_Id = SS.SwapDeals_Id and SL.LegType = SS.ScheduleLeg 
--and SS.CashFlowType = ('I') and SS.ScheduleLeg = 'L' 
and SL.MaturityDate > @FECHAEJECUCION and SL.StartDate <= @FECHAEJECUCION
inner join KplusLocal..SwapDeals SD on SD.SwapDeals_Id = SL.SwapDeals_Id and SD.TypeOfEvent not in ('M', 'L')
where SS.CashFlowType = ('I') and SS.ScheduleLeg = 'L'  and SS.PeriodType != 'S'
and SS.EndDate > @FECHAEJECUCION and SS.StartDate <= @FECHAEJECUCION
and SS.SwapDeals_Id > 0

update @CF 
set StartDate = Case when SL.FixingFrequency != 'D'
						then  SS.StartDate 
						else 
							(select	max(EndDate) from KplusLocal..SwapSchedule SS1 where SS1.SwapDeals_Id = SS.SwapDeals_Id 
												and SS1.ScheduleLeg = cf1.SwapLeg and SS1.PeriodType ='P' and SS1.CashFlowType = 'I' 
												and SS1.EndDate <= @FECHAEJECUCION)
						 end
from @CF cf1 
inner join KplusLocal..SwapSchedule SS on SS.SwapDeals_Id = cf1.SwapDeals_Id and SS.EndDate = cf1.EndDate and SS.PeriodType = 'P'
and SS.CashFlowType = 'I' and cf1.SwapLeg = SS.ScheduleLeg
inner join KplusLocal..SwapLeg SL on SL.SwapDeals_Id = SS.SwapDeals_Id and SL.LegType = SS.ScheduleLeg
left JOIN KplusLocal..Pairs	LPAIR  ON SL.Pairs_Id_Principal = LPAIR.Pairs_Id

update @CF
set StartDate = SL.StartDate
from @CF cf
inner join KplusLocal..SwapLeg SL on SL.SwapDeals_Id = cf.SwapDeals_Id and SL.LegType = cf.SwapLeg
where cf.StartDate is NULL

/* Hacemos una tabla con la relaccion de Folders y carteras */ 
DECLARE  @temp_cartera TABLE
(
Folders_Id	INT NULL,
Cartera		VARCHAR(10) NULL,
Sucursal	VARCHAR(10) NULL
)
/* Folders pertenecientes al FolderGroup 'COBERTURAS' */
INSERT INTO @temp_cartera
SELECT	t2.Folders_Id
,t1.FoldersGrp_ShortName
,t4.Branches_ShortName
FROM	KplusLocal..FoldersGrp t1
INNER JOIN	KplusLocal..FoldersGrpFolders t2
ON	t1.FoldersGrp_Id = t2.FoldersGrp_Id
INNER JOIN	KplusLocal..Folders t5
ON	t2.Folders_Id = t5.Folders_Id 
INNER JOIN	KplusLocal..Portfolios t3
ON	t5.Portfolios_Id = t3.Portfolios_Id 
INNER JOIN	KplusLocal..Branches t4
ON	t3.Branches_Id = t4.Branches_Id
AND	t1.FoldersGrp_ShortName in ('VRAZONABLE', 'FLUJO_CAJA')
INSERT INTO @temp_cartera
SELECT	t5.Folders_Id
,t1.FoldersGrp_ShortName
,t4.Branches_ShortName
FROM	KplusLocal..FoldersGrp t1
INNER JOIN	KplusLocal..FoldersGrpPortfolios t2
ON	t1.FoldersGrp_Id = t2.FoldersGrp_Id
INNER JOIN	KplusLocal..Portfolios t3
ON	t2.Portfolios_Id = t3.Portfolios_Id
INNER JOIN	KplusLocal..Branches t4
ON	t3.Branches_Id = t4.Branches_Id
INNER JOIN	KplusLocal..Folders t5
ON	t3.Portfolios_Id = t5.Portfolios_Id
AND	t1.FoldersGrp_ShortName in ('VRAZONABLE', 'FLUJO_CAJA')
INSERT INTO @temp_cartera
SELECT	t5.Folders_Id
,t1.FoldersGrp_ShortName
,t4.Branches_ShortName
FROM	KplusLocal..FoldersGrp t1
INNER JOIN	KplusLocal..FoldersGrpBranches t2
ON	t1.FoldersGrp_Id=t2.FoldersGrp_Id
INNER JOIN	KplusLocal..Branches t4
ON	t2.Branches_Id = t4.Branches_Id
INNER JOIN	KplusLocal..Portfolios t3
ON	t4.Branches_Id = t3.Branches_Id
INNER JOIN	KplusLocal..Folders t5
ON	t3.Portfolios_Id = t5.Portfolios_Id
AND	t1.FoldersGrp_ShortName in ('VRAZONABLE', 'FLUJO_CAJA')

/* Borramos posibles duplicados */
DELETE @temp_cartera
WHERE	Folders_Id IN (	SELECT	Folders_Id
FROM	@temp_cartera
GROUP BY Folders_Id
HAVING COUNT(*) > 1 )

/* mtm ayer */
EXEC PRC_DRV_MTM_SWAP_CARTERA @FechaEjecucionAnt

INSERT INTO @MTM_SWP_AYER_NETO
SELECT 
SwapDeals_Id,
MTM_CLP																					
FROM	Kustom..TBL_MTM_SWAP_CARTERA
WHERE	DATEDIFF(DAY,Fecha_Reporte,  @FechaEjecucionAnt) = 0
 
/* mtm hoy */
EXEC PRC_DRV_MTM_SWAP_CARTERA @FECHAEJECUCION
 
INSERT INTO @MTM_SWP_HOY
SELECT	
SwapDeals_Id,
MTM_L,
MTM_L_CLP,
MTM_D,
MTM_D_CLP,
MTM_CLP																					
FROM	Kustom..TBL_MTM_SWAP_CARTERA
WHERE	DATEDIFF(DAY,Fecha_Reporte,  @FECHAEJECUCION) = 0



INSERT INTO @INT_SWP
SELECT 
SwapDeals_Id, 
Accrued,
(CASE cur.RoundingType
	WHEN 'R' THEN ROUND(Kustom.dbo.FUNC_GET_AMOUNT_CCY_DAY(Accrued, Currencies_Ppal_Id, 52033, @FECHAEJECUCION),cur.NoDecimal) 
	ELSE ROUND(Kustom.dbo.FUNC_GET_AMOUNT_CCY_DAY(Accrued, Currencies_Ppal_Id, 52033, @FECHAEJECUCION),cur.NoDecimal, 1 )
END),
SwapLeg,
0,
TNA,
TRA
FROM 		Kustom..TBL_DRV_SwapAccrued
INNER JOIN 	KplusLocal..Currencies cur
ON			Currencies_Ppal_Id = cur.Currencies_Id
WHERE	DATEDIFF(DAY,Fecha,  @FECHAEJECUCION) = 0


INSERT INTO @INT_SWP_Neto
SELECT 
	swp.SwapDeals_Id, 
	(SELECT (CASE C.RoundingType
                            WHEN 'R' THEN ROUND(ISNULL(SUM(swp.Accrued),0), C.NoDecimal) 
                            ELSE ROUND (ISNULL(SUM(swp.Accrued),0), C.NoDecimal, 1 )
			END)
    FROM    KplusLocal..Currencies 		C
    WHERE   C.Currencies_ShortName	=	'CLP')	
FROM @INT_SWP				swp 
GROUP BY swp.SwapDeals_Id


INSERT INTO @CPTY_OP_INTER 
SELECT	
	CptyGrpElt.Cpty_Id,
	CptyGrpDef.CptyGrp_Id,
	CptyGrpDef.CptyGrp_ShortName,
	CptyGrpDef.CptyGrp_Name
FROM		KplusLocal.dbo.CptyGrpElt	CptyGrpElt
INNER JOIN	KplusLocal.dbo.CptyGrpDef	CptyGrpDef
ON			CptyGrpDef.CptyGrp_Id	=	CptyGrpElt.CptyGrp_Id
WHERE		CptyGrpDef.CptyGrp_ShortName	=	'CPTY_INTER'


SELECT 
	DISTINCT  (swp.SwapDeals_Id) 'SwapDeals_Id'
INTO #Deals
FROM		KplusLocal..SwapDeals swp
INNER JOIN	KplusLocal.dbo.SwapLeg										legL
ON			swp.SwapDeals_Id										=	legL.SwapDeals_Id
AND			legL.LegType											= 	'L' 
INNER JOIN	KplusLocal.dbo.TypeOfInstr									TypeOfInstr
ON			legL.TypeOfInstr_Id										=	TypeOfInstr.TypeOfInstr_Id
INNER JOIN	KplusLocal.dbo.InstrumentGrpCoverage						InstrumentGrpCoverage
ON			TypeOfInstr.TypeOfInstr_Id								=	InstrumentGrpCoverage.TypeOfInstr_Id
INNER JOIN	KplusLocal.dbo.InstrumentGrp								InstrumentGrp
ON			InstrumentGrpCoverage.InstrumentGrp_Id					=	InstrumentGrp.InstrumentGrp_Id 
AND			InstrumentGrp.InstrumentGrp_ShortName					=	'OP_REALES'
INNER JOIN	KplusLocal.dbo.Cpty											Cpty
ON			legL.Cpty_Id											=	Cpty.Cpty_Id
INNER JOIN	Kustom.dbo.Cpty_Custom										Cpty_Custom
ON			Cpty.Cpty_Id											=	Cpty_Custom.DealId
LEFT JOIN	@CPTY_OP_INTER												CPTY_OP_INTER
ON			Cpty.Cpty_Id											=	CPTY_OP_INTER.Cpty_Id 
WHERE 
	swp.DealStatus = 'V' and
	swp.InputMode IN ('I', 'C')	and
	swp.TypeOfEvent	NOT IN	('L', 'M') 
	and	legL.MaturityDate > @FECHAEJECUCION 												
	AND CPTY_OP_INTER.Cpty_Id IS NULL
	


SELECT 
( CASE 	WHEN  ( TypeOfInstr.TypeOfInstr_ShortName = 'IRS' AND (LEFT(ISNULL(FloatingRates_D.DownloadKey,''),3) != 'OIS' AND LEFT(ISNULL(FloatingRates_L.DownloadKey,''),3) != 'OIS') )
			THEN 'SWP_TASA'
		WHEN  ( TypeOfInstr.TypeOfInstr_ShortName = 'CCS' AND (LEFT(ISNULL(FloatingRates_D.DownloadKey,''),3) != 'ICP' AND LEFT(ISNULL(FloatingRates_L.DownloadKey,''),3) != 'ICP') )
			THEN 'CC_SWP'
		WHEN  ( TypeOfInstr.TypeOfInstr_ShortName = 'ICP' )
			THEN 'SWP_PROM_CAMARA'
		WHEN  ( TypeOfInstr.TypeOfInstr_ShortName = 'IRS' AND (LEFT(ISNULL(FloatingRates_D.DownloadKey,''),3) = 'OIS'  OR LEFT(ISNULL(FloatingRates_L.DownloadKey,''),3) = 'OIS') )
			THEN 'SWP_OIS'
		WHEN  ( TypeOfInstr.TypeOfInstr_ShortName = 'CCS' AND (LEFT(ISNULL(FloatingRates_D.DownloadKey,''),3) = 'ICP'  OR LEFT(ISNULL(FloatingRates_L.DownloadKey,''),3) = 'ICP') )
			THEN 'CC_SWP_PROM_CAMARA'
END )																																								'Tipo_SWP',
(CASE WHEN (select Cartera from @temp_cartera where Folders_Id = SwapDeals.Folders_Id_Captured ) = 'FLUJO_CAJA'
										THEN 'FLUJO_CAJA'
									  WHEN (select Cartera from @temp_cartera where Folders_Id = SwapDeals.Folders_Id_Captured ) = 'VRAZONABLE'
										THEN 'VRAZONABLE'
										ELSE 'NEGOCIACION'
								 END)																																'Tipo_Cartera',
( SELECT TOP 1 FoldersGrp.FoldersGrp_ShortName
 FROM 		KplusLocal..Folders 				F
 INNER JOIN 	KplusLocal..Portfolios 				Portf
 ON 			F.Portfolios_Id 				=	Portf.Portfolios_Id
 INNER JOIN 	KplusLocal..Branches 				Branches
 ON 			Portf.Branches_Id 				= 	Branches.Branches_Id
 INNER JOIN 	KplusLocal..FoldersGrpBranches 		FoldersGrpBranches
 ON 			Branches.Branches_Id 			= 	FoldersGrpBranches.Branches_Id
 INNER JOIN 	KplusLocal..FoldersGrp 				FoldersGrp
 ON 			FoldersGrpBranches.FoldersGrp_Id = FoldersGrp.FoldersGrp_Id
 AND 		FoldersGrp.FoldersGrp_ShortName IN ('ALM', 'TRD')
 AND 		F.Folders_Id 					=	 SwapDeals.Folders_Id_Captured)	 																				'Oficina',							 
SwapDeals.SwapDeals_Id,
(SELECT 	(CASE 	WHEN Cpty_Custom.Cpty_Relacionado_SBC_Id = 3 and  C.IsResident = 'N'
					THEN 'NR_NR' 
				WHEN Cpty_Custom.Cpty_Relacionado_SBC_Id = 3 and  C.IsResident = 'Y'
					THEN 'NR'
				WHEN Cpty_Custom.Cpty_Relacionado_SBC_Id = 1 and  C.IsResident = 'Y'
					THEN 'R'
				WHEN Cpty_Custom.Cpty_Relacionado_SBC_Id = 2 and  C.IsResident = 'Y'
					THEN 'R'
				WHEN Cpty_Custom.Cpty_Relacionado_SBC_Id = 1 and  C.IsResident = 'N'
					THEN 'RE'
				WHEN Cpty_Custom.Cpty_Relacionado_SBC_Id = 2 and  C.IsResident = 'N'
					THEN 'RE'
END)
FROM kplustp..Cpty C
INNER JOIN Kustom..Cpty_Custom Cpty_Custom
ON	Cpty_Custom.DealId = C.Cpty_Id
AND C.Cpty_Id = SwapLeg_L.Cpty_Id)																																	'Relacionado',
Cpty_Custom.Rut																																						'Rut',
Cpty_Custom.Nombre_Largo,
CONVERT(VARCHAR(10),SwapDeals.TradeDate, 111)																														'TradeDate', 
CONVERT(VARCHAR(10),SwapLeg_L.MaturityDate, 111)																													'MaturityDate_L',
CONVERT(VARCHAR(10),(select top 1 StartDate from @CF where SwapDeals_Id=SwapDeals.SwapDeals_Id and SwapLeg = 'L' ), 111)											'StartDate_L', 
CONVERT(VARCHAR(10),(select top 1 EndDate   from @CF where SwapDeals_Id=SwapDeals.SwapDeals_Id and SwapLeg = 'L' ), 111)											'EndDate_L',
(CASE 
				WHEN 
					(SELECT FloatingRates_ShortName FROM KplusLocal..FloatingRates WHERE FloatingRates_Id = SwapLeg_L.FloatingRates_Id) = 'CLFSTSWOV' OR 
					(SELECT FloatingRates_ShortName FROM KplusLocal..FloatingRates WHERE FloatingRates_Id = SwapLeg_L.FloatingRates_Id) = 'CLPSTSWON' THEN 'ICP'	
				ELSE
				CASE
					WHEN SwapLeg_L.Indexation = 'F' THEN 'Fija'
					ELSE isnull((SELECT FloatingRates_ShortName FROM KplusLocal..FloatingRates WHERE FloatingRates_Id = SwapLeg_L.FloatingRates_Id),'')			
					END 
				END)																																				'Tipo_Tasa_L',	
(CASE 	WHEN SwapLeg_L.Indexation = 'F'
			THEN ROUND(SwapLeg_L.FixedRate,4)
		ELSE ROUND((SwapLeg_L.AdditiveMargin / 100),4) 
END)																																								'Tasa_L',														
DATEDIFF(DAY,CONVERT(VARCHAR(10),(select top 1 StartDate from @CF where SwapDeals_Id=SwapDeals.SwapDeals_Id and SwapLeg = 'L' ) , 111), @FECHAEJECUCION ) + 1 		'Dias_Dev_L',
(case	when SwapLeg_L.Pairs_Id_Principal = 0 
				then SwapLeg_L.Currencies_Id
		when PAIR_L.Currencies_Id_1 = SwapLeg_L.Currencies_Id 
				then PAIR_L.Currencies_Id_2
		else PAIR_L.Currencies_Id_1
end )																																								'Ccy_L',
(case	when SwapLeg_L.Pairs_Id_Principal = 0 
				then SwapSchedule_L.Principal
		when PAIR_L.Currencies_Id_1 = SwapLeg_L.Currencies_Id 
				then (SwapSchedule_L.Principal * SwapSchedule_L.PrincipalFXRate)
		else coalesce((SwapSchedule_L.Principal / NULLIF(SwapSchedule_L.PrincipalFXRate,0)),0)
end )																																								'Principal_L',
CONVERT(VARCHAR(10),(select top 1 StartDate from @CF where SwapDeals_Id=SwapDeals.SwapDeals_Id and SwapLeg = 'D' ), 111)											'StartDate_D', 
CONVERT(VARCHAR(10),(select top 1 EndDate   from @CF where SwapDeals_Id=SwapDeals.SwapDeals_Id and SwapLeg = 'D' ), 111)											'EndDate_D',
(CASE 
				WHEN 
					(SELECT FloatingRates_ShortName FROM KplusLocal..FloatingRates WHERE FloatingRates_Id = SwapLeg_D.FloatingRates_Id) = 'CLFSTSWOV' OR 
					(SELECT FloatingRates_ShortName FROM KplusLocal..FloatingRates WHERE FloatingRates_Id = SwapLeg_D.FloatingRates_Id) = 'CLPSTSWON' THEN 'ICP'	
				ELSE
				CASE
					WHEN SwapLeg_D.Indexation = 'F' THEN 'Fija'
					ELSE isnull((SELECT FloatingRates_ShortName FROM KplusLocal..FloatingRates WHERE FloatingRates_Id = SwapLeg_D.FloatingRates_Id),'')			
					END 
				END)																																				'Tipo_Tasa_D',
(CASE 	WHEN SwapLeg_D.Indexation = 'F'
			THEN ROUND(SwapLeg_D.FixedRate,4)
		ELSE ROUND((SwapLeg_D.AdditiveMargin / 100),4) 
END)																																								'Tasa_D',	
DATEDIFF(DAY,CONVERT(VARCHAR(10), (select top 1 StartDate from @CF where SwapDeals_Id=SwapDeals.SwapDeals_Id ), 111), @FECHAEJECUCION ) + 1 																						'Dias_Dev_D',
(case	when SwapLeg_D.Pairs_Id_Principal = 0 then SwapLeg_D.Currencies_Id
		when PAIR_D.Currencies_Id_1 = SwapLeg_D.Currencies_Id then PAIR_D.Currencies_Id_2
		else PAIR_D.Currencies_Id_1
end )																																								'Ccy_D',
(case	when SwapLeg_D.Pairs_Id_Principal = 0 
				then SwapSchedule_D.Principal
		when PAIR_D.Currencies_Id_1 = SwapLeg_D.Currencies_Id 
				then (SwapSchedule_D.Principal * SwapSchedule_D.PrincipalFXRate)
		else coalesce((SwapSchedule_D.Principal / NULLIF(SwapSchedule_D.PrincipalFXRate,0)),0)
end )																																								'Principal_D',
TypeOfInstr.TypeOfInstr_ShortName																																	'TypeOfInstr_ShortName',			
SwapLeg_D.FloatingRates_Id																																			'FloatingRates_Id_D',
SwapLeg_L.FloatingRates_Id																																			'FloatingRates_Id_L',
SwapDeals.Folders_Id_Captured																																		'Folders_Id_Captured',
SwapLeg_L.Cpty_Id																																					'Cpty_Id',							
--Kustom.dbo.FUNC_DRV_SWAP_Delivery_Mode(SwapDeals.SwapDeals_Id)																									'Delivery_Mode',
Kustom.dbo.FUNC_DRV_SWAP_Delivery_Mode(SwapDeals.SwapDeals_Id)																										'FUNC_DRV_SWAP_Delivery_Mode',
ISNULL((SELECT top 1 Accrued FROM @INT_SWP WHERE SwapDeals_Id = SwapDeals.SwapDeals_Id AND ScheduleLeg = 'L'),0)															'Interes_L',
ISNULL((SELECT top 1 Accrued_CLP FROM @INT_SWP WHERE SwapDeals_Id = SwapDeals.SwapDeals_Id AND ScheduleLeg = 'L'),0)														'Interes_L_CLP',
ISNULL((SELECT top 1 Accrued FROM @INT_SWP WHERE SwapDeals_Id = SwapDeals.SwapDeals_Id AND ScheduleLeg = 'D'),0)															'Interes_D',
ISNULL((SELECT top 1 Accrued_CLP FROM @INT_SWP WHERE SwapDeals_Id = SwapDeals.SwapDeals_Id AND ScheduleLeg = 'D'),0)														'Interes_D_CLP',
ISNULL((SELECT top 1 Accrued FROM @INT_SWP_Neto WHERE SwapDeals_Id = SwapDeals.SwapDeals_Id ),0)																			'Interes_NETO',
( ISNULL((SELECT MTM_L FROM @MTM_SWP_HOY WHERE Deal_Id = SwapDeals.SwapDeals_Id ),0))																				'MTM_L',
( ISNULL((SELECT MTM_L_CLP FROM @MTM_SWP_HOY WHERE Deal_Id = SwapDeals.SwapDeals_Id ),0))																			'MTM_L_CLP',
( ISNULL((SELECT MTM_D FROM @MTM_SWP_HOY WHERE Deal_Id = SwapDeals.SwapDeals_Id ),0))																				'MTM_D',
( ISNULL((SELECT MTM_D_CLP FROM @MTM_SWP_HOY WHERE Deal_Id = SwapDeals.SwapDeals_Id ),0))																			'MTM_D_CLP',
ISNULL((SELECT MTM_CLP FROM @MTM_SWP_HOY WHERE Deal_Id = SwapDeals.SwapDeals_Id) ,0)																				'MTM_Neto_HOY',
ISNULL((SELECT NPV_Local_Cur FROM @MTM_SWP_AYER_NETO WHERE Deal_Id = SwapDeals.SwapDeals_Id) ,0)																	'MTM_Neto_AYER',
ISNULL((SELECT top 1 TNA FROM @INT_SWP WHERE SwapDeals_Id = SwapDeals.SwapDeals_Id AND ScheduleLeg = 'L'),0)														'TNA_L',
ISNULL((SELECT top 1 TRA FROM @INT_SWP WHERE SwapDeals_Id = SwapDeals.SwapDeals_Id AND ScheduleLeg = 'L'),0)														'TRA_L',
ISNULL((SELECT top 1 TNA FROM @INT_SWP WHERE SwapDeals_Id = SwapDeals.SwapDeals_Id AND ScheduleLeg = 'D'),0)														'TNA_D',
ISNULL((SELECT top 1 TRA FROM @INT_SWP WHERE SwapDeals_Id = SwapDeals.SwapDeals_Id AND ScheduleLeg = 'D'),0)														'TRA_D'

 INTO #U_SWP
FROM		KplusLocal..SwapDeals						SwapDeals
INNER JOIN	KplusLocal..SwapLeg							SwapLeg_L
ON			SwapDeals.SwapDeals_Id					= 	SwapLeg_L.SwapDeals_Id
and			SwapDeals.SwapDeals_Id IN (SELECT SwapDeals_Id FROM #Deals)
AND			SwapLeg_L.LegType						= 	'L' 
INNER JOIN	KplusLocal..SwapLeg							SwapLeg_D
ON			SwapDeals.SwapDeals_Id					= 	SwapLeg_D.SwapDeals_Id
AND			SwapLeg_D.LegType						= 	'D' 
AND			SwapDeals.TypeOfEvent				NOT IN	('L', 'M')
AND			SwapDeals.DealStatus					IN 	('V')
AND			SwapDeals.InputMode						<> 	'G'
INNER JOIN	KplusLocal..SwapSchedule					SwapSchedule_L
ON			SwapDeals.SwapDeals_Id					= 	SwapSchedule_L.SwapDeals_Id
AND			SwapSchedule_L.ScheduleLeg				= 	'L' 
AND			SwapLeg_L.Cpty_Id						<> 	0
AND			SwapSchedule_L.StartDate				<= 	@FECHAEJECUCION
AND			SwapSchedule_L.EndDate					> 	@FECHAEJECUCION
AND			SwapSchedule_L.PeriodType not in  ('S', 'B')
AND			SwapSchedule_L.CashFlowType				IN	('I')
INNER JOIN	KplusLocal..SwapSchedule					SwapSchedule_D
ON			SwapDeals.SwapDeals_Id					= 	SwapSchedule_D.SwapDeals_Id
AND			SwapSchedule_D.ScheduleLeg				= 	'D'
AND			SwapSchedule_D.StartDate				<= 	@FECHAEJECUCION
AND			SwapSchedule_D.EndDate					> 	@FECHAEJECUCION
AND			SwapSchedule_D.PeriodType not in  ('S', 'B')
AND			SwapSchedule_D.CashFlowType				IN 	('I')
LEFT JOIN	KplusLocal..Pairs							PAIR_D
ON			SwapLeg_D.Pairs_Id_Principal			=	PAIR_D.Pairs_Id
LEFT JOIN	KplusLocal..Pairs							PAIR_L
ON			SwapLeg_L.Pairs_Id_Principal			=	PAIR_L.Pairs_Id
INNER JOIN	Kustom..Cpty_Custom							Cpty_Custom
ON			SwapLeg_D.Cpty_Id						= 	Cpty_Custom.DealId
INNER JOIN	KplusLocal..Folders							Folders
ON			SwapLeg_L.Folders_Id					= 	Folders.Folders_Id
INNER JOIN	KplusLocal..Portfolios						Portfolios    
ON			Folders.Portfolios_Id					= 	Portfolios.Portfolios_Id
INNER JOIN	KplusLocal..Branches						Branches 
ON			Portfolios.Branches_Id					= 	Branches.Branches_Id
INNER JOIN	KplusLocal..HierarchyEntities				HE
ON			Branches.HierarchyEntities_Id			= 	HE.HierarchyEntities_Id
AND			HE.HierarchyEntities_Name				= 	(SELECT Kustom.dbo.FUNC_UTIL_GETVALPARLOC('Chile','HierarchyEntities_Name',0,null,'VCHAR1'))
INNER JOIN	KplusLocal.dbo.TypeOfInstr					TypeOfInstr
ON			SwapLeg_L.TypeOfInstr_Id				= 	TypeOfInstr.TypeOfInstr_Id
INNER JOIN	KplusLocal.dbo.InstrumentGrpCoverage		InstrumentGrpCoverage
ON			TypeOfInstr.TypeOfInstr_Id				= 	InstrumentGrpCoverage.TypeOfInstr_Id
INNER JOIN	KplusLocal.dbo.InstrumentGrp				InstrumentGrp
ON			InstrumentGrpCoverage.InstrumentGrp_Id	= 	InstrumentGrp.InstrumentGrp_Id
AND			InstrumentGrp.InstrumentGrp_ShortName	= 	'OP_REALES'
LEFT JOIN	kplustp..FloatingRates						FloatingRates_D
ON			SwapLeg_D.FloatingRates_Id				=	FloatingRates_D.FloatingRates_Id
LEFT JOIN	kplustp..FloatingRates						FloatingRates_L
ON			SwapLeg_L.FloatingRates_Id				=	FloatingRates_L.FloatingRates_Id
LEFT JOIN	@CPTY_OP_INTER								CPTY_OP_INTER
ON			SwapLeg_D.Cpty_Id						=	CPTY_OP_INTER.Cpty_Id
WHERE 		CPTY_OP_INTER.Cpty_Id IS NULL
ORDER BY	SwapDeals.SwapDeals_Id


 DROP TABLE #Deals

--select * from #U_SWP

SELECT  
( CASE 	WHEN  ( TypeOfInstr.TypeOfInstr_ShortName = 'IRS' AND (LEFT(ISNULL(FloatingRates_D.DownloadKey,''),3) != 'OIS' AND LEFT(ISNULL(FloatingRates_L.DownloadKey,''),3) != 'OIS') )
			THEN 'SWP_TASA'
		WHEN  ( TypeOfInstr.TypeOfInstr_ShortName = 'CCS' AND (LEFT(ISNULL(FloatingRates_D.DownloadKey,''),3) != 'ICP' AND LEFT(ISNULL(FloatingRates_L.DownloadKey,''),3) != 'ICP') )
			THEN 'CC_SWP'
		WHEN  ( TypeOfInstr.TypeOfInstr_ShortName = 'ICP' )
			THEN 'SWP_PROM_CAMARA'
		WHEN  ( TypeOfInstr.TypeOfInstr_ShortName = 'IRS' AND (LEFT(ISNULL(FloatingRates_D.DownloadKey,''),3) = 'OIS'  OR LEFT(ISNULL(FloatingRates_L.DownloadKey,''),3) = 'OIS') )
			THEN 'SWP_OIS'
		WHEN  ( TypeOfInstr.TypeOfInstr_ShortName = 'CCS' AND (LEFT(ISNULL(FloatingRates_D.DownloadKey,''),3) = 'ICP'  OR LEFT(ISNULL(FloatingRates_L.DownloadKey,''),3) = 'ICP') )
			THEN 'CC_SWP_PROM_CAMARA'
END )																																								'Tipo_SWP',
(CASE WHEN (select Cartera from @temp_cartera where Folders_Id = SwapDeals.Folders_Id_Captured ) = 'FLUJO_CAJA'
										THEN 'FLUJO_CAJA'
									  WHEN (select Cartera from @temp_cartera where Folders_Id = SwapDeals.Folders_Id_Captured ) = 'VRAZONABLE'
										THEN 'VRAZONABLE'
										ELSE 'NEGOCIACION'
								 END)																																'Tipo_Cartera',
( SELECT TOP 1 FoldersGrp.FoldersGrp_ShortName
 FROM 		KplusLocal..Folders 				F
 INNER JOIN 	KplusLocal..Portfolios 				Portf
 ON 			F.Portfolios_Id 				=	Portf.Portfolios_Id
 INNER JOIN 	KplusLocal..Branches 				Branches
 ON 			Portf.Branches_Id 				= 	Branches.Branches_Id
 INNER JOIN 	KplusLocal..FoldersGrpBranches 		FoldersGrpBranches
 ON 			Branches.Branches_Id 			= 	FoldersGrpBranches.Branches_Id
 INNER JOIN 	KplusLocal..FoldersGrp 				FoldersGrp
 ON 			FoldersGrpBranches.FoldersGrp_Id = FoldersGrp.FoldersGrp_Id
 AND 		FoldersGrp.FoldersGrp_ShortName IN ('ALM', 'TRD')
 AND 		F.Folders_Id 					=	 SwapDeals.Folders_Id_Captured)	 																					'Oficina',							 
SwapDeals.SwapDeals_Id,
(SELECT 	(CASE 	WHEN Cpty_Custom.Cpty_Relacionado_SBC_Id = 3 and  C.IsResident = 'N'
					THEN 'NR_NR' 
				WHEN Cpty_Custom.Cpty_Relacionado_SBC_Id = 3 and  C.IsResident = 'Y'
					THEN 'NR'
				WHEN Cpty_Custom.Cpty_Relacionado_SBC_Id = 1 and  C.IsResident = 'Y'
					THEN 'R'
				WHEN Cpty_Custom.Cpty_Relacionado_SBC_Id = 2 and  C.IsResident = 'Y'
					THEN 'R'
				WHEN Cpty_Custom.Cpty_Relacionado_SBC_Id = 1 and  C.IsResident = 'N'
					THEN 'RE'
				WHEN Cpty_Custom.Cpty_Relacionado_SBC_Id = 2 and  C.IsResident = 'N'
					THEN 'RE'
END)
FROM kplustp..Cpty C
INNER JOIN Kustom..Cpty_Custom Cpty_Custom
ON	Cpty_Custom.DealId = C.Cpty_Id
AND C.Cpty_Id = SwapLeg_L.Cpty_Id)																																	'Relacionado',
Cpty_Custom.Rut																																						'Rut',
Cpty_Custom.Nombre_Largo,
CONVERT(VARCHAR(10),SwapDeals.TradeDate, 111)																														'TradeDate', 
CONVERT(VARCHAR(10),SwapLeg_L.MaturityDate, 111)																													'MaturityDate_L',
CONVERT(VARCHAR(10),'Starting')																																		'StartDate_L', 
CONVERT(VARCHAR(10),'Starting')																																		'EndDate_L',
(CASE 
				WHEN 
					(SELECT FloatingRates_ShortName FROM KplusLocal..FloatingRates WHERE FloatingRates_Id = SwapLeg_L.FloatingRates_Id) = 'CLFSTSWOV' OR 
					(SELECT FloatingRates_ShortName FROM KplusLocal..FloatingRates WHERE FloatingRates_Id = SwapLeg_L.FloatingRates_Id) = 'CLPSTSWON' THEN 'ICP'	
				ELSE
				CASE
					WHEN SwapLeg_L.Indexation = 'F' THEN 'Fija'
					ELSE isnull((SELECT FloatingRates_ShortName FROM KplusLocal..FloatingRates WHERE FloatingRates_Id = SwapLeg_L.FloatingRates_Id),'')			
					END 
				END)																																				'Tipo_Tasa_L',		
(CASE 	WHEN SwapLeg_L.Indexation = 'F'
			THEN ROUND(SwapLeg_L.FixedRate,4)
		ELSE ROUND((SwapLeg_L.AdditiveMargin / 100),4) 
END)																																								'Tasa_L',														
0 																																									'Dias_Dev_L',
(case	when SwapLeg_L.Pairs_Id_Principal = 0 
				then SwapLeg_L.Currencies_Id
		when PAIR_L.Currencies_Id_1 = SwapLeg_L.Currencies_Id 
				then PAIR_L.Currencies_Id_2
		else PAIR_L.Currencies_Id_1
end )																																								'Ccy_L',
/*(case	when SwapLeg_L.Pairs_Id_Principal = 0 
				then SwapLeg_L.PrincipalAmount
		when PAIR_L.Currencies_Id_1 = SwapLeg_L.Currencies_Id 
				then (SwapLeg_L.PrincipalAmount * SwapLeg_L.PrincipalFXRate)
		else+ coalesce((SwapLeg_L.PrincipalAmount / NULLIF(SwapLeg_L.PrincipalFXRate,0)),0)
end )*/
SwapLeg_L.PrincipalAmount																																								'Principal_L',
CONVERT(VARCHAR(10),'Starting')																																		'StartDate_D', 
CONVERT(VARCHAR(10),'Starting')																																		'EndDate_D',
(CASE 
				WHEN 
					(SELECT FloatingRates_ShortName FROM KplusLocal..FloatingRates WHERE FloatingRates_Id = SwapLeg_D.FloatingRates_Id) = 'CLFSTSWOV' OR 
					(SELECT FloatingRates_ShortName FROM KplusLocal..FloatingRates WHERE FloatingRates_Id = SwapLeg_D.FloatingRates_Id) = 'CLPSTSWON' THEN 'ICP'	
				ELSE
				CASE
					WHEN SwapLeg_D.Indexation = 'F' THEN 'Fija'
					ELSE isnull((SELECT FloatingRates_ShortName FROM KplusLocal..FloatingRates WHERE FloatingRates_Id = SwapLeg_D.FloatingRates_Id),'')			
					END 
				END)																																				'Tipo_Tasa_D',	
(CASE 	WHEN SwapLeg_D.Indexation = 'F'
			THEN ROUND(SwapLeg_D.FixedRate,4)
		ELSE ROUND((SwapLeg_D.AdditiveMargin / 100),4) 
END)																																								'Tasa_D',	
0																																									'Dias_Dev_D',
(case	when SwapLeg_D.Pairs_Id_Principal = 0 then SwapLeg_D.Currencies_Id
		when PAIR_D.Currencies_Id_1 = SwapLeg_D.Currencies_Id then PAIR_D.Currencies_Id_2
		else PAIR_D.Currencies_Id_1
end )																																								'Ccy_D',
/*(case	when SwapLeg_D.Pairs_Id_Principal = 0 
				then SwapLeg_D.PrincipalAmount
		when PAIR_D.Currencies_Id_1 = SwapLeg_D.Currencies_Id 
				then (SwapLeg_D.PrincipalAmount * SwapLeg_D.PrincipalFXRate)
		else coalesce((SwapLeg_D.PrincipalAmount / NULLIF(SwapLeg_D.PrincipalFXRate,0)),0)
end )		*/
SwapLeg_D.PrincipalAmount																																						'Principal_D',
TypeOfInstr.TypeOfInstr_ShortName																																	'TypeOfInstr_ShortName',			
SwapLeg_D.FloatingRates_Id																																			'FloatingRates_Id_D',
SwapLeg_L.FloatingRates_Id																																			'FloatingRates_Id_L',
SwapDeals.Folders_Id_Captured																																		'Folders_Id_Captured',
SwapLeg_L.Cpty_Id																																					'Cpty_Id',							
Kustom.dbo.FUNC_DRV_SWAP_Delivery_Mode(SwapDeals.SwapDeals_Id)																										'FUNC_DRV_SWAP_Delivery_Mode',
ISNULL((SELECT Accrued FROM @INT_SWP WHERE SwapDeals_Id = SwapDeals.SwapDeals_Id AND ScheduleLeg = 'L'),0)															'Interes_L',
ISNULL((SELECT Accrued_CLP FROM @INT_SWP WHERE SwapDeals_Id = SwapDeals.SwapDeals_Id AND ScheduleLeg = 'L'),0)														'Interes_L_CLP',
ISNULL((SELECT Accrued FROM @INT_SWP WHERE SwapDeals_Id = SwapDeals.SwapDeals_Id AND ScheduleLeg = 'D'),0)															'Interes_D',
ISNULL((SELECT Accrued_CLP FROM @INT_SWP WHERE SwapDeals_Id = SwapDeals.SwapDeals_Id AND ScheduleLeg = 'D'),0)														'Interes_D_CLP',
ISNULL((SELECT Accrued FROM @INT_SWP_Neto WHERE SwapDeals_Id = SwapDeals.SwapDeals_Id ),0)																			'Interes_NETO',
( ISNULL((SELECT MTM_L FROM @MTM_SWP_HOY WHERE Deal_Id = SwapDeals.SwapDeals_Id ),0))																				'MTM_L',
( ISNULL((SELECT MTM_L_CLP FROM @MTM_SWP_HOY WHERE Deal_Id = SwapDeals.SwapDeals_Id ),0))																			'MTM_L_CLP',
( ISNULL((SELECT MTM_D FROM @MTM_SWP_HOY WHERE Deal_Id = SwapDeals.SwapDeals_Id ),0))																				'MTM_D',
( ISNULL((SELECT MTM_D_CLP FROM @MTM_SWP_HOY WHERE Deal_Id = SwapDeals.SwapDeals_Id ),0))																			'MTM_D_CLP',
ISNULL((SELECT MTM_CLP FROM @MTM_SWP_HOY WHERE Deal_Id = SwapDeals.SwapDeals_Id) ,0)																				'MTM_Neto_HOY',
ISNULL((SELECT NPV_Local_Cur FROM @MTM_SWP_AYER_NETO WHERE Deal_Id = SwapDeals.SwapDeals_Id) ,0)																	'MTM_Neto_AYER',
ISNULL((SELECT top 1 TNA FROM @INT_SWP WHERE SwapDeals_Id = SwapDeals.SwapDeals_Id AND ScheduleLeg = 'L'),0)														'TNA_L',
ISNULL((SELECT top 1 TRA FROM @INT_SWP WHERE SwapDeals_Id = SwapDeals.SwapDeals_Id AND ScheduleLeg = 'L'),0)														'TRA_L',
ISNULL((SELECT top 1 TNA FROM @INT_SWP WHERE SwapDeals_Id = SwapDeals.SwapDeals_Id AND ScheduleLeg = 'D'),0)														'TNA_D',
ISNULL((SELECT top 1 TRA FROM @INT_SWP WHERE SwapDeals_Id = SwapDeals.SwapDeals_Id AND ScheduleLeg = 'D'),0)														'TRA_D'
 INTO #U_SWP_Starting
FROM		KplusLocal..SwapDeals						SwapDeals
INNER JOIN	KplusLocal..SwapLeg							SwapLeg_L
ON			SwapDeals.SwapDeals_Id					= 	SwapLeg_L.SwapDeals_Id
AND			SwapLeg_L.LegType						= 	'L' 
INNER JOIN	KplusLocal..SwapLeg							SwapLeg_D
ON			SwapDeals.SwapDeals_Id					= 	SwapLeg_D.SwapDeals_Id
AND			SwapLeg_D.LegType						= 	'D'
AND			SwapDeals.SwapDeals_Id				NOT IN	(SELECT SwapDeals_Id FROM #U_SWP)
AND			SwapDeals.TypeOfEvent				NOT IN	('L', 'M')
AND			SwapDeals.DealStatus					IN 	('V')
AND			SwapDeals.InputMode						<> 	'G'
--AND			DATEDIFF(day,SwapDeals.TradeDate,    @FECHAEJECUCION) >=  0
AND		  ( DATEDIFF(day,SwapLeg_L.MaturityDate, @FECHAEJECUCION) <  0 OR DATEDIFF(day,SwapLeg_D.MaturityDate, @FECHAEJECUCION) <  0 )
INNER JOIN	KplusLocal.dbo.TypeOfInstr					TypeOfInstr
ON			SwapLeg_L.TypeOfInstr_Id				= 	TypeOfInstr.TypeOfInstr_Id
INNER JOIN	KplusLocal.dbo.InstrumentGrpCoverage		InstrumentGrpCoverage
ON			TypeOfInstr.TypeOfInstr_Id				= 	InstrumentGrpCoverage.TypeOfInstr_Id
INNER JOIN	KplusLocal.dbo.InstrumentGrp				InstrumentGrp
ON			InstrumentGrpCoverage.InstrumentGrp_Id	= 	InstrumentGrp.InstrumentGrp_Id
AND			InstrumentGrp.InstrumentGrp_ShortName	= 	'OP_REALES'
LEFT JOIN	KplusLocal..Pairs							PAIR_D
ON			SwapLeg_D.Pairs_Id_Principal			=	PAIR_D.Pairs_Id
LEFT JOIN	KplusLocal..Pairs							PAIR_L
ON			SwapLeg_L.Pairs_Id_Principal			=	PAIR_L.Pairs_Id
INNER JOIN	Kustom..Cpty_Custom							Cpty_Custom
ON			SwapLeg_D.Cpty_Id						= 	Cpty_Custom.DealId
INNER JOIN	KplusLocal..Folders							Folders
ON			SwapLeg_L.Folders_Id					= 	Folders.Folders_Id
INNER JOIN	KplusLocal..Portfolios						Portfolios    
ON			Folders.Portfolios_Id					= 	Portfolios.Portfolios_Id
INNER JOIN	KplusLocal..Branches						Branches 
ON			Portfolios.Branches_Id					= 	Branches.Branches_Id
INNER JOIN	KplusLocal..HierarchyEntities				HE
ON			Branches.HierarchyEntities_Id			= 	HE.HierarchyEntities_Id
AND			HE.HierarchyEntities_Name				= 	(SELECT Kustom.dbo.FUNC_UTIL_GETVALPARLOC('Chile','HierarchyEntities_Name',0,null,'VCHAR1'))
LEFT JOIN	kplustp..FloatingRates						FloatingRates_D
ON			SwapLeg_D.FloatingRates_Id				=	FloatingRates_D.FloatingRates_Id
LEFT JOIN	kplustp..FloatingRates						FloatingRates_L
ON			SwapLeg_L.FloatingRates_Id				=	FloatingRates_L.FloatingRates_Id
LEFT JOIN	@CPTY_OP_INTER								CPTY_OP_INTER
ON			SwapLeg_D.Cpty_Id						=	CPTY_OP_INTER.Cpty_Id
WHERE 		CPTY_OP_INTER.Cpty_Id IS NULL


INSERT INTO @CARTERA
SELECT 
'Tipo_Ope'					=	Tipo_SWP,
'Tipo_Cartera'				=	Tipo_Cartera,
'Oficina'					=	Oficina,
'Num_Ope'					=	SwapDeals_Id,
'Relacionado'				=	Relacionado,
'Rut'						=	Rut,
'Nombre_Cliente'			=	Nombre_Largo,
'Fecha_Inicio_R1'			=	TradeDate,
'Fecha_Vto_R1'				=	MaturityDate_L,
'Fecha_Inicio_R2'			=	StartDate_L, 
'Fecha_Vto_R2'				=	EndDate_L,
'Tipo_Tasa_R'				=	Tipo_Tasa_L,
'Tasa_R'					=	Tasa_L,																											 
'Dias_Dev_L'				=	Dias_Dev_L,
'Moneda_R'					=	( SELECT Currencies_ShortName FROM KplusLocal..Currencies WHERE Currencies_Id = Ccy_L ),
'Nominal_R'					=	ROUND(Principal_L,Cur_L.NoDecimal),
'Nominal_R_CLP'				=	ROUND(Kustom.dbo.FUNC_GET_AMOUNT_CCY_DAY(Principal_L, Ccy_L, @CLP, @FECHAEJECUCION),0),
'Fecha_Inicio_P'			=	StartDate_D, 
'Fecha_Vto_P'				=	EndDate_D,
'Tipo_Tasa_D'				=	Tipo_Tasa_D,	
'Tasa_P'					=	Tasa_D,	
'Dias_Dev_D'				=	Dias_Dev_D,
'Moneda_P'					=	( SELECT Currencies_ShortName FROM KplusLocal..Currencies WHERE Currencies_Id = Ccy_D ),
'Nominal_P'					=	ROUND(Principal_D,Cur_D.NoDecimal),
'Nominal_P_CLP'				=	ROUND(Kustom.dbo.FUNC_GET_AMOUNT_CCY_DAY(Principal_D, Ccy_D, @CLP, @FECHAEJECUCION),0),
'Valor_Mercado_Activo'		=	ROUND(ISNULL(MTM_L ,0) - (case when Ccy_L = 52101 then ISNULL(Interes_L_CLP,0) else ISNULL(Interes_L,0) end ),Cur_L.NoDecimal),
'Valor_Mercado_Activo_CLP'	=	ROUND(ISNULL(MTM_L_CLP,0) - ISNULL(Interes_L_CLP,0),0),
'Interes_Activo'			=	ROUND(Interes_L, Cur_L.NoDecimal),
'Interes_Activo_CLP'		=	ROUND(ISNULL(Interes_L_CLP ,0),0), 
'Valor_Mercado_Pasivo'		=	ROUND(ISNULL(MTM_D,0) - (case when Ccy_D = 52101 then ISNULL(Interes_D_CLP,0) else ISNULL(Interes_D,0) end ),Cur_D.NoDecimal),
'Valor_Mercado_Pasivo_CLP'	=	ROUND(ISNULL(MTM_D_CLP,0) - ISNULL(Interes_D_CLP,0),0),
'Interes_Pasivo'			=	ROUND(Interes_D, Cur_D.NoDecimal),
'Interes_Pasivo_CLP'		=	ROUND(ISNULL(Interes_D_CLP,0),0), 
'Valor_Mercado_Neto_Dia'	=	ISNULL(MTM_Neto_HOY, 0),
'Valor_Mercado_Dia_Anterior'=	ISNULL(MTM_Neto_AYER, 0),
'Variacion_anual_Rdo_MTM'	=	NULL,
'Ajuste_Mercado'			=	ISNULL(MTM_Neto_AYER - MTM_Neto_HOY, 0),
'CC_Nocionales_Activo'		=	Kustom.dbo.FUNC_KP_SWP_Acc(	TypeOfInstr_ShortName,
															FloatingRates_Id_D,
															FloatingRates_Id_L,
															Folders_Id_Captured,
															Cpty_Id,													
															FUNC_DRV_SWAP_Delivery_Mode, 
															Ccy_L,
															Ccy_D,
															'Act_Nocional_98'),
'CC_Nocionales_Pasivo'		=	Kustom.dbo.FUNC_KP_SWP_Acc(	TypeOfInstr_ShortName,
															FloatingRates_Id_D,
															FloatingRates_Id_L,
															Folders_Id_Captured,
															Cpty_Id,														
															FUNC_DRV_SWAP_Delivery_Mode, 
															Ccy_L,
															Ccy_D,
															'Pas_Nocional_98'),
'CC_MTM_Neto'				=	Kustom.dbo.FUNC_KP_SWP_Acc(	TypeOfInstr_ShortName,
															FloatingRates_Id_D,
															FloatingRates_Id_L,
															Folders_Id_Captured,
															Cpty_Id,														
															FUNC_DRV_SWAP_Delivery_Mode, 
															Ccy_L,
															Ccy_D,
															(CASE WHEN ISNULL(MTM_Neto_HOY, 0)  > 0
																			THEN 'Balance Activo_DB'
																			ELSE 'Balance Pasivo_CR'
																	END) 
																),
'CC_Resultado'				=	Kustom.dbo.FUNC_KP_SWP_Acc(	TypeOfInstr_ShortName,
															FloatingRates_Id_D,
															FloatingRates_Id_L,
															Folders_Id_Captured,
															Cpty_Id,
															FUNC_DRV_SWAP_Delivery_Mode, 
															Ccy_L,
															Ccy_D,
															(CASE 
																	 WHEN (ISNULL(MTM_Neto_HOY, 0) > 0) AND ((ISNULL(MTM_Neto_HOY, 0) - ISNULL(MTM_Neto_AYER, 0)) < 0)
																	 THEN 'Act Perdida_MtM_DB'
																	 WHEN (ISNULL(MTM_Neto_HOY, 0) < 0) AND ((ISNULL(MTM_Neto_HOY, 0) - ISNULL(MTM_Neto_AYER, 0)) <= 0)
																	 THEN 'Pas Perdida_MtM_DB'
																	 WHEN (ISNULL(MTM_Neto_HOY, 0) > 0) AND ((ISNULL(MTM_Neto_HOY, 0) - ISNULL(MTM_Neto_AYER, 0)) >= 0)
																	 THEN 'Act Ganancia_MtM_CR'
																	 WHEN (ISNULL(MTM_Neto_HOY, 0) < 0) AND ((ISNULL(MTM_Neto_HOY, 0) - ISNULL(MTM_Neto_AYER, 0)) > 0)
																	 THEN 'Pas Ganancia_MtM_CR'
																	END)
																	),
'CC_MTM_Activo'				=	Kustom.dbo.FUNC_KP_SWP_Acc(	TypeOfInstr_ShortName,
															FloatingRates_Id_D,
															FloatingRates_Id_L,
															Folders_Id_Captured,
															Cpty_Id,														
															FUNC_DRV_SWAP_Delivery_Mode, 
															Ccy_L,
															Ccy_D,
															'Act_Vr_Mcdo_98'),
'CC_Interes_Activo'			=	Kustom.dbo.FUNC_KP_SWP_Acc(	TypeOfInstr_ShortName,
															FloatingRates_Id_D,
															FloatingRates_Id_L,
															Folders_Id_Captured,
															Cpty_Id,														
															FUNC_DRV_SWAP_Delivery_Mode, 
															Ccy_L,
															Ccy_D,
															'Act_Interes'),
'CC_MTM_Pasivo'				=	Kustom.dbo.FUNC_KP_SWP_Acc(	TypeOfInstr_ShortName,
															FloatingRates_Id_D,
															FloatingRates_Id_L,
															Folders_Id_Captured,
															Cpty_Id,													
															FUNC_DRV_SWAP_Delivery_Mode, 
															Ccy_L,
															Ccy_D,
															'Pas_Vr_Mcdo_98'),
'CC_Interes_Pasivo'			=	Kustom.dbo.FUNC_KP_SWP_Acc(	TypeOfInstr_ShortName,
															FloatingRates_Id_D,
															FloatingRates_Id_L,
															Folders_Id_Captured,
															Cpty_Id,														
															FUNC_DRV_SWAP_Delivery_Mode, 
															Ccy_L,
															Ccy_D,
															'Pas_Interes'),
'CC_Int_Result_Activo'		=	Kustom.dbo.FUNC_KP_SWP_Acc(	TypeOfInstr_ShortName,
															FloatingRates_Id_D,
															FloatingRates_Id_L,
															Folders_Id_Captured,
															Cpty_Id,														
															FUNC_DRV_SWAP_Delivery_Mode, 
															Ccy_L,
															Ccy_D,
															'Int_LOAN_CR'),
'CC_Int_Result_Pasivo'		=	Kustom.dbo.FUNC_KP_SWP_Acc(	TypeOfInstr_ShortName,
															FloatingRates_Id_D,
															FloatingRates_Id_L,
															Folders_Id_Captured,
															Cpty_Id,														
															FUNC_DRV_SWAP_Delivery_Mode, 
															Ccy_L,
															Ccy_D,
															'Int_DEPO_DB'),
TypeOfInstr_ShortName,
FloatingRates_Id_D,
FloatingRates_Id_L,
Folders_Id_Captured,
Cpty_Id,
FUNC_DRV_SWAP_Delivery_Mode, 
Ccy_L,
Ccy_D,
MTM_Neto_HOY,
MTM_Neto_AYER,
TNA_L,
TRA_L,
TNA_D,
TRA_D
FROM 		#U_SWP
INNER JOIN 	KplusLocal..Currencies Cur_L
ON			Ccy_L = Cur_L.Currencies_Id
INNER JOIN 	KplusLocal..Currencies Cur_D
ON			Ccy_D = Cur_D.Currencies_Id

INSERT INTO @CARTERA
SELECT 
'Tipo_Ope'							=	Tipo_SWP,
'Tipo_Cartera'						=	Tipo_Cartera,
'Oficina'							=	Oficina,
'Num_Ope'							=	SwapDeals_Id,
'Relacionado'						=	Relacionado,
'Rut'								=	Rut,
'Nombre_Cliente'					=	Nombre_Largo,
'Fecha_Inicio_R1'					=	TradeDate,
'Fecha_Vto_R1'						=	MaturityDate_L,
'Fecha_Inicio_R2'					=	StartDate_L, 
'Fecha_Vto_R2'						=	EndDate_L,
'Tipo_Tasa_R'						=	Tipo_Tasa_L,
'Tasa_R'							=	Tasa_L,																											 
'Dias_Dev_L'						=	Dias_Dev_L,
'Moneda_R'							=	( SELECT Currencies_ShortName FROM KplusLocal..Currencies WHERE Currencies_Id = Ccy_L ),
'Nominal_R'							=	ROUND(Principal_L,Cur_L.NoDecimal),
'Nominal_R_CLP'						=	ROUND(Kustom.dbo.FUNC_GET_AMOUNT_CCY_DAY(Principal_L, Ccy_L, @CLP, @FECHAEJECUCION),0),
'Fecha_Inicio_P'					=	StartDate_D, 
'Fecha_Vto_P'						=	EndDate_D,
'Tipo_Tasa_P'						=	Tipo_Tasa_D,
'Tasa_P'							=	Tasa_D,	
'Dias_Dev_D'						=	Dias_Dev_D,
'Moneda_P'							=	( SELECT Currencies_ShortName FROM KplusLocal..Currencies WHERE Currencies_Id = Ccy_D ),
'Nominal_P'							=	ROUND(Principal_D,Cur_D.NoDecimal),
'Nominal_P_CLP'						=	ROUND(Kustom.dbo.FUNC_GET_AMOUNT_CCY_DAY(Principal_D, Ccy_D, @CLP, @FECHAEJECUCION),0),
'Valor_Mercado_Activo'				=	ROUND(ISNULL(MTM_L ,0) - (case when Ccy_L = 52101 then ISNULL(Interes_L_CLP,0) else ISNULL(Interes_L,0) end ),Cur_L.NoDecimal),
'Valor_Mercado_Activo_CLP'			=	ROUND(ISNULL(MTM_L_CLP,0) - ISNULL(Interes_L_CLP,0),0),
'Interes_Activo'					=	ROUND(Interes_L, Cur_L.NoDecimal),
'Interes_Activo_CLP'				=	ROUND(ISNULL(Interes_L_CLP ,0),0), 
'Valor_Mercado_Pasivo'				=	ROUND(ISNULL(MTM_D,0) - (case when Ccy_D = 52101 then ISNULL(Interes_D_CLP,0) else ISNULL(Interes_D,0) end ),Cur_D.NoDecimal),
'Valor_Mercado_Pasivo_CLP'			=	ROUND(ISNULL(MTM_D_CLP,0) - ISNULL(Interes_D_CLP,0),0),
'Interes_Pasivo'					=	ROUND(Interes_D, Cur_D.NoDecimal),
'Interes_Pasivo_CLP'				=	ROUND(ISNULL(Interes_D_CLP,0),0), 
'Valor_Mercado_Neto_Dia'			=	ISNULL(MTM_Neto_HOY, 0),
'Valor_Mercado_Dia_Anterior'		=	ISNULL(MTM_Neto_AYER, 0),
'Variacion_anual_Rdo_MTM'			=	NULL,
'Ajuste_Mercado'					=	ISNULL(MTM_Neto_AYER - MTM_Neto_HOY, 0),
'CC_Nocionales_Activo'				=	Kustom.dbo.FUNC_KP_SWP_Acc(	TypeOfInstr_ShortName,
																	FloatingRates_Id_D,
																	FloatingRates_Id_L,
																	Folders_Id_Captured,
																	Cpty_Id,													
																	FUNC_DRV_SWAP_Delivery_Mode, 
																	Ccy_L,
																	Ccy_D,
																	'Act_Nocional_98'),
'CC_Nocionales_Pasivo'				=	Kustom.dbo.FUNC_KP_SWP_Acc(	TypeOfInstr_ShortName,
																	FloatingRates_Id_D,
																	FloatingRates_Id_L,
																	Folders_Id_Captured,
																	Cpty_Id,														
																	FUNC_DRV_SWAP_Delivery_Mode, 
																	Ccy_L,
																	Ccy_D,
																	'Pas_Nocional_98'),
/* CAMBIA CRITERIA FC */
'CC_MTM_Neto'						=	Kustom.dbo.FUNC_KP_SWP_Acc(	TypeOfInstr_ShortName,
																	FloatingRates_Id_D,
																	FloatingRates_Id_L,
																	Folders_Id_Captured,
																	Cpty_Id,														
																	FUNC_DRV_SWAP_Delivery_Mode, 
																	Ccy_L,
																	Ccy_D,
																	(CASE WHEN ISNULL(MTM_Neto_HOY, 0)  > 0
																			THEN 'Balance Activo_DB'
																			ELSE 'Balance Pasivo_CR'
																	END)
																),
/* CAMBIA CRITERIA Y LOGICA */
'CC_Resultado'						=	'',
--Kustom.dbo.FUNC_KP_SWP_Acc(	TypeOfInstr_ShortName,
--																	FloatingRates_Id_D,
--																	FloatingRates_Id_L,
--																	Folders_Id_Captured,
--																	Cpty_Id,													
--																	FUNC_DRV_SWAP_Delivery_Mode, 
--																	Ccy_L,
--																	Ccy_D,
--																	(CASE 
--																	 WHEN (ISNULL(MTM_Neto_HOY, 0) >= 0) AND ((ISNULL(MTM_Neto_HOY, 0) - ISNULL(MTM_Neto_AYER, 0)) < 0)
--																	 THEN 'Act Perdida_MtM_DB'
--																	 WHEN (ISNULL(MTM_Neto_HOY, 0) < 0) AND ((ISNULL(MTM_Neto_HOY, 0) - ISNULL(MTM_Neto_AYER, 0)) < 0)
--																	 THEN 'Pas Perdida_MtM_DB'
--																	 WHEN (ISNULL(MTM_Neto_HOY, 0) >= 0) AND ((ISNULL(MTM_Neto_HOY, 0) - ISNULL(MTM_Neto_AYER, 0)) >= 0)
--																	 THEN 'Act Ganancia_MtM_CR'
--																	 WHEN (ISNULL(MTM_Neto_HOY, 0) < 0) AND ((ISNULL(MTM_Neto_HOY, 0) - ISNULL(MTM_Neto_AYER, 0)) >= 0)
--																	 THEN 'Pas Ganancia_MtM_CR'
--																	END)
--																	),
'CC_MTM_Activo'						=	Kustom.dbo.FUNC_KP_SWP_Acc(	TypeOfInstr_ShortName,
																	FloatingRates_Id_D,
																	FloatingRates_Id_L,
																	Folders_Id_Captured,
																	Cpty_Id,														
																	FUNC_DRV_SWAP_Delivery_Mode, 
																	Ccy_L,
																	Ccy_D,
																	'Act_Vr_Mcdo_98'),
'CC_Interes_Activo'					=	Kustom.dbo.FUNC_KP_SWP_Acc(	TypeOfInstr_ShortName,
																	FloatingRates_Id_D,
																	FloatingRates_Id_L,
																	Folders_Id_Captured,
																	Cpty_Id,														
																	FUNC_DRV_SWAP_Delivery_Mode, 
																	Ccy_L,
																	Ccy_D,
																	'Act_Interes'),
'CC_MTM_Pasivo'						=	Kustom.dbo.FUNC_KP_SWP_Acc(	TypeOfInstr_ShortName,
																	FloatingRates_Id_D,
																	FloatingRates_Id_L,
																	Folders_Id_Captured,
																	Cpty_Id,													
																	FUNC_DRV_SWAP_Delivery_Mode, 
																	Ccy_L,
																	Ccy_D,
																	'Pas_Vr_Mcdo_98'),
'CC_Interes_Pasivo'					=	Kustom.dbo.FUNC_KP_SWP_Acc(	TypeOfInstr_ShortName,
																	FloatingRates_Id_D,
																	FloatingRates_Id_L,
																	Folders_Id_Captured,
																	Cpty_Id,														
																	FUNC_DRV_SWAP_Delivery_Mode, 
																	Ccy_L,
																	Ccy_D,
																	'Pas_Interes'),
'CC_Int_Result_Activo'				=	Kustom.dbo.FUNC_KP_SWP_Acc(	TypeOfInstr_ShortName,
																	FloatingRates_Id_D,
																	FloatingRates_Id_L,
																	Folders_Id_Captured,
																	Cpty_Id,														
																	FUNC_DRV_SWAP_Delivery_Mode, 
																	Ccy_L,
																	Ccy_D,
																	'Int_DEPO_DB'),
'CC_Int_Result_Pasivo'				=	Kustom.dbo.FUNC_KP_SWP_Acc(	TypeOfInstr_ShortName,
																	FloatingRates_Id_D,
																	FloatingRates_Id_L,
																	Folders_Id_Captured,
																	Cpty_Id,														
																	FUNC_DRV_SWAP_Delivery_Mode, 
																	Ccy_L,
																	Ccy_D,
																	'Int_DEPO_DB'),
TypeOfInstr_ShortName,
FloatingRates_Id_D,
FloatingRates_Id_L,
Folders_Id_Captured,
Cpty_Id,
FUNC_DRV_SWAP_Delivery_Mode, 
Ccy_L,
Ccy_D,
MTM_Neto_HOY,
MTM_Neto_AYER,
TNA_L,
TRA_L,
TNA_D,
TRA_D															
FROM 		#U_SWP_Starting
INNER JOIN 	KplusLocal..Currencies Cur_L
ON			Ccy_L = Cur_L.Currencies_Id
INNER JOIN 	KplusLocal..Currencies Cur_D
ON			Ccy_D = Cur_D.Currencies_Id

/* Elimina los posibles registros que sean del mismo dia */

IF @FECHAEJECUCION IN (SELECT Fecha_Reporte FROM Kustom.dbo.TBL_SWAP_CARTERA)
BEGIN

-- tabla de calculo
DECLARE @TBL_MTM_SWAP_1 TABLE(
	SwapDeals_Id			INT			NULL
	,TradeDate				DATETIME	NULL
	,Valor_Mercado_Neto_Dia	FLOAT		NULL
	,Valor_Mercado_Anterior	FLOAT		NULL
	,Variacion				FLOAT		NULL
	,Tipo					INT			NULL
	,INDEX	IdX1			(SwapDeals_Id)
)

INSERT INTO @TBL_MTM_SWAP_1
SELECT		 'SwapDeals_Id'				=	Num_Ope
			,'TradeDate'				=	Fecha_Inicio_R1
			,'Valor_Mercado_Neto_Dia'	=	Valor_Mercado_Neto_Dia
			,'Valor_Mercado_Anterior'	=	0
			,'Variacion'				=	0
			,'Tipo'						=	(CASE
											 WHEN DATEDIFF(YEAR,@FECHAEJECUCION,Fecha_Inicio_R1) < 0
											 THEN 1
											 ELSE 2
											 END)
FROM		Kustom.dbo.TBL_SWAP_CARTERA
WHERE		DATEDIFF(DAY,Fecha_Reporte,@FECHAEJECUCION) = 0


SELECT		 CDC.Currencies_Id													'CDC'
			,CP.Currencies_Id													'CP'
			,CONCAT(CDC.Currencies_ShortName,'/',CP.Currencies_ShortName)		'Pair_ShortName'
			INTO #Pairs_1
FROM		Kustom.dbo.TBL_DRV_RPT_RTK_SW_PROD_HIST								RTK
INNER JOIN	KplusLocal.dbo.Currencies											CP
ON			CP.Currencies_ShortName											=	RTK.StaticData_PrincipalCurrencySh
AND			RTK.Fecha														=	@FechaUltDiaAnoAnt
AND			RTK.SwapDeals_SwapDeals_Id										>	0
AND			RTK.SwapLegCurrent_LegType										=	'Loan'
INNER JOIN	KplusLocal.dbo.Currencies											CDC
ON			CDC.Currencies_ShortName										=	RTK.DealData_CurrencyShortName
GROUP BY	CDC.Currencies_Id
			,CP.Currencies_Id
			,CDC.Currencies_ShortName
			,CP.Currencies_ShortName
			
			

INSERT INTO #Pairs_1
SELECT		CDC.Currencies_Id												--'CDC'
			,CP.Currencies_Id												--'CP'
			,CONCAT(CDC.Currencies_ShortName,'/',CP.Currencies_ShortName)	--'Pair_ShortName'
FROM		Kustom.dbo.TBL_DRV_RPT_RTK_SW_PROD_HIST								RTK
INNER JOIN	KplusLocal.dbo.Currencies											CP
ON			CP.Currencies_ShortName											=	RTK.StaticData_PrincipalCurrencySh
AND			RTK.Fecha														=	@FechaUltDiaAnoAnt
AND			RTK.SwapDeals_SwapDeals_Id										>	0
AND			RTK.SwapLegCurrent_LegType										=	'Deposit'
INNER JOIN	KplusLocal.dbo.Currencies											CDC
ON			CDC.Currencies_ShortName										=	RTK.DealData_CurrencyShortName
AND			CONCAT(CDC.Currencies_ShortName,'/',CP.Currencies_ShortName)	NOT IN (SELECT Pair_ShortName FROM #Pairs_1)
GROUP BY	CDC.Currencies_Id
			,CP.Currencies_Id
			,CDC.Currencies_ShortName
			,CP.Currencies_ShortName
		

INSERT INTO #Pairs_1
SELECT		 CDC.Currencies_Id												--'CDC'
			,@CLP_ID														--'CP'
			,CONCAT(CDC.Currencies_ShortName,'/CLP')						--'Pair_ShortName'			
FROM		Kustom.dbo.TBL_DRV_RPT_RTK_SW_PROD_HIST		RTK
INNER JOIN	KplusLocal.dbo.Currencies					CDC
ON			CDC.Currencies_ShortName				=	RTK.DealData_CurrencyShortName
AND			RTK.Fecha								=	@FechaUltDiaAnoAnt
AND			RTK.SwapDeals_SwapDeals_Id				>	0
AND			CONCAT(CDC.Currencies_ShortName,'/CLP') NOT IN (SELECT Pair_ShortName FROM #Pairs_1)
GROUP BY	CDC.Currencies_Id
			,CDC.Currencies_ShortName
			
	
SELECT		Pair_ShortName														'Pair_ShortName'
			,Kustom.dbo.FUNC_GET_AMOUNT_CCY_DAY(1, CDC, CP, @FechaUltDiaAnoAnt)	'Tipo_Cambio'
			INTO #Pairs_1_TC
FROM		#Pairs_1 
ORDER BY	1	DESC

SELECT		RTK.SwapDeals_SwapDeals_Id					'SwapDeals_Id'
			,SUM(RTK.RawPLData_Npv * TC.Tipo_Cambio)	'RawPLData_Npv_CLP'
			,0											'NoDecimal'
			,'R'										'RoundingType'
			INTO #CLP_1
FROM		Kustom.dbo.TBL_DRV_RPT_RTK_SW_PROD_HIST		RTK
INNER JOIN	@TBL_MTM_SWAP_1								MTM
ON			RTK.SwapDeals_SwapDeals_Id				=	MTM.SwapDeals_Id
AND			RTK.Fecha								=	@FechaUltDiaAnoAnt
AND			RTK.SwapDeals_SwapDeals_Id				>	0
AND			MTM.Tipo								=	1
INNER JOIN	KplusLocal.dbo.Currencies					CDC
ON			CDC.Currencies_ShortName				=	RTK.DealData_CurrencyShortName
INNER JOIN	#Pairs_1_TC									TC
ON			CONCAT(CDC.Currencies_ShortName,'/CLP')	=	TC.Pair_ShortName
GROUP BY	RTK.SwapDeals_SwapDeals_Id

UPDATE		MTM
SET			MTM.Valor_Mercado_Anterior	=	(CASE A.RoundingType
											 WHEN 'R'
											 THEN ROUND(A.RawPLData_Npv_CLP,A.NoDecimal) 
											 ELSE ROUND(A.RawPLData_Npv_CLP,A.NoDecimal, 1 )
											 END)
FROM 		@TBL_MTM_SWAP_1					MTM
INNER JOIN	#CLP_1							A
ON			MTM.SwapDeals_Id			=	A.SwapDeals_Id
AND			MTM.Tipo					=	1

DROP TABLE #Pairs_1
DROP TABLE #Pairs_1_TC
DROP TABLE #CLP_1

--Operaciones del mismo ano (Tipo 2)

SELECT		CDC.Currencies_Id												'CDC'
			,CP.Currencies_Id												'CP'
			,CONCAT(CDC.Currencies_ShortName,'/',CP.Currencies_ShortName)	'Pair_ShortName'
			INTO #Pairs_12
FROM		Kustom.dbo.TBL_DRV_RPT_RTK_SW_PROD_HIST								RTK
INNER JOIN	@TBL_MTM_SWAP_1														MTM
ON			RTK.SwapDeals_SwapDeals_Id										=	MTM.SwapDeals_Id
AND			MTM.Tipo														=	2
AND			RTK.Fecha														= (SELECT MIN(Fecha) FROM Kustom.dbo.TBL_DRV_RPT_RTK_FXO_RM_HIST WHERE DATEDIFF(DAY,@FechaUltDiaAnoAnt,Fecha) >= 0 AND SwapDeals_SwapDeals_Id = RTK.SwapDeals_SwapDeals_Id)
AND			RTK.SwapDeals_SwapDeals_Id										>	0
AND			RTK.SwapLegCurrent_LegType										=	'Loan'
INNER JOIN	KplusLocal.dbo.Currencies											CP
ON			CP.Currencies_ShortName											=	RTK.StaticData_PrincipalCurrencySh
INNER JOIN	KplusLocal.dbo.Currencies											CDC
ON			CDC.Currencies_ShortName										=	RTK.DealData_CurrencyShortName
GROUP BY	CDC.Currencies_Id
			,CP.Currencies_Id
			,CDC.Currencies_ShortName
			,CP.Currencies_ShortName

INSERT INTO #Pairs_12
SELECT		CDC.Currencies_Id												--'CDC'
			,CP.Currencies_Id												--'CP'
			,CONCAT(CDC.Currencies_ShortName,'/',CP.Currencies_ShortName)	--'Pair_ShortName'
FROM		Kustom.dbo.TBL_DRV_RPT_RTK_SW_PROD_HIST								RTK
INNER JOIN	@TBL_MTM_SWAP_1														MTM
ON			RTK.SwapDeals_SwapDeals_Id										=	MTM.SwapDeals_Id
AND			MTM.Tipo														=	2
AND			RTK.Fecha														= (SELECT MIN(Fecha) FROM Kustom.dbo.TBL_DRV_RPT_RTK_FXO_RM_HIST WHERE DATEDIFF(DAY,@FechaUltDiaAnoAnt,Fecha) >= 0 AND SwapDeals_SwapDeals_Id = RTK.SwapDeals_SwapDeals_Id)
AND			RTK.SwapDeals_SwapDeals_Id										>	0
AND			RTK.SwapLegCurrent_LegType										=	'Deposit'
INNER JOIN	KplusLocal.dbo.Currencies											CP
ON			CP.Currencies_ShortName											=	RTK.StaticData_PrincipalCurrencySh
INNER JOIN	KplusLocal.dbo.Currencies											CDC
ON			CDC.Currencies_ShortName										=	RTK.DealData_CurrencyShortName
AND			CONCAT(CDC.Currencies_ShortName,'/',CP.Currencies_ShortName)	NOT IN (SELECT Pair_ShortName FROM #Pairs_12)
GROUP BY	CDC.Currencies_Id
			,CP.Currencies_Id
			,CDC.Currencies_ShortName
			,CP.Currencies_ShortName

INSERT INTO #Pairs_12
SELECT		CDC.Currencies_Id												--'CDC'
			,@CLP_ID														--'CP'
			,CONCAT(CDC.Currencies_ShortName,'/CLP')						--'Pair_ShortName'			
FROM		Kustom.dbo.TBL_DRV_RPT_RTK_SW_PROD_HIST		RTK
INNER JOIN	@TBL_MTM_SWAP_1								MTM
ON			RTK.SwapDeals_SwapDeals_Id				=	MTM.SwapDeals_Id
AND			MTM.Tipo								=	2
AND			RTK.Fecha														= (SELECT MIN(Fecha) FROM Kustom.dbo.TBL_DRV_RPT_RTK_FXO_RM_HIST WHERE DATEDIFF(DAY,@FechaUltDiaAnoAnt,Fecha) >= 0 AND SwapDeals_SwapDeals_Id = RTK.SwapDeals_SwapDeals_Id)
INNER JOIN	KplusLocal.dbo.Currencies					CDC
ON			CDC.Currencies_ShortName				=	RTK.DealData_CurrencyShortName
AND			CONCAT(CDC.Currencies_ShortName,'/CLP') NOT IN (SELECT Pair_ShortName FROM #Pairs_12)
GROUP BY	CDC.Currencies_Id
			,CDC.Currencies_ShortName

SELECT		Pair_ShortName														'Pair_ShortName'
			,Kustom.dbo.FUNC_GET_AMOUNT_CCY_DAY(1, CDC, CP, @FECHA_ANTERIOR)	'Tipo_Cambio'
			INTO #Pairs_1_TC2
FROM		#Pairs_12 
ORDER BY	1	DESC


SELECT		RTK.SwapDeals_SwapDeals_Id					'SwapDeals_Id'
			,SUM(RTK.RawPLData_Npv * TC.Tipo_Cambio)	'RawPLData_Npv_CLP'
			,0											'NoDecimal'
			,'R'										'RoundingType'
			INTO #CLP_12
FROM		@TBL_MTM_SWAP_1								MTM
INNER JOIN	Kustom.dbo.TBL_DRV_RPT_RTK_SW_PROD_HIST		RTK
ON			RTK.SwapDeals_SwapDeals_Id				=	MTM.SwapDeals_Id
AND			RTK.Fecha								= (SELECT MIN(Fecha) FROM Kustom.dbo.TBL_DRV_RPT_RTK_FXO_RM_HIST WHERE DATEDIFF(DAY,@FechaUltDiaAnoAnt,Fecha) >= 0 AND SwapDeals_SwapDeals_Id = RTK.SwapDeals_SwapDeals_Id)
AND			RTK.SwapDeals_SwapDeals_Id				>	0
AND			MTM.Tipo								=	2
INNER JOIN	KplusLocal.dbo.Currencies					CDC
ON			CDC.Currencies_ShortName				=	RTK.DealData_CurrencyShortName
INNER JOIN	#Pairs_1_TC2									TC
ON			CONCAT(CDC.Currencies_ShortName,'/CLP')	=	TC.Pair_ShortName
GROUP BY	RTK.SwapDeals_SwapDeals_Id


UPDATE		MTM
SET			MTM.Valor_Mercado_Anterior	=	(CASE A.RoundingType
											 WHEN 'R'
											 THEN ROUND(A.RawPLData_Npv_CLP,A.NoDecimal) 
											 ELSE ROUND(A.RawPLData_Npv_CLP,A.NoDecimal, 1 )
											 END)
FROM 		@TBL_MTM_SWAP_1					MTM
INNER JOIN	#CLP_12							A
ON			MTM.SwapDeals_Id			=	A.SwapDeals_Id
AND			MTM.Tipo					=	2

DROP TABLE #Pairs_12
DROP TABLE #Pairs_1_TC2
DROP TABLE #CLP_12

UPDATE		@TBL_MTM_SWAP_1
SET			Variacion		=	Valor_Mercado_Neto_Dia - Valor_Mercado_Anterior
--WHERE		Tipo			=	1

UPDATE		C
SET			C.Variacion_anual_Rdo_MTM	=	MTM.Variacion
FROM		Kustom.dbo.TBL_SWAP_CARTERA						C
INNER JOIN	@TBL_MTM_SWAP_1					MTM
ON			C.Num_Ope					=	MTM.SwapDeals_Id
WHERE		DATEDIFF(DAY,Fecha_Reporte,@FECHAEJECUCION) = 0

--SELECT *
--FROM		Kustom.dbo.TBL_SWAP_CARTERA
--WHERE		DATEDIFF(DAY,Fecha_Reporte,@FECHAEJECUCION) = 0

--SELECT * FROM @CARTERA
UPDATE		C
SET			C.CC_Resultado = Kustom.dbo.FUNC_KP_SWP_Acc(	CAR.TypeOfInstr_ShortName,
															CAR.FloatingRates_Id_D,
															CAR.FloatingRates_Id_L,
															CAR.Folders_Id_Captured,
															CAR.Cpty_Id,
															CAR.FUNC_DRV_SWAP_Delivery_Mode, 
															CAR.Ccy_L,
															CAR.Ccy_D,
															(CASE 
															 WHEN (ISNULL(C.Valor_Mercado_Neto_Dia, 0) > 0) AND (ISNULL(C.Variacion_anual_Rdo_MTM,0) < 0)
															 THEN 'Act Perdida_MtM_DB'
															 WHEN (ISNULL(C.Valor_Mercado_Neto_Dia, 0) < 0) AND (ISNULL(C.Variacion_anual_Rdo_MTM,0) <= 0)
															 THEN 'Pas Perdida_MtM_DB'
															 WHEN (ISNULL(C.Valor_Mercado_Neto_Dia, 0) > 0) AND (ISNULL(C.Variacion_anual_Rdo_MTM,0) >= 0)
															 THEN 'Act Ganancia_MtM_CR'
															 WHEN (ISNULL(C.Valor_Mercado_Neto_Dia, 0) < 0) AND (ISNULL(C.Variacion_anual_Rdo_MTM,0) > 0)
															 THEN 'Pas Ganancia_MtM_CR'
															END)
															)
FROM		Kustom.dbo.TBL_SWAP_CARTERA C
INNER JOIN	@CARTERA CAR
ON			CAR.Num_Ope = C.Num_Ope
WHERE		DATEDIFF(DAY,C.Fecha_Reporte,@FECHAEJECUCION) = 0
END

ELSE

BEGIN 
DELETE FROM Kustom.dbo.TBL_SWAP_CARTERA WHERE Fecha_Reporte = @FECHAEJECUCION

-- tabla de calculo
DECLARE @TBL_MTM_SWAP TABLE(
	SwapDeals_Id			INT			NULL
	,TradeDate				DATETIME	NULL
	,Valor_Mercado_Neto_Dia	FLOAT		NULL
	,Valor_Mercado_Anterior	FLOAT		NULL
	,Variacion				FLOAT		NULL
	,Tipo					INT			NULL
	,INDEX	IdX1			(SwapDeals_Id)
)

INSERT INTO @TBL_MTM_SWAP
SELECT		'SwapDeals_Id'				=	Num_Ope
			,'TradeDate'				=	Fecha_Inicio_R1
			,'Valor_Mercado_Neto_Dia'	=	Valor_Mercado_Neto_Dia
			,'Valor_Mercado_Anterior'	=	0
			,'Variacion'				=	0
			,'Tipo'						=	(CASE
											 WHEN DATEDIFF(YEAR,@FECHAEJECUCION,Fecha_Inicio_R1) < 0
											 THEN 1
											 ELSE 2
											 END)
FROM		@CARTERA

SELECT		CDC.Currencies_Id													'CDC'
			,CP.Currencies_Id													'CP'
			,CONCAT(CDC.Currencies_ShortName,'/',CP.Currencies_ShortName)		'Pair_ShortName'
			INTO #Pairs
FROM		Kustom.dbo.TBL_DRV_RPT_RTK_SW_PROD_HIST								RTK
INNER JOIN	KplusLocal.dbo.Currencies											CP
ON			CP.Currencies_ShortName											=	RTK.StaticData_PrincipalCurrencySh
AND			RTK.Fecha														=	@FechaUltDiaAnoAnt
AND			RTK.SwapDeals_SwapDeals_Id										>	0
AND			RTK.SwapLegCurrent_LegType										=	'Loan'
INNER JOIN	KplusLocal.dbo.Currencies											CDC
ON			CDC.Currencies_ShortName										=	RTK.DealData_CurrencyShortName
GROUP BY	CDC.Currencies_Id
			,CP.Currencies_Id
			,CDC.Currencies_ShortName
			,CP.Currencies_ShortName


INSERT INTO #Pairs
SELECT		CDC.Currencies_Id												--'CDC'
			,CP.Currencies_Id												--'CP'
			,CONCAT(CDC.Currencies_ShortName,'/',CP.Currencies_ShortName)	--'Pair_ShortName'
FROM		Kustom.dbo.TBL_DRV_RPT_RTK_SW_PROD_HIST								RTK
INNER JOIN	KplusLocal.dbo.Currencies											CP
ON			CP.Currencies_ShortName											=	RTK.StaticData_PrincipalCurrencySh
AND			RTK.Fecha														=	@FechaUltDiaAnoAnt
AND			RTK.SwapDeals_SwapDeals_Id										>	0
AND			RTK.SwapLegCurrent_LegType										=	'Deposit'
INNER JOIN	KplusLocal.dbo.Currencies											CDC
ON			CDC.Currencies_ShortName										=	RTK.DealData_CurrencyShortName
AND			CONCAT(CDC.Currencies_ShortName,'/',CP.Currencies_ShortName)	NOT IN (SELECT Pair_ShortName FROM #Pairs)
GROUP BY	CDC.Currencies_Id
			,CP.Currencies_Id
			,CDC.Currencies_ShortName
			,CP.Currencies_ShortName

INSERT INTO #Pairs
SELECT		 CDC.Currencies_Id												--'CDC'
			,@CLP_ID														--'CP'
			,CONCAT(CDC.Currencies_ShortName,'/CLP')						--'Pair_ShortName'			
FROM		Kustom.dbo.TBL_DRV_RPT_RTK_SW_PROD_HIST		RTK
INNER JOIN	KplusLocal.dbo.Currencies					CDC
ON			CDC.Currencies_ShortName				=	RTK.DealData_CurrencyShortName
AND			RTK.Fecha								=	@FechaUltDiaAnoAnt
AND			RTK.SwapDeals_SwapDeals_Id				>	0
AND			CONCAT(CDC.Currencies_ShortName,'/CLP') NOT IN (SELECT Pair_ShortName FROM #Pairs)
GROUP BY	CDC.Currencies_Id
			,CDC.Currencies_ShortName

SELECT		Pair_ShortName														'Pair_ShortName'
			,Kustom.dbo.FUNC_GET_AMOUNT_CCY_DAY(1, CDC, CP, @FECHA_ANTERIOR)	'Tipo_Cambio'
			INTO #Pairs_TC
FROM		#Pairs 
ORDER BY	1	DESC

SELECT		RTK.SwapDeals_SwapDeals_Id					'SwapDeals_Id'
			,SUM(RTK.RawPLData_Npv * TC.Tipo_Cambio)	'RawPLData_Npv_CLP'
			,0											'NoDecimal'
			,'R'										'RoundingType'
			INTO #CLP
FROM		Kustom.dbo.TBL_DRV_RPT_RTK_SW_PROD_HIST		RTK
INNER JOIN	@TBL_MTM_SWAP								MTM
ON			RTK.SwapDeals_SwapDeals_Id				=	MTM.SwapDeals_Id
AND			RTK.Fecha								=	@FechaUltDiaAnoAnt
AND			RTK.SwapDeals_SwapDeals_Id				>	0
AND			MTM.Tipo								=	1
INNER JOIN	KplusLocal.dbo.Currencies					CDC
ON			CDC.Currencies_ShortName				=	RTK.DealData_CurrencyShortName
INNER JOIN	#Pairs_TC									TC
ON			CONCAT(CDC.Currencies_ShortName,'/CLP')	=	TC.Pair_ShortName
GROUP BY	RTK.SwapDeals_SwapDeals_Id

UPDATE		MTM
SET			MTM.Valor_Mercado_Anterior	=	(CASE A.RoundingType
											 WHEN 'R'
											 THEN ROUND(A.RawPLData_Npv_CLP,A.NoDecimal) 
											 ELSE ROUND(A.RawPLData_Npv_CLP,A.NoDecimal, 1 )
											 END)
FROM 		@TBL_MTM_SWAP					MTM
INNER JOIN	#CLP							A
ON			MTM.SwapDeals_Id			=	A.SwapDeals_Id
AND			MTM.Tipo					=	1

DROP TABLE #Pairs
DROP TABLE #Pairs_TC
DROP TABLE #CLP

--Operaciones del mismo ano (Tipo 2)

SELECT		CDC.Currencies_Id												'CDC'
			,CP.Currencies_Id												'CP'
			,CONCAT(CDC.Currencies_ShortName,'/',CP.Currencies_ShortName)	'Pair_ShortName'
			INTO #Pairs2
FROM		Kustom.dbo.TBL_DRV_RPT_RTK_SW_PROD_HIST								RTK
INNER JOIN	@TBL_MTM_SWAP														MTM
ON			RTK.SwapDeals_SwapDeals_Id										=	MTM.SwapDeals_Id
AND			MTM.Tipo														=	2
AND			RTK.Fecha														= (SELECT MIN(Fecha) FROM Kustom.dbo.TBL_DRV_RPT_RTK_FXO_RM_HIST WHERE DATEDIFF(DAY,@FechaUltDiaAnoAnt,Fecha) >= 0 AND SwapDeals_SwapDeals_Id = RTK.SwapDeals_SwapDeals_Id)
AND			RTK.SwapDeals_SwapDeals_Id										>	0
AND			RTK.SwapLegCurrent_LegType										=	'Loan'
INNER JOIN	KplusLocal.dbo.Currencies											CP
ON			CP.Currencies_ShortName											=	RTK.StaticData_PrincipalCurrencySh
INNER JOIN	KplusLocal.dbo.Currencies											CDC
ON			CDC.Currencies_ShortName										=	RTK.DealData_CurrencyShortName
GROUP BY	CDC.Currencies_Id
			,CP.Currencies_Id
			,CDC.Currencies_ShortName
			,CP.Currencies_ShortName

INSERT INTO #Pairs2
SELECT		CDC.Currencies_Id												--'CDC'
			,CP.Currencies_Id												--'CP'
			,CONCAT(CDC.Currencies_ShortName,'/',CP.Currencies_ShortName)	--'Pair_ShortName'
FROM		Kustom.dbo.TBL_DRV_RPT_RTK_SW_PROD_HIST								RTK
INNER JOIN	@TBL_MTM_SWAP														MTM
ON			RTK.SwapDeals_SwapDeals_Id										=	MTM.SwapDeals_Id
AND			MTM.Tipo														=	2
AND			RTK.Fecha														= (SELECT MIN(Fecha) FROM Kustom.dbo.TBL_DRV_RPT_RTK_FXO_RM_HIST WHERE DATEDIFF(DAY,@FechaUltDiaAnoAnt,Fecha) >= 0 AND SwapDeals_SwapDeals_Id = RTK.SwapDeals_SwapDeals_Id)
AND			RTK.SwapDeals_SwapDeals_Id										>	0
AND			RTK.SwapLegCurrent_LegType										=	'Deposit'
INNER JOIN	KplusLocal.dbo.Currencies											CP
ON			CP.Currencies_ShortName											=	RTK.StaticData_PrincipalCurrencySh
INNER JOIN	KplusLocal.dbo.Currencies											CDC
ON			CDC.Currencies_ShortName										=	RTK.DealData_CurrencyShortName
AND			CONCAT(CDC.Currencies_ShortName,'/',CP.Currencies_ShortName)	NOT IN (SELECT Pair_ShortName FROM #Pairs2)
GROUP BY	CDC.Currencies_Id
			,CP.Currencies_Id
			,CDC.Currencies_ShortName
			,CP.Currencies_ShortName

INSERT INTO #Pairs2
SELECT		CDC.Currencies_Id												--'CDC'
			,@CLP_ID														--'CP'
			,CONCAT(CDC.Currencies_ShortName,'/CLP')						--'Pair_ShortName'			
FROM		Kustom.dbo.TBL_DRV_RPT_RTK_SW_PROD_HIST		RTK
INNER JOIN	@TBL_MTM_SWAP								MTM
ON			RTK.SwapDeals_SwapDeals_Id				=	MTM.SwapDeals_Id
AND			MTM.Tipo								=	2
AND			RTK.Fecha								= (SELECT MIN(Fecha) FROM Kustom.dbo.TBL_DRV_RPT_RTK_FXO_RM_HIST WHERE DATEDIFF(DAY,@FechaUltDiaAnoAnt,Fecha) >= 0 AND SwapDeals_SwapDeals_Id = RTK.SwapDeals_SwapDeals_Id)
INNER JOIN	KplusLocal.dbo.Currencies					CDC
ON			CDC.Currencies_ShortName				=	RTK.DealData_CurrencyShortName
AND			CONCAT(CDC.Currencies_ShortName,'/CLP') NOT IN (SELECT Pair_ShortName FROM #Pairs2)
GROUP BY	CDC.Currencies_Id
			,CDC.Currencies_ShortName

SELECT		Pair_ShortName														'Pair_ShortName'
			,Kustom.dbo.FUNC_GET_AMOUNT_CCY_DAY(1, CDC, CP, @FECHA_ANTERIOR)	'Tipo_Cambio'
			INTO #Pairs_TC2
FROM		#Pairs2 
ORDER BY	1	DESC


SELECT		RTK.SwapDeals_SwapDeals_Id					'SwapDeals_Id'
			,SUM(RTK.RawPLData_Npv * TC.Tipo_Cambio)	'RawPLData_Npv_CLP'
			,0											'NoDecimal'
			,'R'										'RoundingType'
			INTO #CLP2
FROM		Kustom.dbo.TBL_DRV_RPT_RTK_SW_PROD_HIST		RTK
INNER JOIN	@TBL_MTM_SWAP								MTM
ON			RTK.SwapDeals_SwapDeals_Id				=	MTM.SwapDeals_Id
AND			RTK.Fecha								= (SELECT MIN(Fecha) FROM Kustom.dbo.TBL_DRV_RPT_RTK_FXO_RM_HIST WHERE DATEDIFF(DAY,@FechaUltDiaAnoAnt,Fecha) >= 0 AND SwapDeals_SwapDeals_Id = RTK.SwapDeals_SwapDeals_Id)
AND			RTK.SwapDeals_SwapDeals_Id				>	0
AND			MTM.Tipo								=	2
INNER JOIN	KplusLocal.dbo.Currencies					CDC
ON			CDC.Currencies_ShortName				=	RTK.DealData_CurrencyShortName
INNER JOIN	#Pairs_TC2									TC
ON			CONCAT(CDC.Currencies_ShortName,'/CLP')	=	TC.Pair_ShortName
GROUP BY	RTK.SwapDeals_SwapDeals_Id


UPDATE		MTM
SET			MTM.Valor_Mercado_Anterior	=	(CASE A.RoundingType
											 WHEN 'R'
											 THEN ROUND(A.RawPLData_Npv_CLP,A.NoDecimal) 
											 ELSE ROUND(A.RawPLData_Npv_CLP,A.NoDecimal, 1 )
											 END)
FROM 		@TBL_MTM_SWAP					MTM
INNER JOIN	#CLP2							A
ON			MTM.SwapDeals_Id			=	A.SwapDeals_Id
AND			MTM.Tipo					=	2

DROP TABLE #Pairs2
DROP TABLE #Pairs_TC2
DROP TABLE #CLP2

UPDATE		@TBL_MTM_SWAP
SET			Variacion		=	Valor_Mercado_Neto_Dia - Valor_Mercado_Anterior
--WHERE		Tipo			=	1

UPDATE		C
SET			C.Variacion_anual_Rdo_MTM	=	MTM.Variacion
FROM		@CARTERA						C
INNER JOIN	@TBL_MTM_SWAP					MTM
ON			C.Num_Ope					=	MTM.SwapDeals_Id

UPDATE		@CARTERA
SET			CC_Resultado = Kustom.dbo.FUNC_KP_SWP_Acc(		TypeOfInstr_ShortName,
															FloatingRates_Id_D,
															FloatingRates_Id_L,
															Folders_Id_Captured,
															Cpty_Id,
															FUNC_DRV_SWAP_Delivery_Mode, 
															Ccy_L,
															Ccy_D,
															(CASE 
															 WHEN (ISNULL(Valor_Mercado_Neto_Dia, 0) >= 0) AND (ISNULL(Variacion_anual_Rdo_MTM,0) < 0)
															 THEN 'Act Perdida_MtM_DB'
															 WHEN (ISNULL(Valor_Mercado_Neto_Dia, 0) < 0) AND (ISNULL(Variacion_anual_Rdo_MTM,0) <= 0)
															 THEN 'Pas Perdida_MtM_DB'
															 WHEN (ISNULL(Valor_Mercado_Neto_Dia, 0) >= 0) AND (ISNULL(Variacion_anual_Rdo_MTM,0) >= 0)
															 THEN 'Act Ganancia_MtM_CR'
															 WHEN (ISNULL(Valor_Mercado_Neto_Dia, 0) < 0) AND (ISNULL(Variacion_anual_Rdo_MTM,0) > 0)
															 THEN 'Pas Ganancia_MtM_CR'
															END)
										)

--UPDATE @CARTERA
--
--					SET TNA_L = Accrued.TNA 
--
--		from	Kustom..TBL_DRV_SwapAccrued Accrued
--INNER JOIN @CARTERA SD
--ON  DATEDIFF (dd, Accrued.Fecha, @FECHAEJECUCION) = 0
--AND SD.Num_Ope = Accrued.SwapDeals_Id
--AND Accrued.SwapLeg = 'L'
-- 
--			
--
--UPDATE @CARTERA
--
--					SET TNA_D = Accrued.TNA 
--
--		from	Kustom..TBL_DRV_SwapAccrued Accrued
--INNER JOIN @CARTERA SD
--ON DATEDIFF (dd, Accrued.Fecha, @FECHAEJECUCION) = 0
--AND SD.Num_Ope = Accrued.SwapDeals_Id
--AND Accrued.SwapLeg = 'D'
--		
--
--UPDATE @CARTERA
--
--					SET TRA_L = Accrued.TRA 
--
--		from	Kustom..TBL_DRV_SwapAccrued Accrued
--INNER JOIN @CARTERA SD
--ON DATEDIFF (dd, Accrued.Fecha, @FECHAEJECUCION) = 0
--AND SD.Num_Ope = Accrued.SwapDeals_Id
--AND Accrued.SwapLeg = 'L'
--			
--
--UPDATE @CARTERA
--
--					SET TRA_D = Accrued.TRA 
--
--		from	Kustom..TBL_DRV_SwapAccrued Accrued
--INNER JOIN @CARTERA SD
--ON DATEDIFF (dd, Accrued.Fecha, @FECHAEJECUCION) = 0
--AND SD.Num_Ope = Accrued.SwapDeals_Id
--AND Accrued.SwapLeg = 'D'			
															

/* SALIDA CONTA */
INSERT INTO Kustom.dbo.TBL_SWAP_CARTERA
SELECT
@FECHAEJECUCION_HOY,
@FECHAEJECUCION,
Tipo_Ope,
Tipo_Cartera,
Oficina,
Num_Ope,
Relacionado,
Rut,
Nombre_Cliente,
Fecha_Inicio_R1,
Fecha_Vto_R1,
Fecha_Inicio_R2,
Fecha_Vto_R2,
Tipo_Tasa_R,
Tasa_R,
Dias_Dev_R,
Moneda_R,
Nominal_R,
Nominal_R_CLP,
Fecha_Inicio_P,
Fecha_Vto_P,
Tipo_Tasa_P,
Tasa_P,
Dias_Dev_P,
Moneda_P,
Nominal_P,
Nominal_P_CLP,
Valor_Mercado_Activo,
Valor_Mercado_Activo_CLP,
Interes_Activo,
Interes_Activo_CLP,
Valor_Mercado_Pasivo,
Valor_Mercado_Pasivo_CLP,
Interes_Pasivo,
Interes_Pasivo_CLP,
Valor_Mercado_Neto_Dia,
Valor_Mercado_Dia_Anterior,
Variacion_anual_Rdo_MTM, --nuevo
Ajuste_Mercado,
CC_Nocionales_Activo,
CC_Nocionales_Pasivo,
CC_MTM_Neto,
CC_Resultado,
CC_MTM_Activo,
CC_Interes_Activo,
CC_MTM_Pasivo,
CC_Interes_Pasivo,
CC_Int_Result_Activo,
CC_Int_Result_Pasivo,
TNA_L,
TRA_L,
TNA_D,
TRA_D
FROM  @CARTERA
ORDER BY Tipo_Ope

DECLARE @FECHAMTM DATETIME = (SELECT TOP 1 Fecha_Reporte FROM Kustom.[dbo].[TBL_MTM_SWAP])
EXEC dbo.PRC_DRV_MTM_SWAP  @FECHAEJECUCION

---Variacion MTM
UPDATE 		S
SET			S.Variacion_anual_Rdo_MTM	=	M.VARIATION_MTM_CLP
FROM 		Kustom.dbo.TBL_SWAP_CARTERA					S
INNER JOIN 	Kustom.[dbo].[TBL_MTM_SWAP]					M
ON 			S.Num_Ope 						= 			M.SwapDeals_Id
AND 		S.Fecha_Reporte 				= 			@FECHAEJECUCION


UPDATE		S
SET CC_Resultado =
				Kustom.dbo.FUNC_KP_SWP_Acc(	TypeOfInstr.TypeOfInstr_ShortName,
															SwapLeg_D.FloatingRates_Id,																																	
															SwapLeg_L.FloatingRates_Id,
															D.Folders_Id_Captured,
															SwapLeg_L.Cpty_Id,
															dbo.FUNC_DRV_SWAP_Delivery_Mode(D.SwapDeals_Id), 
															(case	when SwapLeg_L.Pairs_Id_Principal 	= 	0 
																	then SwapLeg_L.Currencies_Id
																	when PAIR_L.Currencies_Id_1 		= 	SwapLeg_L.Currencies_Id 
																	then PAIR_L.Currencies_Id_2
																	else PAIR_L.Currencies_Id_1
															end ),
															(case	when SwapLeg_D.Pairs_Id_Principal = 0 then SwapLeg_D.Currencies_Id
																	when PAIR_D.Currencies_Id_1 = SwapLeg_D.Currencies_Id then PAIR_D.Currencies_Id_2
																	else PAIR_D.Currencies_Id_1
															end ),
															(CASE 
															 WHEN (ISNULL(S.Valor_Mercado_Neto_Dia, 0) >= 0) AND (ISNULL(M.VARIATION_MTM_CLP,0) < 0)
															 THEN 'Act Perdida_MtM_DB'
															 WHEN (ISNULL(S.Valor_Mercado_Neto_Dia, 0) < 0) AND (ISNULL(M.VARIATION_MTM_CLP,0) <= 0)
															 THEN 'Pas Perdida_MtM_DB'
															 WHEN (ISNULL(S.Valor_Mercado_Neto_Dia, 0) >= 0) AND (ISNULL(M.VARIATION_MTM_CLP,0) >= 0)
															 THEN 'Act Ganancia_MtM_CR'
															 WHEN (ISNULL(S.Valor_Mercado_Neto_Dia, 0) < 0) AND (ISNULL(M.VARIATION_MTM_CLP,0) > 0)
															 THEN 'Pas Ganancia_MtM_CR'
															END)
															)
FROM 		Kustom.dbo.TBL_SWAP_CARTERA					S
INNER JOIN 	Kustom.[dbo].[TBL_MTM_SWAP]					M
ON 			S.Num_Ope 						= 			M.SwapDeals_Id
AND 		S.Fecha_Reporte 				= 			@FECHAEJECUCION
INNER JOIN 	KplusLocal..SwapDeals						D
ON			S.Num_Ope						=			D.SwapDeals_Id
INNER JOIN 	KplusLocal..SwapLeg							SwapLeg_L
ON			D.SwapDeals_Id					=			SwapLeg_L.SwapDeals_Id
AND			SwapLeg_L.LegType				=			'L'
INNER JOIN	KplusLocal..SwapLeg							SwapLeg_D
ON			D.SwapDeals_Id					= 			SwapLeg_D.SwapDeals_Id
AND			SwapLeg_D.LegType				= 			'D'
INNER JOIN	KplusLocal.dbo.TypeOfInstr					TypeOfInstr
ON			SwapLeg_L.TypeOfInstr_Id				= 	TypeOfInstr.TypeOfInstr_Id
LEFT JOIN	KplusLocal..Pairs							PAIR_D
ON			SwapLeg_D.Pairs_Id_Principal			=	PAIR_D.Pairs_Id
LEFT JOIN	KplusLocal..Pairs							PAIR_L
ON			SwapLeg_L.Pairs_Id_Principal			=	PAIR_L.Pairs_Id

EXEC dbo.PRC_DRV_MTM_SWAP  @FECHAMTM


END

drop table #U_SWP
drop table #U_SWP_Starting

SET NOCOUNT OFF /*no queremos que nos devuelva le numero de filas afectadas*/
END 

GO
PRINT 'GRANT  SP'
GO
GRANT EXECUTE ON dbo.PRC_DRV_CARTERA_SWP TO PUBLIC
GO
PRINT 'FIN CATALOGA SP: Kustom.dbo.PRC_DRV_CARTERA_SWP'
GO