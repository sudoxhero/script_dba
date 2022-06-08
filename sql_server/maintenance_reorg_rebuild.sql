
SELECT
CASE WHEN ps.avg_fragmentation_in_percent > 30 THEN 
     'ALTER INDEX ['+i.name+'] ON ['+DB_NAME()+'].['+SCHEMA_NAME (tbl.schema_id)+'].['+OBJECT_NAME(ps.OBJECT_ID)+'] REBUILD WITH (FILLFACTOR = 90, SORT_IN_TEMPDB = ON, STATISTICS_NORECOMPUTE = OFF);'
     WHEN ps.avg_fragmentation_in_percent <= 30 THEN 
     'ALTER INDEX ['+i.name+'] ON ['+DB_NAME()+'].['+SCHEMA_NAME (tbl.schema_id)+'].['+OBJECT_NAME(ps.OBJECT_ID)+'] REORGANIZE;'    
     ELSE
     NULL
     END as [reorganizationOrRebuildCommand] INTO #tmpFragmentedIndexes 
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
   AND page_count > 500 
   --AND ps.avg_fragmentation_in_percent >= 15
OPTION (RECOMPILE);

DECLARE @ReorganizeOrRebuildCommand NVARCHAR(MAX);

BEGIN 
 DECLARE reorganizeOrRebuildCommands_cursor CURSOR
 FOR
    SELECT  reorganizationOrRebuildCommand
  FROM #tmpFragmentedIndexes
  WHERE reorganizationOrRebuildCommand IS NOT NULL;

 OPEN reorganizeOrRebuildCommands_cursor;
 FETCH NEXT FROM reorganizeOrRebuildCommands_cursor INTO @ReorganizeOrRebuildCommand;
 WHILE @@fetch_status = 0
  BEGIN   
     PRINT ''
     PRINT 'Executing script:'     
     PRINT @ReorganizeOrRebuildCommand
   END
          
   EXEC (@ReorganizeOrRebuildCommand);          
   FETCH NEXT FROM reorganizeOrRebuildCommands_cursor INTO @ReorganizeOrRebuildCommand;
  END;

 CLOSE reorganizeOrRebuildCommands_cursor;
 DEALLOCATE reorganizeOrRebuildCommands_cursor;

 PRINT ''
 PRINT 'All fragmented indexes have been reorganized/rebuilt.'
 PRINT ''
