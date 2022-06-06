WITH IndexSchema   
    AS (SELECT we.object_id,           
        we.index_id,           
        we.name,           
        ISNULL(we.filter_definition, '') AS filter_definition,           
        we.is_unique,           
        (               
            SELECT QUOTENAME(CAST(ic.column_id AS VARCHAR(10)) + CASE                                     
                WHEN ic.is_descending_key = 1 THEN '-'                                                              
                ELSE '+' END,                          
                '('                      
            )               
            FROM sys.index_columns ic
                INNER JOIN sys.columns c ON ic.object_id = c.object_id                                        
                AND ic.column_id = c.column_id               
                WHERE we.object_id = ic.object_id               
                AND we.index_id = ic.index_id               
                AND is_included_column = 0               
                ORDER BY key_ordinal ASC               
                FOR XML PATH('')
        ) + COALESCE((                   
            SELECT QUOTENAME(CAST(ic.column_id AS VARCHAR(10)) + CASE                                      
                WHEN ic.is_descending_key = 1 THEN '-'                                      
                ELSE '+' END,                              
                '('                          
            )                   
            FROM sys.index_columns ic                   
            INNER JOIN sys.columns c ON ic.object_id = c.object_id                                            
            AND ic.column_id = c.column_id                   
            LEFT OUTER JOIN sys.index_columns ic_key ON c.object_id = ic_key.object_id                                                         
            AND c.column_id = ic_key.column_id                                                         
            AND we.index_id = ic_key.index_id                                                         
            AND ic_key.is_included_column = 0                   
            WHERE we.object_id = ic.object_id                   
            AND ic.index_id = 1                   
            AND ic.is_included_column = 0                   
            AND ic_key.index_id IS NULL                   
            ORDER BY ic.key_ordinal ASC                   
    FOR XML PATH('')               
    ),                   
    ''
    ) + CASE                        
    WHEN we.is_unique = 1 THEN 'U'                        
    ELSE '' END AS index_columns_keys_ids,           
    CASE                
    WHEN we.index_id IN ( 0, 1 ) THEN 'ALL-COLUMNS'                
    ELSE COALESCE((                         
        SELECT QUOTENAME(ic.column_id, '(')                         
        FROM sys.index_columns ic                         
        INNER JOIN sys.columns c ON ic.object_id = c.object_id                                                  
        AND ic.column_id = c.column_id                         
        LEFT OUTER JOIN sys.index_columns ic_key ON c.object_id = ic_key.object_id                                                   
        AND c.column_id = ic_key.column_id                                                   
        AND ic_key.index_id = 1                         
        WHERE we.object_id = ic.object_id                         
        AND we.index_id = ic.index_id                         
        AND ic.is_included_column = 1                         
        AND ic_key.index_id IS NULL                         
        ORDER BY ic.key_ordinal ASC
FOR XML PATH
('')                     
),                         
SPACE(0)                     
) END AS included_columns_ids       
FROM sys.tables t       
INNER JOIN sys.indexes we ON t.object_id = we.object_id       
INNER JOIN sys.data_spaces ds ON we.data_space_id = ds.data_space_id       
INNER JOIN sys.dm_db_partition_stats ps ON we.object_id = ps.object_id                                               
AND we.index_id = ps.index_id) 
SELECT QUOTENAME(DB_NAME()) AS database_name,     
QUOTENAME(OBJECT_SCHEMA_NAME(is1.object_id)) + '.' + QUOTENAME(OBJECT_NAME(is1.object_id)) AS object_name,     
is1.name AS index_name,     is2.name AS duplicate_index_name FROM IndexSchema is1 INNER JOIN IndexSchema is2 ON is1.object_id = is2.object_id                            
AND is1.index_id <> is2.index_id                            
AND is1.index_columns_keys_ids = is2.index_columns_keys_ids                            
AND is1.included_columns_ids = is2.included_columns_ids                            
AND is1.filter_definition = is2.filter_definition                            
AND is1.is_unique = is2.is_unique; 
