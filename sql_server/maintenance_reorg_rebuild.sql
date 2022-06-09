CREATE OR ALTER PROCEDURE sp_reorg_rebuild AS
--*******************************************************
-- Title: maintenance_reorg_rebuild.sql
-- Source: https://github.com/sudoxhero/script_dba
-- Autor: Emanoel Carlos
--*******************************************************

--*******************************************************
-- Description: 
-- Store Procedure que levanta e desfragmenta os indexes da base de dados que esta sendo executado que contenha mais de 15% de fragmentação e com mais de 1000 paginas, assim evitando pegar indexes pequenos.
-- Será realizado reorganize nos indexes que tiverem entre 5% e 30% de fragmentação
-- Será realizado rebuild nos indexes que tiverem mais que 30% de fragmentação
-- A saida estará como texto contendo o antes e o depois

--*******************************************************
-- ATENTION!! 
-- Dependendo da quantidade e tamanho dos indexes fragmentados o processo pode impactar e demorar por horas. É importante que seja executado em momento ocioso para não impactar os usuários

--*******************************************************
-- Mode Use:
-- Após a criação da store procedure, executar o comando exec sp_reorg_rebuild

--*******************************************************
-- Modification history:
-- Emanoel Carlos - June 09, 2022

--*******************************************************

SET NOCOUNT ON

-- Garantindo que a tabela #tmpFragmentedIndexes não existe
IF OBJECT_ID('tempdb..#tmpFragmentedIndexes') IS NOT NULL
DROP TABLE #tmpFragmentedIndexes;

-- Criando a tabela #tmpFragmentedIndexes com os indexes que tenham mais de 15% de fragmentação e com mais de 1000 paginas para não pegar indexes pequenos
SELECT
DB_NAME(ps.database_id) as [DatabaseName],
SCHEMA_NAME(tbl.schema_id) as [SchemaName],
OBJECT_NAME(ps.object_id) as [TableName],
i.name as [IndexName],
ps.avg_fragmentation_in_percent as [FragmentationPercent],
CASE WHEN ps.avg_fragmentation_in_percent > 30 THEN 
     'ALTER INDEX ['+i.name+'] ON ['+DB_NAME()+'].['+SCHEMA_NAME (tbl.schema_id)+'].['+OBJECT_NAME(ps.OBJECT_ID)+'] REBUILD WITH (FILLFACTOR = 90, SORT_IN_TEMPDB = ON, STATISTICS_NORECOMPUTE = OFF);'
     WHEN ps.avg_fragmentation_in_percent <= 30 THEN 
     'ALTER INDEX ['+i.name+'] ON ['+DB_NAME()+'].['+SCHEMA_NAME (tbl.schema_id)+'].['+OBJECT_NAME(ps.OBJECT_ID)+'] REORGANIZE;'    
     ELSE
     NULL
     END as [ReorgOrRebuildCommand] 
INTO #tmpFragmentedIndexes
FROM
   sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL , 'DETAILED') AS ps 
   INNER JOIN
      sys.indexes AS i WITH (NOLOCK) 
      ON ps.[object_id] = i.[object_id] 
      AND ps.index_id = i.index_id 
   INNER JOIN 
      sys.tables as tbl WITH (NOLOCK) 
      ON ps.object_id = tbl.object_id
WHERE
   ps.index_id != 0
   AND ps.alloc_unit_type_desc IN ( N'IN_ROW_DATA', N'ROW_OVERFLOW_DATA')
   AND database_id = DB_ID() 
   AND page_count > 1000 
   AND ps.avg_fragmentation_in_percent >= 15
OPTION (RECOMPILE);

-- Criando cursor para que execute os comandos de reorg e rebuild
DECLARE 
@SchemaName nvarchar(max),
@TableName nvarchar(max),
@IndexName nvarchar(max),
@FragmentationPercent nvarchar(max),
@ReorgOrRebuildCommand nvarchar(max)

DECLARE reorg_rebuild_cursor CURSOR 
FOR SELECT SchemaName,TableName,IndexName,FragmentationPercent,ReorgOrRebuildCommand FROM #tmpFragmentedIndexes

OPEN reorg_rebuild_cursor

FETCH NEXT FROM reorg_rebuild_cursor INTO @SchemaName,@TableName,@IndexName,@FragmentationPercent,@ReorgOrRebuildCommand

WHILE @@FETCH_STATUS = 0
BEGIN

PRINT '#################################################################################################################################'
PRINT ''
PRINT 'Fragmentation Percent: '+@FragmentationPercent
PRINT 'Index: '+@SchemaName+'.'+@TableName+'.'+@IndexName
PRINT 'Command: '+@ReorgOrRebuildCommand
PRINT ''
PRINT 'Executing script:'     
PRINT @ReorgOrRebuildCommand
PRINT ''
EXEC (@ReorgOrRebuildCommand);

DECLARE @ResultAfter nvarchar(max)

SELECT @ResultAfter =
'
Fragmentation Percent: '+convert(nvarchar,ps.avg_fragmentation_in_percent)+'
Index: '+SCHEMA_NAME(tbl.schema_id)+'.'+OBJECT_NAME(ps.object_id)+'.'+i.name
FROM
   sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL , 'DETAILED') AS ps 
   INNER JOIN
      sys.indexes AS i WITH (NOLOCK) 
      ON ps.[object_id] = i.[object_id] 
      AND ps.index_id = i.index_id 
   INNER JOIN 
      sys.tables as tbl WITH (NOLOCK) 
      ON ps.object_id = tbl.object_id
WHERE
SCHEMA_NAME(tbl.schema_id) = @SchemaName
AND OBJECT_NAME(ps.object_id) = @TableName
AND i.name = @IndexName
OPTION (RECOMPILE)

PRINT @ResultAfter

PRINT ''
PRINT '#################################################################################################################################'

FETCH NEXT FROM reorg_rebuild_cursor INTO @SchemaName,@TableName,@IndexName,@FragmentationPercent,@ReorgOrRebuildCommand
END
CLOSE reorg_rebuild_cursor;
DEALLOCATE reorg_rebuild_cursor;

PRINT ''
PRINT 'All fragmented indexes have been reorganized/rebuilt.'
PRINT ''

-- Apagando as tabelas temporarias
IF OBJECT_ID('tempdb..#tmpFragmentedIndexes') IS NOT NULL
DROP TABLE #tmpFragmentedIndexes;
