
prompt ==========================================================================================
prompt DATABASE
prompt ==========================================================================================
                SELECT NAME,DATABASE_ROLE,OPEN_MODE FROM V$DATABASE;
prompt **Verificar se está logado no banco certo e com a role certa
prompt **E, sendo possível, se o problema é no primário ou standby
prompt ==========================================================================================
prompt INSTANCIAS
prompt ==========================================================================================
prompt
  set linesize 400
  set feed off
  Alter Session Set Nls_Date_Format = 'dd/mm/yyyy hh24:mi:ss';
  select inst_id, instance_name, version, startup_time, status, logins, database_status, blocked from gv$instance order by 1;
  prompt **verificar se houve stop/start de instancia e se todas as instancias estão ativas
prompt ==========================================================================================  
prompt HOSTNAME E USUÁRIO 
prompt ==========================================================================================  
col session_user for a20
col hostname for a50
SELECT 
    SYS_CONTEXT('USERENV', 'SESSION_USER') AS SESSION_USER, SYS_CONTEXT('USERENV', 'HOST') AS HOSTNAME FROM DUAL;
prompt ==========================================================================================
prompt SERVICOS
prompt ==========================================================================================
prompt
!  for INST in `grep -i orap /etc/oratab | cut -c 1-8`; do echo "============================>   $INST   <============================"; srvctl status service -d $INST; echo -e /n ;done;
prompt ** caso não tenha acesso ao sistema operacional do servidor de banco utilizar o comando abaixo
        col NETWORK_NAME for a40
		col name for a20
        select INST_ID,NAME, NETWORK_NAME from gV$ACTIVE_SERVICES order by name, inst_id;
prompt **verificar se os serviços necessários estão ativos
prompt ==========================================================================================
prompt COMPARAR RECURSOS UTILIZADOS COM SEUS LIMITES:
prompt ==========================================================================================
prompt
col limite_configurado for a30
col DISPLAY_VALUE for a30
col NAME for a30
col RESOURCE_NAME for a20
select rs.inst_id,resource_name,current_utilization, max_utilization,value limite_configurado
from 
  (select inst_id,resource_name, current_utilization, max_utilization from gv$resource_limit where  regexp_like(resource_name, 'transactions|sessions|processes|locks')) rs,
  (select inst_id, name, value from GV$PARAMETER where name in ('sessions','transactions','processes','locks')) par
where rs.resource_name= par.name
and rs.inst_id= par.inst_id
order by resource_name, inst_id;
prompt ==========================================================================================
prompt PGA
prompt ==========================================================================================
prompt
PROMPT PGA CONFIGURADA
prompt
set lines 200 pages 200
col name for a30
col value for a30
col DISPLAY_VALUE for a30
select inst_id, name, value/1024/1024/1024, DISPLAY_VALUE from GV$SPPARAMETER
where name like '%pga%';
prompt
PROMPT PGA USADA
prompt
set pages 200 lines 200
select INST_ID, sum(PGA_ALLOC_MEM)/1024/1024/1024 PGA_ALOCADA, sum(PGA_USED_MEM)/1024/1024/1024 PGA_USADA
from gv$process group by INST_ID;
prompt
prompt ==========================================================================================
prompt OBJETOS INVALIDOS
prompt ==========================================================================================
prompt
        set lines 1000 pages 200
        col OWNER for a10
        col OBJECT_NAME for a35
        col SUBOBJECT_NAME for a30
        --OBJETOS INVALIDOS
        select OWNER, OBJECT_NAME, SUBOBJECT_NAME,OBJECT_ID,
         DATA_OBJECT_ID, OBJECT_TYPE,
         CREATED,
        LAST_DDL_TIME,
        TIMESTAMP,
        STATUS, TEMPORARY,GENERATED, NAMESPACE
        from dba_objects
            where status <> 'VALID'
         order by OBJECT_NAME,SUBOBJECT_NAME,TIMESTAMP;

prompt **Objetos invalidos podem ou não ser a causa de um problema atual, podem existir objetos inválidos há muito tempo que não são usados pela aplicação;
prompt
prompt ==========================================================================================
prompt ÍNDICES INVALIDOS
prompt ==========================================================================================
prompt
col OWNER      FOR a20
col INDEX_NAME FOR a40
select owner,INDEX_NAME, STATUS from dba_indexes where STATUS not in  ('VALID','N/A')
union all
select index_owner,INDEX_NAME, STATUS from dba_ind_partitions where STATUS not in ('USABLE','N/A' )
union all
select index_owner,INDEX_NAME, STATUS from dba_ind_subpartitions where STATUS <> 'USABLE';
prompt **Índices invalidos podem ou não ser a causa de um problema atual, podem existir Índices inválidos há muito tempo que não são usados pela aplicação;
prompt ==========================================================================================
prompt USUÁRIOS EXPIRADOS/BLOQUEADOS
prompt ==========================================================================================
col username for a30
col profile for a30
set lines 200 pages 200
select USERNAME,profile, ACCOUNT_STATUS, LOCK_DATE, EXPIRY_DATE from dba_users where NOT REGEXP_LIKE (username, '^[C|P][0-9][0-9][0-9][0-9][0-9][0-9]')
and username not in (
'SYS','SYSTEM','XS$NULL','APPQOSSYS','GSMCATUSER','SYSBACKUP','REMOTE_SCHEDULER_AG','DBSFWUSER','GSMUSER','GGSYS','ANONYMOUS','SYSRAC','AUDSYS','REMOTE_SCHEDULER_AGENT','GSMADMIN_INTERNAL','DIP','SYSKM','OUTLN','ORACLE_OCM','SYS$UMF','XDB','SYSDG','WMSYS','DBSNMP')
and EXPIRY_DATE is not null
order by EXPIRY_DATE desc;            
prompt ** verificar as colunas ACCOUNT_STATUS, LOCK_DATE, EXPIRY_DATE
prompt ** verificar usuário q ficaram expirados ou bloqueados recentemente , incluir na query quem esta nesse status a mais de 40 dias
prompt ==========================================================================================
prompt NUMERO DE SESSOES POR USUÁRIO
prompt ==========================================================================================
prompt
set lines 200 pages 200
col username for a20
select * from  (select username,status from gv$session where username is not null)
                                pivot
                                (count(status) for status in ('ACTIVE','INACTIVE')) order by 1;
prompt **Quantidade de sessões ativas aumentando ou proxímo da qtd de sessões inativas normalmente indica existencia de problemas
prompt
prompt ==========================================================================================
prompt NUMERO DE SESSOES POR CLIENT
prompt ==========================================================================================
prompt
set lines 200 pages 200
col username for a20
select * from  (select machine,status from gv$session where username is not null)
                                pivot
                                (count(status) for status in ('ACTIVE','INACTIVE')) order by 1;
prompt
prompt ==========================================================================================
prompt NUMERO DE SESSOES POR INSTANCIA
prompt ==========================================================================================
prompt
set lines 200 pages 200
col username for a20
select * from  (select INST_ID,status from gv$session where username NOT IN ('DBSNMP','SYS','PUBLIC','SYSRAC'))
                                pivot
                                (count(status) for status in ('ACTIVE','INACTIVE')) order by 1;
prompt
prompt ==========================================================================================
prompt SESSOES ATIVAS A MAIS TEMPO 
prompt ==========================================================================================
prompt
col USERNAME for a15
select * from (select INST_ID,username,last_call_et from gv$session where username is not null and username not like 'SYS%'
and status = 'ACTIVE'
order by last_call_et desc)
where rownum <= 10  ;
prompt ** Sessões mais demoradas podem apontar a causa de um eventual problema
prompt
prompt ==========================================================================================
prompt SESSOES POR EVENTO DE ESPERA
prompt ==========================================================================================
prompt
col WAIT_CLASS for a20
col event for a60
select wait_class,event, count(*) from gv$session where status ='ACTIVE' group by wait_class,event order by wait_class,event;
 ** Sessões mais demoradas podem apontar a causa de um eventual problema
prompt
prompt ==========================================================================================
prompt QUERIES MAIS EXECUTADAS
prompt ==========================================================================================
prompt
col USERNAME for a10
select ses.inst_id, ses.username, ses.sql_id, count (*)  from gv$session ses
where status <> 'INACTIVE'
and username is not null
AND USERNAME <> (SELECT SYS_CONTEXT ('USERENV', 'CURRENT_USER') FROM DUAL)
group by ses.inst_id,username,ses.sql_id
order by count (*) desc ,ses.username,ses.inst_id;
prompt ** Aumento na quantidade de execuções de uma query pode ser indicio de problema, assim esse é um ponto a ser avaliado com cuidado.
prompt
prompt ==========================================================================================
prompt BLOQUEADORAS PRINCIPAIS
prompt ==========================================================================================
prompt
set long 1000
set lines 2000 pages 100
set colsep ";"
col username for a13
col SQL_FULLTEXT for a2000
col SERVICE_NAME for a15
col machine for a30
col PROGRAMA for a30
col PROCESS for a15
col EVENT for a35
col WAIT_CLASS for a20
col p1text for a20
col p2text for a20
col p3text for a20
col sqlt for a1000
col exec_start for a20
col "login_time" for a20
col resource_group for a15
col SQL_PROFILE for a20
select username
,ses.sql_id
--,PREV_SQL_ID,sql.SQL_PROFILE
        ,SUBSTR(machine,1,30) machine
        --,SUBSTR(program,1,30) programa
        -- , resource_consumer_group as resource_group, service_name
        ,status
        ,ses.process,ses.inst_id, ses.sid, ses.serial#
        ,to_char(LOGON_TIME,'DD/MM/YY HH24:MI:SS') as "login_time"
        ,last_call_et
        --,to_char(SQL_EXEC_START,'DD/MM/YY HH24:MI:SS')as  exec_start
--      ,ses.PROCESS,BLOCKING_SESSION_STATUS, BLOCKING_INSTANCE, BLOCKING_SESSION
        ,wait_class,event,seconds_in_wait,state,PQ_STATUS
        --,ROW_WAIT_OBJ#,ROW_WAIT_FILE#,ROW_WAIT_BLOCK#,ROW_WAIT_ROW#
        ,FINAL_BLOCKING_SESSION_STATUS,FINAL_BLOCKING_INSTANCE,FINAL_BLOCKING_SESSION
        --,p1,p1text,p2,p2text,p3,p3text
        --,SES.SQL_ADDRESS ,SES.SQL_HASH_VALUE,SQL_CHILD_NUMBER,sql.PLAN_HASH_VALUE
        --,SQL_FULLTEXT
,substr(SQL_TEXT,1,1000) as sqlt
from  gv$session ses , gv$sql sql
where ses.sql_id=sql.sql_id
and ses.inst_id=sql.inst_id
                and SES.SQL_ADDRESS    = SQL.ADDRESS
                and SES.SQL_HASH_VALUE = SQL.HASH_VALUE
and ses.sid in (select FINAL_BLOCKING_SESSION from  ----INCLUIR INST ID
(
        select FINAL_BLOCKING_SESSION, count(*) QTD
        from gv$session ses
        where FINAL_BLOCKING_SESSION is not null
        --and username like '%GMS%'
        group by FINAL_BLOCKING_SESSION
        order by QTD desc
)
where rownum <= 10)
order by last_call_et;
prompt
prompt ==========================================================================================
prompt SQL COM MAIOR TEMPO DE EXECUCAO INDIVIDUAL
prompt ==========================================================================================
prompt
set lines 2000 pages 200
col data for a30
col PARSING_SCHEMA_NAME for a20
col CPU_T for 9999999999999999999
col elap_T for 999999999999999999
col TEMPO_por_exec head 'tempo por exec(microseg)'
select * from (select to_char(sysdate, 'dd/mm/yy hh24:mi:ss') DATA,PARSING_SCHEMA_NAME,SQL_ID,PLAN_HASH_VALUE,sum(CPU_TIME) cpu_t,sum(ELAPSED_TIME) elap_t,sum(DISK_READS),sum(BUFFER_GETS),sum(EXECUTIONS),trunc(sum(ELAPSED_TIME)/sum(EXECUTIONS)) TEMPO_por_exec
from gv$sql
where executions >0
and PARSING_SCHEMA_NAME not in ('SYS')
group by PARSING_SCHEMA_NAME,SQL_ID,PLAN_HASH_VALUE,OPTIMIZER_COST
order by TEMPO_por_exec desc) where rownum <= 20;
prompt **Essa query mostra os comandos com maior tempo de execução por execução, verificar a coluna "tempo por exec(microseg)"
prompt
prompt ==========================================================================================
prompt SQL COM MAIOR TEMPO ACUMULADO DE EXECUÇÃO
prompt ==========================================================================================
prompt
set lines 200 pages 200
col data for a30
col PARSING_SCHEMA_NAME for a20
col CPU_T for 9999999999999999999
col elap_T for 999999999999999999
select * from (select to_char(sysdate, 'dd/mm/yy hh24:mi:ss') DATA ,PARSING_SCHEMA_NAME,SQL_ID,PLAN_HASH_VALUE,sum(CPU_TIME) cpu_t,sum(ELAPSED_TIME) elap_t,sum(DISK_READS),sum(BUFFER_GETS),sum(EXECUTIONS),trunc(sum(ELAPSED_TIME)/sum(EXECUTIONS),1) TEMPO_por_exec
from gv$sql
where executions >0
and PARSING_SCHEMA_NAME not like '%SYS%'
group by PARSING_SCHEMA_NAME,SQL_ID,PLAN_HASH_VALUE,OPTIMIZER_COST
order by sum(ELAPSED_TIME) desc) where rownum <= 10;
prompt **Essa query mostra os comandos com maior tempo de execução acumulado, verificar a coluna "ELAP_T"
prompt
prompt ==========================================================================================
prompt QUERIES MAIS DEMORADAS
prompt ==========================================================================================
set long 1000
	set lines 2000 pages 100
	set colsep ";"
	col username for a20
	col SQL_FULLTEXT for a2000
	col SERVICE_NAME for a15 
	col machine for a50
	col PROGRAMA for a30
	col PROCESS for a15
	col EVENT for a40
	col WAIT_CLASS for a20
	col p1text for a20
	col p2text for a20
	col p3text for a20
	col sqlt for a1000
	col exec_start for a20
	col "login_time" for a20
	col resource_group for a15
	col SQL_PROFILE for a20
	select username
	,ses.sql_id
	,PREV_SQL_ID,sql.SQL_PROFILE
	,SUBSTR(machine,1,30) machine
	,SUBSTR(program,1,30) programa
	-- , resource_consumer_group as resource_group, service_name
	,status
	,ses.process,ses.inst_id, ses.sid, ses.serial#
	,to_char(LOGON_TIME,'DD/MM/YY HH24:MI:SS') as "login_time"
	,last_call_et
	--,to_char(SQL_EXEC_START,'DD/MM/YY HH24:MI:SS')as  exec_start
	--	,ses.PROCESS,BLOCKING_SESSION_STATUS, BLOCKING_INSTANCE, BLOCKING_SESSION
	,wait_class,event,seconds_in_wait,state,PQ_STATUS
	--,ROW_WAIT_OBJ#,ROW_WAIT_FILE#,ROW_WAIT_BLOCK#,ROW_WAIT_ROW# 
	,FINAL_BLOCKING_SESSION_STATUS,FINAL_BLOCKING_INSTANCE,FINAL_BLOCKING_SESSION,LOCKWAIT
	,p1,p1text,p2,p2text,p3,p3text
	--,SES.SQL_ADDRESS ,SES.SQL_HASH_VALUE,SQL_CHILD_NUMBER,sql.PLAN_HASH_VALUE
	--,SQL_FULLTEXT
	,substr(SQL_TEXT,1,1000) as sqlt
	from  gv$session ses , gv$sql sql
	where ses.sql_id=sql.sql_id
	and ses.inst_id=sql.inst_id
	and SES.SQL_ADDRESS    = SQL.ADDRESS 
	and SES.SQL_HASH_VALUE = SQL.HASH_VALUE
	and status <> 'INACTIVE' and username <> 'C062667' 
	and username is not null 
	order by last_call_et desc 
	FETCH NEXT 50 ROWS ONLY;
prompt ==========================================================================================
prompt Queries (sql_id) com mais de um plano de execução(plan_hash_value)
prompt ==========================================================================================
prompt ==========================================================================================
prompt	EM MEMÓRIA
prompt ==========================================================================================
		SELECT inst_id, sql_id,COUNT(DISTINCT plan_hash_value) AS num_planos
		FROM GV$SQL_PLAN
		GROUP BY sql_id,inst_id
		HAVING COUNT(DISTINCT plan_hash_value) > 1
		order by sql_id;	
prompt ==========================================================================================
prompt	             NO HISTÓRICO
prompt ==========================================================================================
			SELECT sql_id, COUNT(DISTINCT plan_hash_value) AS num_planos
			FROM dba_hist_sql_plan
			GROUP BY sql_id
			HAVING COUNT(DISTINCT plan_hash_value) > 1
			order by sql_id;	
prompt ==========================================================================================
prompt TAMANHO/OCUPACAO DOS DISKGROUPS
prompt Atentar para a coluna "USABLE_FILE_MB"
prompt ==========================================================================================
prompt
        set lines 200 pages 200
        select NAME, STATE, TOTAL_MB, FREE_MB, (TOTAL_MB-FREE_MB) USED_MB,case TOTAL_MB when  0 then 0 else  trunc(((TOTAL_MB-FREE_MB)/TOTAL_MB) * 100)  end "%_USED" , REQUIRED_MIRROR_FREE_MB, USABLE_FILE_MB from V$ASM_DISKGROUP;
prompt
prompt ==========================================================================================
prompt TAMANHO/OCUPACAO DAS TABLESPACES
prompt ==========================================================================================
prompt
                set lines 200 pages 200
                column max_mb format 999,999,999,999
                column total_mb format 999,999,999,999
                column used_mb format 999,999,999,999
                column free_mb format 999,999,999
                column pct_used_alocado format 999.99
                column pct_used_total format 999.99
                column status format a10
                compute sum of max_mb on report
                compute sum of total_mb on report
                compute sum of used_mb on report
                compute sum of free_mb on report
                break on report
select  total.ts tablespace,
DECODE(total.mb,null,'OFFLINE',dbat.status) status,
Trunc(total.mxmb) max_mb,
Trunc(total.mb) total_mb,
Trunc(NVL(total.mb - free.mb,total.mb)) used_mb,
Trunc(NVL(free.mb,0)) free_mb,
DECODE(total.mb,NULL,0,NVL(ROUND((total.mb - free.mb)/(total.mb)*100,2),100)) pct_used_alocado,
DECODE(total.mxmb,0,1,NVL(ROUND((total.mb - free.mb)/(total.mxmb)*100,2),100)) pct_used_total
from
(select tablespace_name ts, sum(bytes)/1024/1024 mb,sum(maxbytes)/1024/1024 mxmb from dba_data_files group by tablespace_name) total,
(select tablespace_name ts, sum(bytes)/1024/1024 mb from dba_free_space group by tablespace_name) free,
dba_tablespaces dbat
where total.ts=free.ts(+) and total.ts=dbat.tablespace_name
--and (((total.mb - free.mb)/total.mb) > 0.90 or ((DECODE(total.mxmb,0,1,NVL(ROUND((total.mb - free.mb)/(total.mxmb)*100,2),100))) > 0.9)   or (STATUS <> 'ONLINE'))
--and total.ts like 'NDA%'
order by total.ts;
prompt
--TEMP
select  sh.tablespace_name,'TEMP',
SUM(sh.bytes_used+sh.bytes_free)/1024/1024/1024 total_gb,
SUM(sh.bytes_used)/1024/1024/1024 used_gb,
SUM(sh.bytes_free)/1024/1024 free_mb,
ROUND(SUM(sh.bytes_used)/SUM(sh.bytes_used+sh.bytes_free)*100,2) pct_used
FROM v$temp_space_header sh
GROUP BY tablespace_name;

prompt **Verificar as colunas PCT_USED_ALOCADO e PCT_USED_TOTAL, a primeira mostra o espaço alocado já utilizado a segunda mostra o espaço usado considerando
prompt **a possibilidade de alocação do banco desde de que exista espaço no diskgroup.
prompt
prompt ==========================================================================================
prompt UTILIZAÇÃO DE SEQUENCES
prompt ==========================================================================================
col SEQUENCE_OWNER for a20                                                                                                                  
col SEQUENCE_NAME  for a30
col MAX_VALUE for 9999999999999999999999999999999999
col LAST_NUMBER for 9999999999999999999999999999999999
select SEQUENCE_OWNER, SEQUENCE_NAME,MAX_VALUE,INCREMENT_BY,CACHE_SIZE,LAST_NUMBER,TRUNC(LAST_NUMBER/MAX_VALUE*100,2) "% UTILIZADO", CYCLE_FLAG from dba_sequences
where sequence_owner not in ('SYS','SYSTEM','DBSNMP','GSMADMIN_INTERNAL','SQLTXPLAIN','XDB','WMSYS')
order by "% UTILIZADO" desc;
prompt ** Verificar a coluna "% UTILIZADO" para identificar sequences que alcançaram o limite configurado
prompt
prompt ==========================================================================================
prompt DELAY DE REPLICACAO  
prompt ==========================================================================================
prompt
set lines 300 pages 300
col name for a50
alter session set nls_date_format='dd/mm/yyyy hh24:mi:ss';
select sysdate, name,a.thread#, b.last_seq "ULTIMO RECEBIDO", a.applied_seq "ULTIMO APLICADO", a.last_app_timestamp,b.last_seq - a.applied_seq "ARC_DIFF"
from 
	(select thread#, name, max(sequence#) applied_seq,max(next_time) last_app_timestamp from gv$archived_log a, 
                               	(select max(RESETLOGS_TIME) RESETLOGS_TIME 		
										from gv$database_incarnation) R where applied='YES' and a.RESETLOGS_TIME= r.RESETLOGS_TIME and a.dest_id in 
												(select distinct DEST_ID
												--, STANDBY_DEST, NAME 
												from gv$archived_log where STANDBY_DEST='YES') 
										group by name, thread#)a,
			   (select thread#, max(sequence#) last_seq from gv$archived_log a,  
			   (select max(RESETLOGS_TIME) RESETLOGS_TIME from gv$database_incarnation) R where a.RESETLOGS_TIME = R.RESETLOGS_TIME and dest_id in (select distinct DEST_ID
--, STANDBY_DEST, NAME 
from gv$archived_log where STANDBY_DEST='YES') group by thread#) b
where a.thread#=b.thread#
order by NAME,THREAD#;
prompt
prompt ==========================================================================================
prompt UTILIZACAO DE REDO
prompt ==========================================================================================
prompt
set lines 200 pages 200
column day format a10
col day for a20
column Switches_per_day format 9999
column 00 format 999
column 01 format 999
column 02 format 999
column 03 format 999
column 04 format 999
column 05 format 999
column 06 format 999
column 08 format 999
column 07 format 999
column 09 format 999
column 10 format 999
column 11 format 999
column 12 format 999
column 13 format 999
column 14 format 999
column 15 format 999
column 16 format 999
column 17 format 999
column 18 format 999
column 19 format 999
column 20 format 999
column 21 format 999
column 22 format 999
column 23 format 999
select to_char(first_time,'DD-MON') day,
sum(decode(to_char(first_time,'hh24'),'00',1,0)) "00",
sum(decode(to_char(first_time,'hh24'),'01',1,0)) "01",
sum(decode(to_char(first_time,'hh24'),'02',1,0)) "02",
sum(decode(to_char(first_time,'hh24'),'03',1,0)) "03",
sum(decode(to_char(first_time,'hh24'),'04',1,0)) "04",
sum(decode(to_char(first_time,'hh24'),'05',1,0)) "05",
sum(decode(to_char(first_time,'hh24'),'06',1,0)) "06",
sum(decode(to_char(first_time,'hh24'),'07',1,0)) "07",
sum(decode(to_char(first_time,'hh24'),'08',1,0)) "08",
sum(decode(to_char(first_time,'hh24'),'09',1,0)) "09",
sum(decode(to_char(first_time,'hh24'),'10',1,0)) "10",
sum(decode(to_char(first_time,'hh24'),'11',1,0)) "11",
sum(decode(to_char(first_time,'hh24'),'12',1,0)) "12",
sum(decode(to_char(first_time,'hh24'),'13',1,0)) "13",
sum(decode(to_char(first_time,'hh24'),'14',1,0)) "14",
sum(decode(to_char(first_time,'hh24'),'15',1,0)) "15",
sum(decode(to_char(first_time,'hh24'),'16',1,0)) "16",
sum(decode(to_char(first_time,'hh24'),'17',1,0)) "17",
sum(decode(to_char(first_time,'hh24'),'18',1,0)) "18",
sum(decode(to_char(first_time,'hh24'),'19',1,0)) "19",
sum(decode(to_char(first_time,'hh24'),'20',1,0)) "20",
sum(decode(to_char(first_time,'hh24'),'21',1,0)) "21",
sum(decode(to_char(first_time,'hh24'),'22',1,0)) "22",
sum(decode(to_char(first_time,'hh24'),'23',1,0)) "23",
count(to_char(first_time,'MM-DD')) Switches_per_day
from gv$log_history
where trunc(first_time) between trunc(sysdate) - 6 and trunc(sysdate)
group by to_char(first_time,'DD-MON')
order by to_char(first_time,'DD-MON') ;

prompt
prompt ==========================================================================================
prompt ALERT
prompt ==========================================================================================
prompt
set lines 300
col HOST_ID for a40
col ORIGINATING_TIMESTAMP for a40
col MESSAGE_ARGUMENTS for a40
col message_text for a100
select ORIGINATING_TIMESTAMP,
--HOST_ID,
MESSAGE_TYPE, MESSAGE_LEVEL,
--MESSAGE_ARGUMENTS,
message_text
from  v$diag_alert_ext
where ORIGINATING_TIMESTAMP >= sysdate -1/24 --ultimas duas horas
--and MESSAGE_LEVEL <> 16
--and message_level = 1
order by ORIGINATING_TIMESTAMP;
prompt
 exit;