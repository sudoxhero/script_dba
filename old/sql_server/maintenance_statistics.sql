CREATE   PROCEDURE sp_update_statistics @isReport INT = NULL , @modification_counter INT = 0 AS  
--*******************************************************  
-- Title: maintenance_statistics.sql  
-- Source: https://github.com/sudoxhero/script_dba  
-- Autor: Emanoel Carlos  
--*******************************************************  
  
--*******************************************************  
-- Description:   
-- Store Procedure que levanta e atualiza as estatisticas que contenha modificação da base de dados que esta sendo executado  
  
--*******************************************************  
-- ATENTION!!   
-- Dependendo da quantidade e tamanho dos indexes o processo pode impactar e demorar por horas. É importante que seja executado em momento ocioso para não impactar os usuários  
  
--*******************************************************  
-- Mode Use:  
-- Para gerar apenas relatório execute : exec sp_update_statistics 0  
-- Para realizar o procedimento execute : exec sp_update_statistics 1 

-- Para filtrar a quantidade de linha modificadas : exec sp_update_statistics 0 , 80000000
  
--*******************************************************  
-- Modification history:  
-- Emanoel Carlos - June 09, 2022  
-- Emanoel Carlos - 10/08/2022 - Implementação @modification_counter para filtrar a procedure executar para tabelas que tem a quantidade de linha modificada informada
  
--*******************************************************  
  
DECLARE  
@UpdateStatisticsCommand NVARCHAR(MAX)  
  
IF @isReport = 1  
BEGIN  
  
SET NOCOUNT ON  
  
IF OBJECT_ID('tempdb..#tmpUpdateStatistics') IS NOT NULL  
DROP TABLE #tmpUpdateStatistics;  
  
SELECT  
DISTINCT 'UPDATE STATISTICS '+SCHEMA_NAME(tbl.schema_id)+'.'+OBJECT_NAME(stat.object_id)+' WITH FULLSCAN;' as [UpdateStatisticsCommand]  
INTO #tmpUpdateStatistics  
FROM sys.stats AS stat  
CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp  
INNER JOIN sys.tables tbl ON stat.object_id = tbl.object_id  
WHERE   
tbl.type = 'U'  
AND modification_counter > @modification_counter  
OPTION (RECOMPILE);  
  
DECLARE update_statistics_cursor CURSOR   
FOR SELECT UpdateStatisticsCommand FROM #tmpUpdateStatistics  
  
OPEN update_statistics_cursor  
  
FETCH NEXT FROM update_statistics_cursor INTO @UpdateStatisticsCommand  
  
WHILE @@FETCH_STATUS = 0  
BEGIN  
  
PRINT '#################################################################################################################################'  
PRINT 'Executing script:'       
PRINT @UpdateStatisticsCommand  
PRINT ''  
EXEC (@UpdateStatisticsCommand);  
  
FETCH NEXT FROM update_statistics_cursor INTO @UpdateStatisticsCommand  
END  
CLOSE update_statistics_cursor;  
DEALLOCATE update_statistics_cursor;  
  
PRINT ''  
PRINT 'All statistics have been updated.'  
PRINT ''  
  
IF OBJECT_ID('tempdb..#tmpUpdateStatistics') IS NOT NULL  
DROP TABLE #tmpUpdateStatistics;  
END  
  
ELSE IF @isReport = 0 OR @isReport IS NULL  
BEGIN  
  
SELECT  
OBJECT_NAME(stat.object_id) as [TableName],  
stat.name as [IndexName],  
last_updated,  
rows,   
rows_sampled,   
modification_counter,  
'UPDATE STATISTICS '+SCHEMA_NAME(tbl.schema_id)+'.'+OBJECT_NAME(stat.object_id)+' WITH FULLSCAN;' as [UpdateStatisticsCommand]  
FROM sys.stats AS stat  
CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp  
INNER JOIN sys.tables tbl ON stat.object_id = tbl.object_id  
WHERE   
tbl.type = 'U'  
AND modification_counter > @modification_counter  
ORDER BY modification_counter DESC, last_updated DESC  
OPTION (RECOMPILE);  
  
END  
  
ELSE IF @isReport NOT IN (0,1)  
BEGIN  
  
PRINT 'ERROR : Comando invalido.  
Valores disponiveis:  
0 = Somente Relatorio  
1 = Realiza a manutenção  
'  
  
END
