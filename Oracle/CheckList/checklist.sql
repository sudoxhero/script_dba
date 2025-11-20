#!/bin/bash

ORACLE_SID=$1

export userOS=oracle

echo ""



export ORACLE_SID=${ORACLE_SID}
export ORACLE_BASE=/opt/u01
if [ `hostname` == 'drjscgerlx017' ]; then
export ORACLE_HOME=/opt/u01/app/oracle/product/11.2.0/client_1/
else
export ORACLE_HOME=/opt/u01/product/11.2.0/client_1/
fi
export TNS_ADMIN=$ORACLE_HOME/network/admin
export NLS_LANG=AMERICAN_AMERICA.WE8ISO8859P1
export NLS_DATE_FORMAT='dd/mm/yyyy hh24:mi:ss'
export ORA_NLS10=$ORACLE_HOME/nls/data
export ORA_SDTZ=DB_TZ
export PATH=$PATH:$ORACLE_HOME/bin
export LD_LIBRARY_PATH=$ORACLE_HOME/lib

mkdir -p /producaoRJ/global/dba_producao/scripts/Check_criticas/p639366/log/$(date +'%Y%m%d')
LOG_FILE="/producaoRJ/global/dba_producao/scripts/Check_criticas/p639366/log/$(date +'%Y%m%d')/checklist_${ORACLE_SID}_$(date +'%Y%m%d_%H%M').log"
exec > >(tee -a ${LOG_FILE}) 2>&1

echo ""
echo "######### Inicio do checklist do banco ${ORACLE_SID} as $(date +'%Y%m%d_%H%M%S') #########"
echo ""

handle_error() {
	echo "$1"
	mailx -s "Falha Checklist Oracle ${ORACLE_SID}" p639366@corp.caixa.gov.br
	exit 1
}

get_db_version() {
	#echo "Obtendo a versão do banco..."
	DB_VERSION=$(sqlplus -s "/@${ORACLE_SID}" <<EOF
whenever sqlerror exit failure
set heading off
set feedback off
select version from v\$instance;
exit;
EOF
)


	if [ $? -ne 0 ]; then
		handle_error "Erro ao conectar no banco de dados: ${DB_VERSION}"
	fi
	
	
	DB_VERSION_NUMERIC=$(echo "$DB_VERSION" | cut -d '.' -f 1)

	echo ""
	echo "Conectado a base de dados!"
	echo ""
}


check_instance() {
echo "##################################"	
echo "######### Check Instance #########"
echo "##################################"
echo ""
if [[ $DB_VERSION_NUMERIC -gt 11 ]]; then
                sqlplus -s "/@${ORACLE_SID}" <<EOF
whenever sqlerror exit failure
set colsep ";"
set linesize 300
set pagesize 50
col uptime for a40
col host_name for a40
col logins for a10
            select
                i.inst_id,
                i.instance_name,
                i.host_name,
                floor(sysdate - i.startup_time)|| ' Dias '||trunc( 24*((sysdate-i.startup_time)-trunc(sysdate-i.startup_time)))||' Horas '||mod(trunc(1440*((sysdate-i.startup_time)-trunc(sysdate-i.startup_time))), 60)||' Minutos '  as uptime,
                d.open_mode,
                d.protection_mode,
                i.logins,
                d.flashback_on,
                d.database_role,
		d.cdb,
                i.version
            from gv\$instance i, gv\$database d
                        group by
                        i.inst_id,
                i.instance_name,
                i.host_name,
                floor(sysdate - i.startup_time)|| ' Dias '||trunc( 24*((sysdate-i.startup_time)-trunc(sysdate-i.startup_time)))||' Horas '||mod(trunc(1440*((sysdate-i.startup_time)-trunc(sysdate-i.startup_time))), 60)||' Minutos ',
                d.open_mode,
                d.protection_mode,
                i.logins,
                d.flashback_on,
                d.database_role,
		d.cdb,
                i.version
            order by i.inst_id;
exit;
EOF

else
		sqlplus -s "/@${ORACLE_SID}" <<EOF
whenever sqlerror exit failure
set colsep ";"
set linesize 300
set pagesize 50
col uptime for a40
col host_name for a40
col logins for a10
            select
                i.inst_id,
                i.instance_name,
                i.host_name,
                floor(sysdate - i.startup_time)|| ' Dias '||trunc( 24*((sysdate-i.startup_time)-trunc(sysdate-i.startup_time)))||' Horas '||mod(trunc(1440*((sysdate-i.startup_time)-trunc(sysdate-i.startup_time))), 60)||' Minutos '  as uptime,
                d.open_mode,
                d.protection_mode,
                i.logins,
                d.flashback_on,
                d.database_role,
                i.version
            from gv\$instance i, gv\$database d
			group by 
			i.inst_id,
                i.instance_name,
                i.host_name,
                floor(sysdate - i.startup_time)|| ' Dias '||trunc( 24*((sysdate-i.startup_time)-trunc(sysdate-i.startup_time)))||' Horas '||mod(trunc(1440*((sysdate-i.startup_time)-trunc(sysdate-i.startup_time))), 60)||' Minutos ',
                d.open_mode,
                d.protection_mode,
                i.logins,
                d.flashback_on,
                d.database_role,
                i.version
            order by i.inst_id;
exit;
EOF

fi

        if [ $? -ne 0 ]; then
                handle_error "check_instance"
        fi
	echo ""
}

check_pdb() {
# Verificar se é CDB

        CHECK_PDB=$(sqlplus -s "/@${ORACLE_SID}" <<EOF
whenever sqlerror exit failure
set heading off
set feedback off
select case cdb when 'YES' then 1 else 0 end from v\$database;
exit;
EOF
)

CHECK_PDB_NUMERIC=$(echo "$CHECK_PDB" | tr -d '[:space:]')

if [ $CHECK_PDB_NUMERIC -gt 0 ]; then
echo "#############################"
echo "######### Check PDB #########"
echo "#############################"
echo ""
        sqlplus -s "/@${ORACLE_SID}" <<EOF
whenever sqlerror exit failure
set colsep ";"
        set linesize 200
	col name for a20
	col open_mode for a15
	col open_time for a40
select
name
, open_mode
, open_time
from v\$pdbs;
exit;
EOF

        if [ $? -ne 0 ]; then
                handle_error "check_pdb"
        fi
        echo ""

fi

}


check_diskgroup() {
echo "###################################"        
echo "######### Check DiskGroup #########"
echo "###################################"
echo ""
        sqlplus -s "/@${ORACLE_SID}" <<EOF
whenever sqlerror exit failure
set colsep ";"        
set linesize 200
        col name for a10
        select  
            name,
            state,
            total_mb / 1024 TOTAL_GB,
            ROUND((total_mb - free_mb) / 1024,2) USED_GB,
            ROUND(free_mb / 1024,2) FREE_GB,
            ROUND((1- (free_mb / total_mb))*100, 2) PCT_USED
        from v\$asm_diskgroup
        where state = 'CONNECTED';
exit;
EOF

        if [ $? -ne 0 ]; then
                handle_error "check_diskgroup"
        fi
        echo ""

}

check_recoveryFra() {
echo "######################################"        
echo "######### Check Recovery Fra #########"
echo "######################################"
echo ""
        sqlplus -s "/@${ORACLE_SID}" <<EOF
whenever sqlerror exit failure
set colsep ";" 
       set linesize 200
        set echo off
        set newpage none
        select 
            file_type,
            percent_space_used,
            percent_space_reclaimable,
            number_of_files
        from v\$flash_recovery_area_usage;
exit;
EOF

        if [ $? -ne 0 ]; then
                handle_error "check_recoveryFra"
        fi
        echo ""

}

check_Fra() {
echo "#############################"        
echo "######### Check FRA #########"
echo "#############################"
echo ""
        sqlplus -s "/@${ORACLE_SID}" <<EOF
whenever sqlerror exit failure
set colsep ";" 
       set linesize 200
        col name for a15
        select 
            name,
            space_limit / 1024 / 1024 / 1024 SIZE_GB,
            ROUND(space_used / 1024 / 1024 / 1024,2) USED_GB,
            ROUND(SPACE_RECLAIMABLE / 1024 / 1024 / 1024,2) SPACE_RECLAIMABLE_GB,
            ROUND((space_used/space_limit)*100,2) pct_used
        from v\$recovery_file_dest;
exit;
EOF

        if [ $? -ne 0 ]; then
                handle_error "check_Fra"
        fi
        echo ""

}

check_tablespace() {
echo "####################################"
echo "######### Check Tablespace #########"
echo "####################################"
echo ""


if [[ $DB_VERSION_NUMERIC -eq 11 ]] || [[ $CHECK_PDB_NUMERIC -eq 0 ]] ; then
                sqlplus -s "/@${ORACLE_SID}" <<EOF
whenever sqlerror exit failure
set colsep ";"
set linesize 200
        set pagesize 49999
        select
                Tablespace_Name
                , round(Allocated_MB / 1024,2) Allocated_GB
                , round(Free_MB / 1024,2) Free_GB
                , round(Used_MB / 1024,2) Used_GB
                , used_pct
                , round(Max_Bytes_MB / 1024,2) Max_Bytes_GB
                from (
                select  a.tablespace_name as Tablespace_Name,
                        round(a.bytes_alloc / 1024 / 1024) Allocated_MB,
                        round(nvl(b.bytes_free, 0) / 1024 / 1024) Free_MB,
                        round((a.bytes_alloc - nvl(b.bytes_free, 0)) / 1024 / 1024) Used_MB,
                        round((nvl(b.bytes_free, 0) / a.bytes_alloc) * 100) free_pct,
                        100 - round((nvl(b.bytes_free, 0) / a.bytes_alloc) * 100) used_pct,
                        round(maxbytes/1024 / 1024) Max_Bytes_MB
                from  ( select  f.tablespace_name,
                                        sum(f.bytes) bytes_alloc,
                                        sum(decode(f.autoextensible, 'YES',f.maxbytes,'NO', f.bytes)) maxbytes
                                from dba_data_files f
                                group by tablespace_name) a,
                        ( select  f.tablespace_name,
                                        sum(f.bytes)  bytes_free
                                from dba_free_space f
                                group by tablespace_name) b
                where a.tablespace_name = b.tablespace_name (+)
                union all
                select
                        h.tablespace_name as tablespace_name,
                        round(sum(h.bytes_free + h.bytes_used) / 1048576) megs_alloc,
                        round(sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) / 1048576) megs_free,
                        round(sum(nvl(p.bytes_used, 0))/ 1048576) megs_used,
                        round((sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) / sum(h.bytes_used + h.bytes_free)) * 100) Pct_Free,
                        100 - round((sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) / sum(h.bytes_used + h.bytes_free)) * 100) pct_used,
                        round(sum(f.maxbytes) / 1048576) max
                from   (select distinct * from sys.gv_\$TEMP_SPACE_HEADER) h, (select distinct * from sys.gv_\$Temp_extent_pool) p, dba_temp_files f
                where  p.file_id(+) = h.file_id
                and    p.tablespace_name(+) = h.tablespace_name
                and    f.file_id = h.file_id
                and    f.tablespace_name = h.tablespace_name
                group by h.tablespace_name
                ORDER BY 2
                ) sub1
                order by used_pct desc;
	exit;
EOF

else
	sqlplus -s "/@${ORACLE_SID}" <<EOF
		whenever sqlerror exit failure
set colsep ";"	
	set line 200 pages 999
		col name for a15
		col tablespace_name for a15
		select
		a.con_id
		,c.name
		,b.tablespace_name
		,round(nvl(a.physical_bytes,0)/(1024*1024*1024),2) "ALLOCATED_GB"
		,round(nvl(b.tot_used,0)/(1024*1024*1024),2) "USED_GB"
		,round((nvl(b.tot_used,0)/a.physical_bytes)*100,2) "USED_PCT"
		,round(a.bytes_alloc/(1024*1024*1024),2) "MAX_BYTES_GB"
		from
		(select con_id,tablespace_name, sum(bytes) physical_bytes,sum(decode(autoextensible,'NO',bytes,'YES',maxbytes)) bytes_alloc
		from cdb_data_files group by con_id,tablespace_name ) a,
		(select con_id,tablespace_name, sum(bytes) tot_used from cdb_segments group by con_id,tablespace_name ) b,
		(select name,con_id from v\$containers) c
		where a.con_id= b.con_id and a.con_id = c.con_id and a.tablespace_name = b.tablespace_name (+)
		order by used_pct desc;

		exit;

EOF

fi

        if [ $? -ne 0 ]; then
                handle_error "check_tablespace"
        fi
        echo ""

}

check_backup() {
echo "################################"
echo "######### Check Backup #########"
echo "################################"
echo ""
        sqlplus -s "/@${ORACLE_SID}" <<EOF
whenever sqlerror exit failure
set colsep ";"        
set linesize 200
col start_time for a20
col end_time for a20
col elapsed_time for a15
col backup_size for a15
col output_device for a20 


		with backup_data as (
		select
		input_type as backup_type,
		status,
		to_char(start_time,'dd/mm/yyyy hh24:mi:ss') as start_time,
		to_char(end_time,'dd/mm/yyyy hh24:mi:ss') as end_time,
		TO_CHAR(TRUNC(ELAPSED_SECONDS/3600),'FM9900') || ':' || TO_CHAR(TRUNC(MOD(ELAPSED_SECONDS,3600)/60),'FM00') || ':' || TO_CHAR(MOD(ELAPSED_SECONDS,60),'FM00') as elapsed_time,
		output_bytes_display as backup_size,
		output_device_type as output_device,
		row_number() over(partition by input_type order by end_time desc) as rn
		from v\$rman_backup_job_details
		where (end_time is not null) and start_time > sysdate-7
		)
		select
		backup_type,
		status,
		start_time,
		end_time,
		elapsed_time,
		backup_size,
		output_device
		from backup_data
		where rn = 1
		order by backup_type;        
exit;
EOF

        if [ $? -ne 0 ]; then
                handle_error "check_backup"
        fi
        echo ""

}

check_dataguard_lag() {
echo "#######################################"
echo "######### Check DataGuard Lag #########"
echo "#######################################"
echo ""
	sqlplus -s "/@${ORACLE_SID}" <<EOF
whenever sqlerror exit failure
set colsep ";"
set linesize 300
col STANDBY_DT_LAST_APP for a20
col NAME for a40


select  case when ARC_DIFF <= 3 then ':)'  when ARC_DIFF > 3 AND ARC_DIFF <=8  then ':|' ELSE ':('  END ST
,  z.DATABASE_ROLE, z.PROTECTION_MODE, z.SWITCHOVER_STATUS, z.name, z.thread, z.STANDBY_LAST_RECEIVED
,  z.STANDBY_LAST_APPLIED, z.STANDBY_DT_LAST_APP, /*z.data_atual,*/ z.MINUTOS, z.ARC_DIFF
from (
SELECT /*+ PARALLEL(8) */
       c.DATABASE_ROLE,
       c.PROTECTION_MODE,
       C.SWITCHOVER_STATUS,
           a.DEST_ID,
          (select max(nvl2(xx.name,xx.DEST_ID||' - '||xx.name,null))
             from v\$archived_log xx
                where xx.DEST_ID = a.DEST_ID
                  and xx.resetlogs_change#=(SELECT resetlogs_change# FROM v\$database)
                  and SEQUENCE#  = (select max(yy.SEQUENCE#)
                                      from v\$archived_log yy
                                                         where yy.resetlogs_change#=(SELECT resetlogs_change# FROM v\$database)
                                                          and yy.DEST_ID = xx.DEST_ID)) as name,
           a.thread# thread,
       b. last_seq STANDBY_LAST_RECEIVED ,
       a.applied_seq STANDBY_LAST_APPLIED,
       TO_CHAR(a.last_app_timestamp,'DD/MM/YYYY HH24:MI:SS') as STANDBY_DT_LAST_APP,
           TO_CHAR(sysdate,'DD/MM/YYYY HH24:MI:SS') as data_atual,
           (sysdate - a.last_app_timestamp) *24*60  as MINUTOS,
       b.last_seq - a.applied_seq ARC_DIFF
FROM   (SELECT /*+ PARALLEL(8) */
               DEST_ID,thread#,
               Max(sequence#) applied_seq,
               Max(next_time) last_app_timestamp
        FROM   gv\$archived_log
        WHERE  applied = 'YES'
                and resetlogs_change#=(SELECT resetlogs_change# FROM v\$database)
        GROUP  BY DEST_ID,thread#) a,
       (SELECT /*+ PARALLEL(8) */
                   DEST_ID,thread#,
               Max (sequence#) last_seq
        FROM   gv\$archived_log
                where resetlogs_change#=(SELECT resetlogs_change# FROM v\$database)
        GROUP  BY DEST_ID,thread#) b,
                (SELECT DATABASE_ROLE, DB_UNIQUE_NAME INSTANCE, OPEN_MODE, PROTECTION_MODE, PROTECTION_LEVEL, SWITCHOVER_STATUS FROM V\$DATABASE) c
WHERE  a.thread# = b.thread#
and a.DEST_ID = b.DEST_ID) z
where UPPER(z.NAME) NOT LIKE '%ARCHIVELOG%'
and ((z.DATABASE_ROLE = 'PRIMARY'and (z.thread,z.DEST_ID ) in (SELECT INST_ID thread#, DEST_ID FROM GV\$ARCHIVE_DEST_STATUS WHERE STATUS <> 'INACTIVE')) or (z.DATABASE_ROLE <> 'PRIMARY'))
order by z.name, z.thread;

exit;
EOF

        if [ $? -ne 0 ]; then
                handle_error "check_dataguard_lag"
        fi
        echo ""

}

check_sessaoativa() {
echo "########################################"
echo "######### Check Sessoes Ativas #########"
echo "########################################"
echo ""
        sqlplus -s "/@${ORACLE_SID}" <<EOF
whenever sqlerror exit failure
set colsep ";"
set linesize 500
set pagesize 1000
col elapsed_time for a10
col username format a15
col service_name format a20
col inst_id for 9
col sid for 99999
col machine format a45
col serial# for 99999
col sql_text for a50
col event for a50


select distinct inst_id, sid, serial#, username, machine, dbms_lob.substr(sql_text,50,1) as sql_text, sql_id, elapsed_time, status, event,service_name from (
select s.inst_id, s.sid, s.serial#, s.username, s.machine, gv.sql_text, gv.sql_id,
TO_CHAR(TRUNC(s.last_call_et/3600),'FM9900') || ':' || TO_CHAR(TRUNC(MOD(s.last_call_et,3600)/60),'FM00') || ':' || TO_CHAR(MOD(s.last_call_et,60),'FM00') as elapsed_time,
s.status, s.event,s.SERVICE_NAME
from gv\$sql gv, gv\$session s
where gv.sql_id=s.sql_id
and gv.inst_id=s.inst_id
and username is not null
and s.status='ACTIVE'
order by elapsed_time desc
)
order by elapsed_time desc;

exit;
EOF

        if [ $? -ne 0 ]; then
                handle_error "check_sessaoativa"
        fi
        echo ""

}

check_lock() {
echo "##############################"
echo "######### Check Lock #########"
echo "##############################"
echo ""
        sqlplus -s "/@${ORACLE_SID}" <<EOF
whenever sqlerror exit failure
set colsep ";"
set linesize 500
set pagesize 1000
select 'SID ' || l1.sid || ' esta bloqueando ' || l2.sid || ' na instancia ' || s.inst_id as blocking
from gv\$lock l1, gv\$lock l2, gv\$session s
where l1.block = 1
and l2.request > 0
and l1.id1 = l2.id1
and l1.id2 = l2.id2
and s.sid = l1.sid;

exit;
EOF

        if [ $? -ne 0 ]; then
                handle_error "check_lock"
        fi
        echo ""

}

check_alertlog() {
echo "########################################################"
echo "######### Check Alert Log das ultimas 2 horas #########"
echo "########################################################"
echo ""

result=$(sqlplus -s "/@${ORACLE_SID}" <<EOF
whenever sqlerror exit failure
set heading off
set feedback off
select instance_name from gv\$instance order by instance_name;
exit;
EOF
)

# Converte o resultado em um array
IFS=$'\n' read -r -d '' -a lines <<< "$result"

# Armazena cada linha em uma variável separada
for i in "${!lines[@]}"; do
    eval "var$i='${lines[$i]}'"
done

# Exemplo de como acessar as variáveis
for i in "${!lines[@]}"; do
	instance_name=$(eval "echo \$var$i")
echo "####################################################"	
echo "Conectando ao banco de dados: $instance_name"
echo "####################################################"
echo ""
	sqlplus -s "/@${ORACLE_SID}" <<EOF
whenever sqlerror exit failure
set colsep ";"
set linesize 450
ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YY HH24:MI:SS';

col originating_timestamp format a18
col host_id format a40
col host_address format a15
col message_text format a145

select
to_char(dae.originating_timestamp, 'DD/MM/YY HH24:MI:SS') as originating_timestamp,
i.instance_name,
dae.host_id,
dae.host_address,
case dae.message_type when 1 then 'UNKNOWN' when 2 then 'INCIDENT_ERROR' when 3 then 'ERROR' when 4 then 'WARNING' when 5 then 'NOTIFICATION' when 6 then 'TRACE' end as message_type,
case dae.message_level when 1 then 'CRITICAL' when 2 then 'SEVERE' when 8 then 'IMPORTANT' when 16 then 'NORMAL' end as message_level,
dae.message_text
from v\$diag_alert_ext dae, v\$instance i
where --(upper(dae.message_text) like '%ORA-%')
--or upper(dae.message_text) like '%TNS%')
--and 
dae.originating_timestamp >= sysdate-2/24
order by 1 asc;

exit;

EOF

done

        if [ $? -ne 0 ]; then
                handle_error "check_alertlog"
        fi
        echo ""

}

check_diskOS() {
echo "#########################################"
echo "######### Check Espaço em Disco #########"
echo "#########################################"
echo ""
result=$(sqlplus -s "/@${ORACLE_SID}" <<EOF
whenever sqlerror exit failure
set heading off
set feedback off
select host_name from gv\$instance order by host_name;
exit;
EOF
)

# Converte o resultado em um array
IFS=$'\n' read -r -d '' -a lines <<< "$result"

# Armazena cada linha em uma variável separada
for i in "${!lines[@]}"; do
    eval "var$i='${lines[$i]}'"
done

# Exemplo de como acessar as variáveis
for i in "${!lines[@]}"; do
        host_name=$(eval "echo \$var$i")
echo "####################################################"
echo "Conectando ao servidor: $host_name"
echo "####################################################"
echo ""

ssh $userOS@$host_name 'df -h'

done

        if [ $? -ne 0 ]; then
                handle_error "check_diskOS"
        fi
        echo ""

}

send_email(){

cat ${LOG_FILE} | mailx -s "Checklist Oracle ${ORACLE_SID}" p639366@corp.caixa.gov.br p965748@corp.caixa.gov.br p558249@corp.caixa.gov.br p598481@corp.caixa.gov.br p754494@corp.caixa.gov.br

}


run_checklist() {
	get_db_version
	check_instance
if [[ $DB_VERSION_NUMERIC -gt 11 ]]; then
	check_pdb
fi
	check_diskgroup	
	check_Fra
	check_recoveryFra
	check_tablespace
	check_backup
	check_dataguard_lag
	check_sessaoativa
	check_lock
#	check_alertlog
#if [[ $ORACLE_SID != 'ssointerstb2' ]] && [[ $ORACLE_SID != 'ssointerstb3' ]]; then
#	check_diskOS
#fi
echo "######### Fim do Checklist #########"
	send_email

}

run_checklist


