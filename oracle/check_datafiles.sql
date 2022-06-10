set linesize 30000
col "File Name" for a50
col "Tablespace" for a20
col "Status" for a10
col "Size (MB)" for a20
col "Used (MB)" for a20
col "Used (Proportion)" for a10
col "Used (%)" for a10
col "Auto Extend" for a10

SELECT /*+ all_rows use_concat */ 
                        ddf.file_name as "File Name",
                        ddf.tablespace_name as "Tablespace", 
                        ddf.online_status as "Status", 
                        TO_CHAR(NVL(ddf.bytes / 1024 / 1024, 0), '99999990.000') as "Size (MB)", 
                        TO_CHAR(DECODE(NVL(u.bytes/1024/1024, 0), 0, NVL((ddf.bytes - NVL(s.bytes, 0))/1024/1024, 0), NVL(u.bytes/1024/1024, 0)), '99999999.999') as "Used (MB)",                         
                        CASE 
                        when ddf.online_status = 'OFFLINE' then
                          'OFFLINE'
                        when ddf.online_status = 'RECOVER' then
                          'RECOVER'
                        else
                          TRIM(TO_CHAR(DECODE((NVL(u.bytes, 0) / ddf.bytes * 100), 0, NVL((ddf.bytes - NVL(s.bytes, 0)) / ddf.bytes * 100, 0), (NVL(u.bytes, 0) / ddf.bytes * 100)), '990')) 
                        end as "Used (Proportion)",
                        TO_CHAR(DECODE((NVL(u.bytes, 0) / ddf.bytes * 100), 0, NVL((ddf.bytes - NVL(s.bytes, 0)) / ddf.bytes * 100, 0), (NVL(u.bytes, 0) / ddf.bytes * 100)), '990.99') as "Used (%)", 
                        ddf.autoextensible as "Auto Extend" 
                    FROM 
                        sys.dba_data_files ddf, 
                        (
                            SELECT 
                                file_id, 
                                SUM(bytes) bytes 
                            FROM 
                                sys.dba_free_space GROUP BY file_id
                        ) s, 
                        (
                            SELECT 
                                file_id, 
                                SUM(bytes) bytes 
                            FROM 
                                sys.dba_undo_extents 
                            WHERE 
                                status <> 'EXPIRED' 
                            GROUP BY file_id
                        ) u 
                    WHERE 
                        (ddf.file_id = s.file_id(+) and ddf.file_id=u.file_id(+))
                    UNION
                    SELECT 
                        v.name as "File Name",
                        dtf.tablespace_name as "Tablespace",
                        dtf.status as "Status", 
                        TO_CHAR(NVL(dtf.bytes / 1024 / 1024, 0), '99999990.000') as "Size (MB)", 
                        TO_CHAR(NVL(t.bytes_used/1024/1024, 0), '99999990.000') as "Used (MB)", 
                        CASE 
                        when dtf.status = 'OFFLINE' then
                          'OFFLINE'
                        else
	                        TRIM(TO_CHAR(NVL(t.bytes_used / dtf.bytes * 100, 0), '990.99'))
                        end as "Used (Proportion)",
                        TO_CHAR(NVL(t.bytes_used / dtf.bytes * 100, 0), '990') as "Used (%)", 
                        dtf.autoextensible as "Auto Extend" 
                    FROM 
                        sys.dba_temp_files dtf, 
                        sys.v_$tempfile v,
                        v$temp_extent_pool t 
                    WHERE 
                        (dtf.file_name = v.name or dtf.file_id = v.file#)
                        and dtf.file_id = t.file_id(+)
                    ORDER BY 1;
                    
